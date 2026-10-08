#!/usr/bin/env python3
"""Design board: index approved/in-flight designs and detect overlapping work.

Every design doc in docs/designs/*.md starts with front matter (see TEMPLATE.md).
This tool is deterministic (no LLM, no tokens):

  board.py index                      write docs/designs/INDEX.md + board.json for this repo
  board.py overlap <path-or-glob>...   list active designs whose areas overlap the given paths/globs/areas
  board.py overlap --design FILE       check one design against every other active design
  board.py overlap --diff BASE         check the files changed since BASE (e.g. origin/main)
           [--exclude ID]... [--author @x] skip designs/PRs the work belongs to (its own design, its own PR)
  board.py aggregate REPOS_FILE OUT    hub only: merge designs + open PRs of many repos (needs gh)
  board.py brief [--board FILE]        compact one-line-per-design list for an agent's context

Overlap rule: two areas overlap when one matches the other as a glob, or one's literal prefix contains the
other on a path-segment boundary (src/auth/** ~ src/auth/x.py, but not src/authz). Named areas (api:/x,
db:users, ui:login) only overlap other named areas of the same kind, by the same rule.
"""
from __future__ import annotations
import fnmatch, json, os, re, subprocess, sys, datetime
from pathlib import Path

ROOT = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip() or ".")
DESIGNS = ROOT / "docs" / "designs"
ACTIVE = {"draft", "approved", "in-progress"}
STALE_DAYS = int(os.environ.get("DESIGN_STALE_DAYS", "21"))

def stale(d: dict) -> bool:
    """Active designs not updated for STALE_DAYS are flagged so an abandoned claim does not block others."""
    try:
        return (datetime.date.today() - datetime.date.fromisoformat(str(d.get("updated", ""))[:10])).days > STALE_DAYS
    except ValueError:
        return False

def _unquote(v: str) -> str:
    return v.strip().strip('"').strip("'")

def parse_front_matter(text: str) -> dict:
    """Small YAML subset: `key: value`, `key: [a, "b"]`, and block lists (`key:` then `- item` lines)."""
    m = re.match(r"^\ufeff?---\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|$)", text, re.S)
    if not m:
        return {}
    data: dict = {}
    last_key = None
    for raw in m.group(1).splitlines():
        line = re.sub(r"\s+#\s.*$", "", raw).rstrip()  # "# comment" only; keeps "#12" in values
        if not line.strip():
            continue
        item = re.match(r"^\s*-\s+(.*)$", line)
        if item and last_key is not None and (data.get(last_key) == "" or isinstance(data.get(last_key), list)):
            if data[last_key] == "":
                data[last_key] = []
            data[last_key].append(_unquote(item.group(1)))
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        k, v = k.strip(), v.strip()
        last_key = k
        if v.startswith("[") and v.endswith("]"):
            data[k] = [x for x in (_unquote(x) for x in v[1:-1].split(",")) if x]
        else:
            data[k] = _unquote(v)
    return data

def normalize(d: dict, fallback_id: str) -> dict:
    """Fill defaults so every consumer can rely on id/status/areas being present and typed."""
    if not d.get("id"):
        d["id"] = fallback_id
    owner = d.get("owner") or ""
    d["owner"] = ", ".join(map(str, owner)) if isinstance(owner, list) else str(owner)
    d["status"] = str(d.get("status") or "draft").strip().lower()
    issues = d.get("issues") or []
    d["issues"] = [issues] if isinstance(issues, (str, int)) else list(issues)
    areas = d.get("areas") or []
    d["areas"] = [areas] if isinstance(areas, str) else list(areas)
    if not d["areas"] and d["status"] in ACTIVE:
        print(f"warning: design {d['id']} has no areas; overlap checks cannot see it", file=sys.stderr)
    return d

def local_designs(repo: str | None = None) -> list[dict]:
    repo = repo or os.environ.get("GITHUB_REPOSITORY") or ROOT.name
    out = []
    for f in sorted(DESIGNS.glob("*.md")):
        if f.name in ("TEMPLATE.md", "INDEX.md", "README.md"):
            continue
        d = parse_front_matter(f.read_text(encoding="utf-8"))
        if not d:
            continue
        d = normalize(d, f.stem)
        d["file"] = str(f.relative_to(ROOT))
        d["repo"] = repo
        out.append(d)
    return out

def _literal_prefix(glob: str) -> str:
    return re.split(r"[*?\[]", glob, maxsplit=1)[0]

def _contains(prefix: str, other: str, sep: str) -> bool:
    """True when `other` equals `prefix` or lies under it on a segment boundary."""
    if prefix.endswith(sep) or prefix.endswith(":"):
        return other.startswith(prefix)
    return other == prefix or other.startswith(prefix + sep)

def areas_overlap(a: str, b: str) -> bool:
    a, b = a.strip(), b.strip()
    if not a or not b:
        return False
    a, b = (re.sub(r"^\./|^/", "", x) for x in (a, b))
    kind = lambda s: (m.group(1).lower() if (m := re.match(r"^([A-Za-z]+):", s)) else None)
    if kind(a) or kind(b):
        if kind(a) != kind(b):
            return False
        a, b = a[len(kind(a)) + 1:], b[len(kind(b)) + 1:]
        if not a or not b:  # "db:" claims the whole kind
            return True
    if fnmatch.fnmatchcase(a, b) or fnmatch.fnmatchcase(b, a):
        return True
    pa, pb = _literal_prefix(a), _literal_prefix(b)
    if not pa or not pb:
        return False
    # A literal prefix cut mid-segment (src/auth* -> "src/auth") must still allow "src/authz".
    loose_a, loose_b = pa != a and not pa.endswith("/"), pb != b and not pb.endswith("/")
    return (pb.startswith(pa) if loose_a else _contains(pa, pb, "/")) or \
           (pa.startswith(pb) if loose_b else _contains(pb, pa, "/"))

def find_overlaps(areas: list[str], designs: list[dict], skip_ids: set[str] = frozenset(),
                  author: str | None = None) -> list[tuple[dict, list[str]]]:
    hits = []
    for d in designs:
        if d.get("status", "draft") not in ACTIVE or d.get("id") in skip_ids or Path(d.get("file") or "-").stem in skip_ids:
            continue
        owners = {o.strip().lstrip("@").lower() for o in str(d.get("owner") or "").split(",")}
        if author and author.lstrip("@").lower() in owners:
            continue  # your own design or PR is not someone else's claim
        common = sorted({f"{x} ~ {y}" for x in areas for y in d.get("areas", []) if areas_overlap(x, y)})
        if common:
            hits.append((d, common))
    return hits

def load_board(path: str | None) -> list[dict]:
    designs = local_designs()
    if path and Path(path).exists():
        board = json.loads(Path(path).read_text(encoding="utf-8"))
        seen = {(d["repo"], d["id"]) for d in designs}
        designs += [normalize(d, d.get("id", "?")) for d in board.get("designs", []) if (d.get("repo"), d.get("id")) not in seen]
        designs += [normalize(dict(p, id=f"PR#{p.get('number', '?')}", status="in-progress", kind="pr"), "PR")
                    for p in board.get("pull_requests", []) if isinstance(p, dict)]
    return designs

def cmd_index() -> None:
    designs = local_designs()
    rows = ["| id | 제목 | 상태 | 담당 | 영역 | 이슈 |", "| --- | --- | --- | --- | --- | --- |"]
    for d in designs:
        rows.append(f"| [{d['id']}]({Path(d['file']).name}) | {d.get('title','')} | {d.get('status','')} | {d.get('owner','')} | "
                    f"{', '.join('`'+a+'`' for a in d['areas'])} | {', '.join(map(str, d.get('issues', [])))} |")
    (DESIGNS / "INDEX.md").write_text("# 설계 목록 (자동 생성: `make designs`)\n\n" + "\n".join(rows) + "\n", encoding="utf-8")
    (DESIGNS / "board.json").write_text(json.dumps({"generated": datetime.date.today().isoformat(), "designs": designs}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"indexed {len(designs)} design(s) → docs/designs/INDEX.md, board.json")

def _take_opts(args: list[str]) -> tuple[list[str], set[str], str | None]:
    rest, skip, author = [], set(), None
    it = iter(args)
    for a in it:
        if a == "--exclude":
            if v := next(it, ""):
                skip.add(v)
        elif a == "--author":
            author = next(it, None)
        else:
            rest.append(a)
    return rest, skip, author

def cmd_overlap(args: list[str]) -> int:
    board = os.environ.get("DESIGN_BOARD")  # optional hub board.json (cross-repo)
    designs = load_board(board)
    args, skip, author = _take_opts(args)
    if args[:1] == ["--design"]:
        d = normalize(parse_front_matter(Path(args[1]).read_text(encoding="utf-8")), Path(args[1]).stem)
        areas = d["areas"]
        skip.add(d["id"])
    elif args[:1] == ["--diff"]:
        res = subprocess.run(["git", "diff", "--name-only", f"{args[1]}...HEAD"], capture_output=True, text=True, cwd=ROOT)
        if res.returncode != 0:
            print(f"error: git diff against {args[1]!r} failed: {res.stderr.strip()}", file=sys.stderr)
            return 2
        areas = [l for l in res.stdout.splitlines() if l and not l.startswith("docs/designs/")]
    else:
        areas = args
    hits = find_overlaps(areas, designs, skip, author)
    if not hits:
        print("no overlap with active designs or open PRs")
        return 0
    for d, common in hits:
        where = d.get("repo", "")
        label = d.get("title") or d.get("id")
        st = d['status'] + (', stale' if stale(d) else '')
        print(f"OVERLAP  {where} {d.get('id')} [{st}] {label} — owner {d.get('owner') or '?'} — {'; '.join(common[:4])}"
              + (f" — {d['url']}" if d.get("url") else f" — {d.get('file','')}"))
    print("→ Talk to the owner before starting: merge into their design, split the area, or sequence the work.")
    return 1

def cmd_brief(args: list[str]) -> None:
    board = args[1] if args[:1] == ["--board"] else os.environ.get("DESIGN_BOARD")
    lines = []
    for d in load_board(board):
        if d.get("status", "draft") in ACTIVE:
            st = d['status'] + (', stale' if stale(d) else '')
            lines.append(f"- {d.get('repo','')} {d.get('id')} [{st}] {d.get('owner') or '?'}: {d.get('title','')} | areas: {', '.join(d.get('areas', [])[:5])}")
    print("\n".join(lines[:40]) if lines else "(no active designs)")

def gh_json(args: list[str]):
    r = subprocess.run(["gh", *args], capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else None

def cmd_aggregate(repos_file: str, out: str) -> None:
    repos = [l.split("#")[0].strip() for l in Path(repos_file).read_text().splitlines() if l.split("#")[0].strip()]
    board = {"generated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"), "designs": [], "pull_requests": [], "errors": []}
    for repo in repos:
        files = gh_json(["api", f"repos/{repo}/contents/docs/designs", "--jq", "[.[] | select(.name | endswith(\".md\")) | .path]"])
        if files is None:
            board["errors"].append(f"{repo}: cannot list docs/designs")
        for path in files or []:
            if path.endswith(("TEMPLATE.md", "INDEX.md", "README.md")):
                continue
            r = subprocess.run(["gh", "api", f"repos/{repo}/contents/{path}", "-H", "Accept: application/vnd.github.raw"], capture_output=True, text=True)
            if r.returncode != 0:
                board["errors"].append(f"{repo}: cannot read {path}")
                continue
            d = parse_front_matter(r.stdout)
            if d:
                d = normalize(d, Path(path).stem)
                d.update(repo=repo, file=path, url=f"https://github.com/{repo}/blob/HEAD/{path}")
                board["designs"].append(d)
        prs = gh_json(["pr", "list", "--repo", repo, "--state", "open", "--limit", "50",
                       "--json", "number,title,author,isDraft,url,files,headRefOid"])
        if prs is None:
            board["errors"].append(f"{repo}: cannot list open PRs")
        for p in prs or []:
            paths = [f["path"] for f in p.get("files", [])]
            areas, design_ids = paths[:200], []
            # A design PR claims the areas it declares, not just its own .md file, so two
            # designs drafted at the same time can see each other before either merges.
            for path in paths:
                if re.match(r"^docs/designs/(?!TEMPLATE|INDEX|README)[^/]+\.md$", path):
                    raw = subprocess.run(["gh", "api", f"repos/{repo}/contents/{path}?ref={p['headRefOid']}",
                                          "-H", "Accept: application/vnd.github.raw"], capture_output=True, text=True).stdout
                    fm = parse_front_matter(raw)
                    if fm:
                        fm = normalize(fm, Path(path).stem)
                        areas += fm["areas"]
                        design_ids.append(fm["id"])
            board["pull_requests"].append({"repo": repo, "number": p["number"], "title": p["title"], "owner": "@" + p["author"]["login"],
                                           "draft": p["isDraft"], "url": p["url"], "areas": areas, "designs": design_ids})
    Path(out).write_text(json.dumps(board, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"board: {len(board['designs'])} designs, {len(board['pull_requests'])} open PRs from {len(repos)} repos → {out}")

def main() -> int:
    try:
        return run()
    except Exception as e:  # exit 1 means "overlap found", so a crash must not look like one
        print(f"error: {type(e).__name__}: {e}", file=sys.stderr)
        return 2

def run() -> int:
    if len(sys.argv) < 2:
        print(__doc__); return 2
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "index": cmd_index(); return 0
    if cmd == "overlap": return cmd_overlap(args)
    if cmd == "brief": cmd_brief(args); return 0
    if cmd == "aggregate": cmd_aggregate(args[0], args[1]); return 0
    print(__doc__); return 2

if __name__ == "__main__":
    sys.exit(main())
