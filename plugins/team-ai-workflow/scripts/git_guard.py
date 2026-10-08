#!/usr/bin/env python3
"""PreToolUse guard for Bash commands that run git (called by git-guard.sh).

Two team rules, enforced deterministically:
  - never commit directly on main/master/develop/release/*
  - never force-push (--force, -f, --force-with-lease, +refspec, --mirror) or delete a branch,
    except a feature-prefixed branch (feat/, fix/, ..., ai/, copilot/)

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
# Force-push is allowed to feature-prefixed branches (team naming, plus agent branches). It cannot know who
# else committed there; GitHub rulesets and review are the real protection for shared branches.
FEATURE = re.compile(r"^(feat|fix|chore|docs|refactor|test|ci|perf|build|style|revert|ai|copilot)/")
PREFIX_CMDS = {"sudo", "env", "command", "exec", "time", "nohup", "nice", "xargs"}
# Shell keywords that can precede a command in the same segment: `if x; then git commit; fi`.
SHELL_WORDS = {"if", "then", "else", "elif", "do", "while", "until", "{", "}", "!", "fi", "done"}
PREFIX_OPTS_WITH_VALUE = {"-u", "-g", "-C", "-D", "-n"}  # sudo -u user, nice -n 5, ...
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env"}
PUSH_OPTS_WITH_VALUE = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
SEPARATORS = re.compile(r"^[;&|()]+$")


def strip_heredocs(cmd: str) -> str:
    """Drop heredoc bodies so text inside a commit message is never read as a command."""
    lines, out, i = cmd.split("\n"), [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        for m in re.finditer(r"(?<!<)<<-?(?!<)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", line):
            if line[: m.start()].count("'") % 2 or line[: m.start()].count('"') % 2:
                continue  # "<<" inside a quoted string is text, not a heredoc
            end = m.group(2)
            i += 1
            while i < len(lines) and lines[i].strip() != end:
                i += 1
        i += 1
    return "\n".join(out)


def segments(cmd: str) -> list:
    cmd = strip_heredocs(cmd.replace("\\\n", " "))
    # Command substitution and newlines start new commands.
    cmd = cmd.replace("$(", " ( ").replace("`", " ; ").replace("\n", " ; ")
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    try:
        tokens = list(lex)
    except ValueError:  # unbalanced quotes: fall back to plain splitting
        tokens = cmd.split()
    # Simple commands are lists of words; separators are kept as strings so "(" / ")" can scope `cd`.
    segs: list = []
    cur: list[str] = []
    for t in tokens:
        if SEPARATORS.match(t):
            if cur:
                segs.append(cur)
            cur = []
            segs.append(t)
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
            block(f"force-push is only allowed to feature-prefixed branches like feat/… or fix/… (target: '{dst}'). Merge instead of rewriting shared history.")


def main() -> int:
    try:
        payload = json.load(sys.stdin)
        cmd = payload.get("tool_input", {}).get("command") or ""
    except (ValueError, AttributeError):
        return 0
    if not isinstance(cmd, str) or "git" not in cmd:
        return 0
    cwd = payload.get("cwd") if isinstance(payload.get("cwd"), str) and os.path.isdir(payload["cwd"]) else os.getcwd()
    saved: list[str] = []
    for seg in segments(cmd):
        if isinstance(seg, str):  # separator: a subshell's `cd` does not outlive it
            for ch in seg:
                if ch == "(":
                    saved.append(cwd)
                elif ch == ")" and saved:
                    cwd = saved.pop()
            continue
        i, env_git_dir = 0, None
        while i < len(seg):
            w = seg[i]
            if w in PREFIX_CMDS or w in SHELL_WORDS:
                i += 1
                while i < len(seg) and seg[i].startswith("-"):  # options of sudo/env/nice ...
                    i += 2 if seg[i] in PREFIX_OPTS_WITH_VALUE else 1
            elif re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w):
                if w.startswith("GIT_DIR="):
                    env_git_dir = os.path.normpath(os.path.join(cwd, os.path.expanduser(w[8:])))
                i += 1
            else:
                break
        if i >= len(seg):
            continue
        if seg[i] == "cd":
            target = seg[i + 1] if i + 1 < len(seg) else os.path.expanduser("~")
            if target != "-":  # `cd -` cannot be resolved here; keep the current guess
                cwd = os.path.normpath(os.path.join(cwd, os.path.expanduser(target)))
            continue
        if os.path.basename(seg[i]) != "git":
            continue
        i += 1
        dir_, git_dir = cwd, env_git_dir
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
