# Snapendance Git Reference

## Ownership and authorship

The user owns repository history and authorship. By default, leave all changes **unstaged and
uncommitted**, including documentation. Read-only Git inspection is permitted when a repository
exists. Initialization, staging, commits, merges, pushes, tags, branch changes, PR operations, and
remote/settings changes require explicit authorization for the action. A request to implement a
feature does not automatically authorize those delivery actions. The project's Claude Code git
guard hook blocks these commands; the user runs them, for example with `! <command>`.

**Exception (authorized 2026-10-13):** agents may create a new branch with the plain forms
`git switch -c <name> [<start>]`, `git checkout -b <name> [<start>]`, or `git branch <name>
[<start>]`. The hook still blocks switching to an existing branch, force/reset variants
(`-C`, `-B`, `-f`), and deleting or renaming branches.

If no repository exists yet, report that and suggest the setup below; do not initialize one.

## Branch workflow (approved 2026-10-12): simplified Gitflow

| Branch | Purpose |
|--------|---------|
| `main` | Verified submission only. Receives `develop` once, at the final submission gate (task 11), tagged `v1.0.0`. |
| `develop` | Integration branch. Docs, rules, and config-only changes are committed here directly. |
| `feature/NN-<task-slug>` | One branch per implementation task from `develop`, named after the task file, e.g. `feature/01-app-shell-native-bridge`. |

- One task per feature branch. Merge into `develop` with `--no-ff` only after the task is verified
  and its external review is `approved`, so each task stays one visible unit in the history.
- Do not use release or hotfix branches. A fix found after a task merges gets its own
  `fix/NN-<slug>` branch from `develop`, or belongs to the next task when it is in its scope.
- Never rebase, force-push, rewrite, or delete shared branches (`main`, `develop`, merged feature
  branches). Preserve merged branches. Never discard unrelated working changes.
- Before starting a task, inspect the current branch. If the task's feature branch does not exist
  yet and the working tree is clean, create it from `develop`
  (`git switch -c feature/NN-<slug> develop`). If it already exists, or there are uncommitted
  changes, tell the user what to switch to and wait.

Suggested initial setup, run by the user:

```bash
git init -b main
git add . && git commit -m "chore: initial project setup"
git switch -c develop
```

## Commit checkpoints: work step by step

Never implement a whole task and split it into commits afterwards. The user reviews the diff
before every commit, so the work itself happens in commit-sized steps:

1. The approved task plan lists its **steps** in order. Each step is one small, coherent change
   (one behavior with its test, one config change, one screen section) that leaves the build
   green, and has its suggested commit message.
2. Implement **one step only**: its test first, then the minimum code, then its focused checks.
3. **Stop at the checkpoint.** Report the files changed, what to look for in the diff, the checks
   run, and the suggested commit message. Do not start the next step.
4. Continue only after the user says the step is committed (or asks for changes to it). If the
   working tree still has the previous step's uncommitted changes, ask before adding more.

If a step turns out bigger than planned, stop and propose splitting it rather than finishing it in
one go. Fixes from review of a step are their own small step.

## Commit messages

Use Conventional Commits with a scope from the task area: `feat(attendance): validate the office
radius`, `test(uploads): cover partial batch retry`, `docs(tasks): add task backlog`,
`chore(android): enable compose`. Suggest messages; do not apply them without authorization.

Do not change author identity, add co-author/generated-by trailers, or list agents as repository
contributors unless requested. The assessment's required AI disclosure belongs in the README and
`docs/agent-log.md`; it does not mandate commit trailers.
