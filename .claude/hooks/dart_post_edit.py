#!/usr/bin/env python3
"""PostToolUse(Edit|Write): format an edited Dart file, then analyze it.

Both steps run in one script so analyzer line numbers refer to the formatted
file. Analyzer findings are returned to Claude as context; they never block.
Generated files and files outside the project's own sources are skipped.
"""
import json
import os
import subprocess
import sys

SKIP_DIRS = ("build/", ".dart_tool/", "docs/")
SKIP_SUFFIXES = (".g.dart", ".freezed.dart", ".mocks.dart")


def main():
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input") or {}
    path = tool_input.get("file_path") or ""
    if not path.endswith(".dart") or path.endswith(SKIP_SUFFIXES) or not os.path.isfile(path):
        return
    root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    rel = os.path.relpath(os.path.realpath(path), os.path.realpath(root))
    if rel.startswith("..") or rel.startswith(SKIP_DIRS):
        return

    fmt = subprocess.run(["dart", "format", path], cwd=root, capture_output=True, text=True)
    notes = []
    if fmt.returncode != 0:
        notes.append(f"dart format failed for {rel}:\n{(fmt.stderr or fmt.stdout).strip()}")

    analyze = subprocess.run(["dart", "analyze", path], cwd=root, capture_output=True, text=True)
    issues = [
        line.strip() for line in analyze.stdout.splitlines()
        if line.strip().startswith(("error -", "warning -", "info -"))
    ]
    if issues:
        notes.append(f"dart analyze {rel} reported {len(issues)} issue(s):\n" + "\n".join(issues))

    if notes:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": "\n\n".join(notes),
            }
        }))


if __name__ == "__main__":
    main()
