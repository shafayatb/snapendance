#!/usr/bin/env python3
"""PreToolUse(Edit|Write|NotebookEdit): deny edits to files agents must not change.

- The assessment brief PDF (requirements source).
- docs/design/** (Claude Design export), except docs/design/README.md, where
  deviations from the design are recorded.
- android/local.properties (machine-specific SDK paths).
- Release signing material: *.jks, *.keystore, key.properties.
"""
import fnmatch
import json
import os
import sys

PROTECTED = [
    "Task_ Senior App Developer Technical Assessment.pdf",
    "docs/design/*",
    "android/local.properties",
    "*.jks",
    "*.keystore",
    "*key.properties",
]
ALLOWED = ["docs/design/README.md"]


def main():
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input") or {}
    path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
    if not path:
        return
    root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
    rel = os.path.relpath(os.path.realpath(path), os.path.realpath(root))
    if rel.startswith(".."):
        return
    if any(fnmatch.fnmatch(rel, p) for p in ALLOWED):
        return
    if any(fnmatch.fnmatch(rel, p) or fnmatch.fnmatch(os.path.basename(rel), p) for p in PROTECTED):
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"Blocked edit to protected file `{rel}`. The brief, the design export, local SDK paths, and "
                    "signing material are not edited by agents. Record design deviations in docs/design/README.md; "
                    "ask the user to change the file themselves if it really must change."
                ),
            }
        }))


if __name__ == "__main__":
    main()
