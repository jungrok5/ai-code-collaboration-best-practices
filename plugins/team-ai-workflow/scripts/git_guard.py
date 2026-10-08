#!/usr/bin/env python3
"""PreToolUse guard for Bash commands that run git (called by git-guard.sh).

Two team rules, enforced deterministically:
  - never commit directly on main/master/develop/release/*
  - never force-push (--force, -f, --force-with-lease, +refspec, --mirror) or delete a branch,
    except your own feature branch

Reads the hook JSON on stdin; exit 2 blocks the command and stderr is shown to the agent.
This is a guard rail, not a sandbox: branch protection on GitHub is the real boundary.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys

PROTECTED = re.compile(r"^(main|master|develop|release/.*)$")
FEATURE = re.compile(r"^(feat|fix|chore|docs|refactor|test|ci|perf)/")
PREFIX_CMDS = {"sudo", "env", "command", "exec", "time", "nohup", "nice", "xargs"}
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env"}
PUSH_OPTS_WITH_VALUE = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
SEPARATORS = re.compile(r"^[;&|()]+$")


def strip_heredocs(cmd: str) -> str:
    """Drop heredoc bodies so text inside a commit message is never read as a command."""
    lines, out, i = cmd.split("\n"), [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        for m in re.finditer(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", line):
            end = m.group(2)
            i += 1
            while i < len(lines) and lines[i].strip() != end:
                i += 1
        i += 1
    return "\n".join(out)


def segments(cmd: str) -> list[list[str]]:
    cmd = strip_heredocs(cmd.replace("\\\n", " "))
    # Command substitution and newlines start new commands.
    cmd = cmd.replace("$(", " ( ").replace("`", " ; ").replace("\n", " ; ")
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    try:
        tokens = list(lex)
    except ValueError:  # unbalanced quotes: fall back to plain splitting
        tokens = cmd.split()
    segs, cur = [], []
    for t in tokens:
        if SEPARATORS.match(t):
            if cur:
                segs.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        segs.append(cur)
    return segs


def branch_of(cwd: str, git_dir: str | None) -> str:
    args = ["git"] + (["--git-dir", git_dir] if git_dir else [])
    for sub in (["symbolic-ref", "--short", "-q", "HEAD"], ["rev-parse", "--abbrev-ref", "HEAD"]):
        try:
            r = subprocess.run(args + sub, cwd=cwd, capture_output=True, text=True, timeout=5)
        except (OSError, subprocess.SubprocessError):
            return ""
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    return ""


def block(msg: str) -> None:
    print(f"BLOCKED: {msg}", file=sys.stderr)
    sys.exit(2)


def check_push(args: list[str], branch: str) -> None:
    force = delete = False
    all_refs = None
    positional: list[str] = []
    explicit_repo = False
    it = iter(args)
    for a in it:
        name = a.split("=", 1)[0]
        if name in PUSH_OPTS_WITH_VALUE:
            explicit_repo |= name == "--repo"
            if "=" not in a and not (name == "-o" and len(a) > 2):
                next(it, None)
        elif name in ("--force", "--force-if-includes") or name.startswith("--force-with-lease"):
            force = True
        elif a == "--mirror":
            force, all_refs = True, "--mirror"
        elif a in ("--all", "--branches", "--tags"):
            all_refs = a
        elif a in ("--delete", "-d"):
            delete = True
        elif a.startswith("--"):
            pass
        elif a.startswith("-") and len(a) > 1:
            flags = a[1:]
            if "o" in flags:  # -o<value> or -xo <value>
                flags = flags[: flags.index("o")]
                if a.endswith("o"):
                    next(it, None)
            force |= "f" in flags
            delete |= "d" in flags
        else:
            positional.append(a)
    refspecs = positional if explicit_repo else positional[1:]
    if all_refs and force:
        block(f"force-push with {all_refs} rewrites every branch, including shared ones. Push your feature branch only.")
    dests = []
    for ref in refspecs:
        if ref.startswith("+"):
            force, ref = True, ref[1:]
        src, _, dst = ref.rpartition(":") if ":" in ref else ("", "", ref)
        if ":" in ref and not src:
            delete = True  # git push origin :branch
        dst = re.sub(r"^refs/heads/", "", dst)
        dests.append(branch if dst in ("HEAD", "@") else dst)
    if not dests:
        dests = [branch]
    for dst in dests:
        if delete and (PROTECTED.match(dst) or not FEATURE.match(dst)):
            block(f"deleting branch '{dst}' is not allowed from an agent session.")
        if force and (PROTECTED.match(dst) or not FEATURE.match(dst)):
            block(f"force-push is only allowed to your own feature branch (target: '{dst}'). Merge instead of rewriting shared history.")


def main() -> int:
    try:
        cmd = json.load(sys.stdin).get("tool_input", {}).get("command") or ""
    except (ValueError, AttributeError):
        return 0
    if "git" not in cmd:
        return 0
    cwd = os.getcwd()
    for seg in segments(cmd):
        i = 0
        while i < len(seg) and (seg[i] in PREFIX_CMDS or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[i]) or
                                (i > 0 and seg[i - 1] in PREFIX_CMDS and seg[i].startswith("-"))):
            i += 1
        if i >= len(seg):
            continue
        if seg[i] == "cd":
            target = seg[i + 1] if i + 1 < len(seg) else os.path.expanduser("~")
            cwd = os.path.normpath(os.path.join(cwd, os.path.expanduser(target)))
            continue
        if os.path.basename(seg[i]) != "git":
            continue
        i += 1
        dir_, git_dir = cwd, None
        while i < len(seg) and seg[i].startswith("-"):
            name, has_eq, val = seg[i].partition("=")
            if name in GIT_OPTS_WITH_VALUE and not has_eq:
                val = seg[i + 1] if i + 1 < len(seg) else ""
                i += 1
            if name == "-C":
                dir_ = os.path.normpath(os.path.join(dir_, os.path.expanduser(val)))
            elif name == "--git-dir":
                git_dir = os.path.normpath(os.path.join(dir_, os.path.expanduser(val)))
            i += 1
        if i >= len(seg):
            continue
        sub, args = seg[i], seg[i + 1:]
        if sub not in ("commit", "push"):
            continue
        branch = branch_of(dir_, git_dir)
        if sub == "commit" and PROTECTED.match(branch):
            block(f"you are on protected branch '{branch}'. Create a feature branch first: git switch -c <type>/<issue>-<slug>")
        if sub == "push":
            check_push(args, branch)
    return 0


if __name__ == "__main__":
    sys.exit(main())
