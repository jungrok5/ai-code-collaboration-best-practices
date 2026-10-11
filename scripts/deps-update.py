#!/usr/bin/env python3
"""Find newer commits for plugins this marketplace pins from other repositories, and prepare one bump at a time.

Every plugin entry in .claude-plugin/marketplace.json whose source is `github`, `url` or `git-subdir` is pinned to a
full commit `sha`. The upstream repository owes us nothing: no tags, no release process and no settings are assumed.

  target commit = the newest semver tag (v1.2.3, 1.2.3 or <plugin>--v1.2.3), when the repository has one and the
                  entry's `ref` is unset or a tag; otherwise the head of the entry's `ref` (a branch), or of the
                  default branch.

  scripts/deps-update.py check              JSON list of entries with a newer target (nothing is written)
  scripts/deps-update.py apply NAME BODY    move NAME to its target in marketplace.json and write a PR body to BODY

Only git and Python are needed (no GitHub API, no third-party actions), so it runs the same on github.com and on
GitHub Enterprise Server runners that can reach the upstream host.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MARKETPLACE = ROOT / ".claude-plugin/marketplace.json"
GIT_SOURCES = {"github", "url", "git-subdir"}
SEMVER = re.compile(r"^(?:(?P<prefix>[\w.-]+)--)?v?(?P<v>\d+\.\d+\.\d+)$")
# Changes here run code on every teammate's machine (hooks, MCP/LSP servers, executables, scripts): a person reads the diff.
CODE = re.compile(r"(^|/)(hooks/|bin/|scripts?/|\.mcp\.json$|\.lsp\.json$|monitors?/|settings\.json$)|\.(sh|py|js|mjs|cjs|ts|rb|go|ps1)$")


def git(*args: str, cwd: Path | None = None) -> str:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True).stdout


def repo_url(src: dict) -> str:
    """Claude Code reads `owner/repo` as a github.com repository, wherever this workflow runs."""
    url = src.get("repo") if src["source"] == "github" else src["url"]
    return url if "://" in url or url.startswith("git@") else f"https://github.com/{url}.git"


def version_key(v: str) -> tuple[int, ...]:
    return tuple(int(x) for x in v.split("."))


def target(name: str, src: dict) -> tuple[str, str | None, str]:
    """(sha, tag or None, how it was chosen) for one entry."""
    url = repo_url(src)
    tags = {}
    for line in git("ls-remote", "--tags", url).splitlines():
        sha, ref = line.split("\t")
        tag = ref.removeprefix("refs/tags/")
        peeled = tag.endswith("^{}")
        tag = tag.removesuffix("^{}")
        m = SEMVER.match(tag)
        if not m or (m.group("prefix") and m.group("prefix") != name):
            continue
        if peeled or tag not in tags:  # an annotated tag's ^{} line is the commit
            tags[tag] = (version_key(m.group("v")), sha)
    ref = src.get("ref")
    if tags and (ref is None or SEMVER.match(ref)):
        tag, (_, sha) = max(tags.items(), key=lambda kv: kv[1][0])
        return sha, tag, f"newest release tag `{tag}`"
    head = git("ls-remote", url, ref or "HEAD").split()
    if not head:
        raise SystemExit(f"deps-update: {name}: {url} has no {ref or 'HEAD'}")
    return head[0], None, f"head of `{ref}`" if ref else "head of the default branch (the repository has no release tags)"


def entries() -> list[dict]:
    return [p for p in json.loads(MARKETPLACE.read_text())["plugins"]
            if isinstance(p.get("source"), dict) and p["source"].get("source") in GIT_SOURCES]


def check() -> list[dict]:
    out = []
    for p in entries():
        sha, tag, why = target(p["name"], p["source"])
        if sha == p["source"].get("sha"):
            continue
        if p["source"].get("path") and p["source"].get("sha") and not describe(p["name"], p["source"], p["source"]["sha"], sha)[1]:
            continue  # only files outside the plugin's folder changed (site, CI...): nothing for teammates to get
        out.append({"name": p["name"], "from": p["source"].get("sha"), "to": sha, "tag": tag, "why": why})
    return out


def describe(name: str, src: dict, old: str | None, new: str) -> tuple[str, list[str], list[str]]:
    """Version line, changed files, and the changed files that run code."""
    path = src.get("path", "").strip("/")
    with tempfile.TemporaryDirectory() as d:
        repo = Path(d)
        git("init", "-q", cwd=repo)
        url = repo_url(src)
        git("fetch", "-q", "--depth=1", url, new, cwd=repo)
        def version(sha: str) -> str:
            try:
                return json.loads(git("show", f"{sha}:{path + '/' if path else ''}.claude-plugin/plugin.json", cwd=repo)).get("version", "?")
            except (subprocess.CalledProcessError, ValueError):
                return "?"
        files: list[str] = []
        old_v = "?"
        if old:
            try:
                git("fetch", "-q", "--depth=1", url, old, cwd=repo)
                files = git("diff", "--name-only", old, new, "--", path or ".", cwd=repo).split()
                old_v = version(old)
            except subprocess.CalledProcessError:
                files = ["(the pinned commit can no longer be fetched: the upstream history was rewritten or deleted)"]
        new_v = version(new)
    return f"{old_v} → {new_v}", files, [f for f in files if CODE.search(f)]


def apply(name: str, body_path: str) -> None:
    data = json.loads(MARKETPLACE.read_text())
    entry = next(p for p in data["plugins"] if p["name"] == name)
    src = entry["source"]
    old = src.get("sha")
    new, tag, why = target(name, src)
    versions, files, code = describe(name, src, old, new)
    src["sha"] = new
    if tag:
        src["ref"] = tag
    MARKETPLACE.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")

    url = repo_url(src).removesuffix(".git")
    compare = f"{url}/compare/{old}...{new}" if old and url.startswith("https://") else url
    lines = [
        f"Moves `{name}` to {why}: `{new[:12]}` (plugin.json version {versions}).",
        "",
        f"- Source: {url}" + (f" (path `{src['path']}`)" if src.get("path") else ""),
        f"- Changes: {compare}",
        "",
    ]
    if code:
        lines += ["### ⚠ Code that runs on every teammate's machine changed", "",
                  "Read these diffs before approving (hooks, MCP/LSP servers, executables and scripts run outside "
                  "Claude's permission checks):", ""] + [f"- `{f}`" for f in code] + [""]
    else:
        lines += ["No hooks, servers, executables or scripts changed: skills, docs and other text only.", ""]
    old_v, new_v = versions.split(" → ")
    if old_v == new_v:
        lines += [f"Note: plugin.json still says `{new_v}`. Installed copies update only when that string changes, so "
                  "teammates who already have the plugin keep the old files until upstream bumps the version; new "
                  "installs get this commit.", ""]
    lines += [f"<details><summary>{len(files)} changed file(s)</summary>", ""] + [f"- `{f}`" for f in files] + ["", "</details>", ""]
    lines += ["Opened by `.github/workflows/plugin-deps.yml` (`scripts/deps-update.py`). Same review rule for every "
              "pinned plugin, ours or third-party: docs/18-adding-skills.md."]
    Path(body_path).write_text("\n".join(lines) + "\n")
    title = f"chore(deps): bump plugin {name} to {tag or new[:12]} ({versions})"
    print(json.dumps({"name": name, "to": new, "tag": tag, "versions": versions, "code_changed": bool(code), "title": title}))


def main(argv: list[str]) -> None:
    if argv[:1] == ["check"]:
        print(json.dumps(check()))
    elif argv[:1] == ["apply"] and len(argv) == 3:
        apply(argv[1], argv[2])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
