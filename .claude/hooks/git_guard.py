#!/usr/bin/env python3
"""PreToolUse(Bash): deny Git/GitHub commands that change history, refs, or settings.

AGENTS.md makes Git human-owned: agents may inspect (status, diff, log, show, ...)
but must not init, stage, commit, push, tag, merge, switch branches, change
remotes/config, or create PRs unless the user explicitly authorizes it.
"""
import json
import re
import shlex
import sys

# Subcommands that are always denied.
DENY = {
    "init", "add", "commit", "push", "pull", "merge", "rebase", "reset", "revert",
    "cherry-pick", "am", "stash", "checkout", "switch", "restore", "clean", "rm",
    "mv", "gc", "prune", "filter-branch", "filter-repo", "update-ref", "replace",
    "notes", "submodule", "worktree", "clone",
}
# Subcommands allowed only in these read-only forms (first argument after the subcommand).
READ_ONLY_FORMS = {
    "branch": {None, "-a", "-r", "-l", "--list", "-v", "-vv", "--show-current", "--contains", "--merged", "--no-merged"},
    "tag": {None, "-l", "--list", "--contains", "--points-at"},
    "remote": {None, "-v", "show", "get-url"},
    "config": {"--get", "--get-all", "--get-regexp", "-l", "--list", "--show-origin"},
}
GH_DENY = {
    "pr": {"create", "merge", "close", "reopen", "edit", "comment", "review", "ready"},
    "repo": {"create", "edit", "delete", "rename", "archive", "fork", "sync"},
    "release": {"create", "delete", "edit", "upload"},
    "issue": {"create", "close", "reopen", "edit", "comment", "delete"},
}
GIT_GLOBAL_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
WRAPPERS = {"rtk", "proxy", "command", "sudo", "env", "nohup", "time", "xargs"}


def segments(command: str):
    # Split on shell control operators and command substitution openers.
    for part in re.split(r"&&|\|\||[;|&\n()]|`", command):
        try:
            words = shlex.split(part, posix=True)
        except ValueError:
            words = part.split()
        # Drop leading env assignments and wrapper commands (rtk, rtk proxy, sudo, ...).
        while words and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]) or words[0] in WRAPPERS):
            words = words[1:]
        if words:
            yield words


def git_violation(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        opt = args[i].split("=", 1)[0]
        i += 2 if opt in GIT_GLOBAL_OPTS_WITH_VALUE and "=" not in args[i] else 1
    if i >= len(args):
        return None
    sub, rest = args[i], args[i + 1:]
    if sub in DENY:
        return f"git {sub}"
    if sub in READ_ONLY_FORMS:
        first = rest[0] if rest else None
        if first not in READ_ONLY_FORMS[sub]:
            return f"git {sub} {' '.join(rest)}".strip()
    return None


def gh_violation(args):
    if len(args) >= 2 and args[1] in GH_DENY.get(args[0], set()):
        return f"gh {args[0]} {args[1]}"
    if args and args[0] == "api" and re.search(r"(-X|--method)[ =]?(POST|PUT|PATCH|DELETE)", " ".join(args), re.I):
        return "gh api (write method)"
    return None


def main():
    data = json.load(sys.stdin)
    command = (data.get("tool_input") or {}).get("command") or ""
    for words in segments(command):
        name = words[0].rsplit("/", 1)[-1]
        found = git_violation(words[1:]) if name == "git" else gh_violation(words[1:]) if name == "gh" else None
        if found:
            print(json.dumps({
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        f"Blocked `{found}`: Git and GitHub writes are human-owned in this project (AGENTS.md). "
                        "Leave changes unstaged and suggest the command or a Conventional Commit message to the user instead. "
                        "If the user has explicitly authorized this exact action, ask them to run it with `! <command>`."
                    ),
                }
            }))
            return
    # No opinion: let the normal permission flow decide.


if __name__ == "__main__":
    main()
