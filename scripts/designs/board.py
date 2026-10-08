#!/usr/bin/env python3
"""Design board: index approved/in-flight designs and detect overlapping work.

Every design doc in docs/designs/*.md starts with front matter (see TEMPLATE.md).
This tool is deterministic (no LLM, no tokens):

  board.py index                      write docs/designs/INDEX.md + board.json for this repo
  board.py overlap <path-or-glob>...   list active designs whose areas overlap the given paths/globs/areas
  board.py overlap --design FILE       check one design against every other active design
  board.py overlap --diff BASE         check the files changed since BASE (e.g. origin/main)
  board.py aggregate REPOS_FILE OUT    hub only: merge designs + open PRs of many repos (needs gh)
  board.py brief [--board FILE]        compact one-line-per-design list for an agent's context

Overlap rule: two areas overlap when one glob matches the other's literal prefix, or named areas
(api:/x, db:users, ui:login) are equal or one is a prefix of the other.
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

def parse_front_matter(text: str) -> dict:
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}
    data = {}
    for line in m.group(1).splitlines():
        line = re.sub(r"\s+#.*$", "", line).rstrip()
        if not line or ":" not in line:
            continue
        k, v = line.split(":", 1)
        v = v.strip()
        if v.startswith("[") and v.endswith("]"):
            items = [x.strip().strip('"').strip("'") for x in v[1:-1].split(",")]
            data[k.strip()] = [x for x in items if x]
        else:
            data[k.strip()] = v.strip('"').strip("'")
    return data

def local_designs(repo: str | None = None) -> list[dict]:
    repo = repo or os.environ.get("GITHUB_REPOSITORY") or ROOT.name
    out = []
    for f in sorted(DESIGNS.glob("*.md")):
        if f.name in ("TEMPLATE.md", "INDEX.md", "README.md"):
            continue
        d = parse_front_matter(f.read_text(encoding="utf-8"))
        if not d:
            continue
        d.setdefault("id", f.stem)
        d["file"] = str(f.relative_to(ROOT))
        d["repo"] = repo
        d.setdefault("areas", [])
        if isinstance(d["areas"], str):
            d["areas"] = [d["areas"]]
        out.append(d)
    return out

def _literal_prefix(glob: str) -> str:
    return re.split(r"[*?\[]", glob, maxsplit=1)[0]

def areas_overlap(a: str, b: str) -> bool:
    a, b = a.strip(), b.strip()
    if not a or not b:
        return False
    named = lambda s: re.match(r"^[a-z]+:", s) is not None
    if named(a) or named(b):
        return named(a) and named(b) and (a.startswith(b) or b.startswith(a))
    if fnmatch.fnmatch(a, b) or fnmatch.fnmatch(b, a):
        return True
    pa, pb = _literal_prefix(a), _literal_prefix(b)
    return pa.startswith(pb) or pb.startswith(pa) if (pa and pb) else False

def find_overlaps(areas: list[str], designs: list[dict], skip_id: str | None = None) -> list[tuple[dict, list[str]]]:
    hits = []
    for d in designs:
        if d.get("status", "draft") not in ACTIVE or d.get("id") == skip_id:
            continue
        common = sorted({f"{x} ~ {y}" for x in areas for y in d.get("areas", []) if areas_overlap(x, y)})
        if common:
            hits.append((d, common))
    return hits

def load_board(path: str | None) -> list[dict]:
    designs = local_designs()
    if path and Path(path).exists():
        board = json.loads(Path(path).read_text(encoding="utf-8"))
        seen = {(d["repo"], d["id"]) for d in designs}
        designs += [d for d in board.get("designs", []) if (d.get("repo"), d.get("id")) not in seen]
        designs += [dict(p, id=f"PR#{p['number']}", status="in-progress", kind="pr") for p in board.get("pull_requests", [])]
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

def cmd_overlap(args: list[str]) -> int:
    board = os.environ.get("DESIGN_BOARD")  # optional hub board.json (cross-repo)
    designs = load_board(board)
    skip = None
    if args[:1] == ["--design"]:
        d = parse_front_matter(Path(args[1]).read_text(encoding="utf-8"))
        areas, skip = d.get("areas", []), d.get("id", Path(args[1]).stem)
        if isinstance(areas, str):
            areas = [areas]
    elif args[:1] == ["--diff"]:
        res = subprocess.run(["git", "diff", "--name-only", f"{args[1]}...HEAD"], capture_output=True, text=True, cwd=ROOT)
        areas = [l for l in res.stdout.splitlines() if l and not l.startswith("docs/designs/")]
    else:
        areas = args
    hits = find_overlaps(areas, designs, skip)
    if not hits:
        print("no overlap with active designs or open PRs")
        return 0
    for d, common in hits:
        where = d.get("repo", "")
        label = d.get("title") or d.get("id")
        st = d.get('status') + (', stale' if stale(d) else '')
        print(f"OVERLAP  {where} {d.get('id')} [{st}] {label} — owner {d.get('owner','?')} — {'; '.join(common[:4])}"
              + (f" — {d['url']}" if d.get("url") else f" — {d.get('file','')}"))
    print("→ Talk to the owner before starting: merge into their design, split the area, or sequence the work.")
    return 1

def cmd_brief(args: list[str]) -> None:
    board = args[1] if args[:1] == ["--board"] else os.environ.get("DESIGN_BOARD")
    lines = []
    for d in load_board(board):
        if d.get("status", "draft") in ACTIVE:
            st = d.get('status') + (', stale' if stale(d) else '')
            lines.append(f"- {d.get('repo','')} {d.get('id')} [{st}] {d.get('owner','?')}: {d.get('title','')} | areas: {', '.join(d.get('areas', [])[:5])}")
    print("\n".join(lines[:40]) if lines else "(no active designs)")

def gh_json(args: list[str]):
    r = subprocess.run(["gh", *args], capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else None

def cmd_aggregate(repos_file: str, out: str) -> None:
    repos = [l.split("#")[0].strip() for l in Path(repos_file).read_text().splitlines() if l.split("#")[0].strip()]
    board = {"generated": datetime.datetime.utcnow().isoformat(timespec="minutes") + "Z", "designs": [], "pull_requests": [], "errors": []}
    for repo in repos:
        files = gh_json(["api", f"repos/{repo}/contents/docs/designs", "--jq", "[.[] | select(.name | endswith(\".md\")) | .path]"])
        if files is None:
            board["errors"].append(f"{repo}: cannot list docs/designs")
        for path in files or []:
            if path.endswith(("TEMPLATE.md", "INDEX.md", "README.md")):
                continue
            raw = subprocess.run(["gh", "api", f"repos/{repo}/contents/{path}", "-H", "Accept: application/vnd.github.raw"], capture_output=True, text=True).stdout
            d = parse_front_matter(raw)
            if d:
                d.setdefault("id", Path(path).stem)
                d.update(repo=repo, file=path, url=f"https://github.com/{repo}/blob/HEAD/{path}")
                d["areas"] = d.get("areas", []) if isinstance(d.get("areas"), list) else [d["areas"]]
                board["designs"].append(d)
        prs = gh_json(["pr", "list", "--repo", repo, "--state", "open", "--limit", "50", "--json", "number,title,author,isDraft,url,files"]) or []
        for p in prs:
            board["pull_requests"].append({"repo": repo, "number": p["number"], "title": p["title"], "owner": "@" + p["author"]["login"],
                                           "draft": p["isDraft"], "url": p["url"], "areas": [f["path"] for f in p.get("files", [])][:200]})
    Path(out).write_text(json.dumps(board, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"board: {len(board['designs'])} designs, {len(board['pull_requests'])} open PRs from {len(repos)} repos → {out}")

def main() -> int:
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
