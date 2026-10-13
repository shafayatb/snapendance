# Snapendance Delivery Reference

## Task flow

1. **Assign.** Work only on a task the user assigned; if none is assigned, say so. Create its
   branch as described in the [Git reference](git.md).
2. **Plan.** Read the task file and the references it lists, inspect the code, and settle the
   task's open decisions. Save the plan to `docs/plans/YYYY-MM-DD-<task>.md` as ordered,
   commit-sized steps, each with a suggested commit message. Get approval before implementing.
3. **Step.** Implement one step: its test first ([verification](verification.md)), then the
   minimum code, then its focused checks. A step is one small, coherent change that keeps the
   build green. If it grows bigger than planned, stop and propose a split.
4. **Step checkpoint.** Report the files changed, what to look for in the diff, the checks run,
   and the suggested commit message, then stop. Continue only after the user says the step is
   committed or asks for changes. If the previous step is still uncommitted, ask before adding
   more.
5. **Task review.** After the last step, dispatch one read-only review agent on the whole task
   diff, or on a single step if the user asks. Give it a self-contained prompt: the task file and
   plan, the diff and new files, the specs, and the checks to run. Tell it not to edit files or
   report small visual differences. It returns severity-ordered findings with file/line
   references, command results, skipped checks, and a verdict. Confirm each finding against the
   code, fix confirmed in-scope ones as their own step, and report out-of-scope ones without
   implementing them.
6. **Task end.** Update the task's status in the [backlog](../tasks/README.md), add the task's
   entry to `docs/agent-log.md`, rewrite `FRESH_PROMPT.md`, give the completion report, and stop.

Mid-task, a fresh session finds its place from the plan and `git log`; `FRESH_PROMPT.md` changes
only at task end.

Docs/rules-only edits need no review agent, log entry, `FRESH_PROMPT.md`, or device run unless the
user asks. Report the files changed and the checks run.

## Agent log

One entry per task in `docs/agent-log.md`: the user's actual requests, approach, decisions,
problems, test/device evidence, review verdict, and Git status. Leave out prompts the user asks
not to log, commits that did not happen, and credentials, precise locations, or captured images.

## Task completion report

In chat:

1. Scope and acceptance status, including anything incomplete.
2. Test-first evidence: each test, the regression it catches, its observed failure, and the
   current result. Keep manual hardware checks separate.
3. Files changed and why.
4. Verification: commands, device scenarios, and checks skipped.
5. Decisions, deviations, and limitations.
6. Review verdict and findings.
7. Git: branch, status, suggested commit message(s), and the merge for the user
   (`git switch develop && git merge --no-ff feature/NN-<slug>`).
8. The next assigned task, or that none is assigned.

End with **STOPPED — ready for a fresh context.**

## FRESH_PROMPT.md

Replace the whole file with one standalone prompt for the next task and print it in chat. Include
the project and scope, the next task and its acceptance criteria (or to await an assignment), the
commits expected before it starts (stop and ask if they are missing), the branch name, and the
plan, references, and prior evidence to read. `AGENTS.md` loads automatically, so do not restate
its rules. Never execute the prompt yourself.

## Final submission gate

- Verify required attendance, camera, batch, and automatic retry flows on Android.
- Run relevant automated checks and the final release build; install and exercise that artifact.
- Keep mock mode, hardware constraints, scheduler limitations, and any unverified behavior explicit.
- Replace starter README material with complete clone/run instructions, architecture/Cubit summaries,
  actual AI prompts/usage, and screenshots/GIFs from the app.
- Exclude secrets, signing material, local machine files, and private demo data from public source.
  The brief PDF, `docs/design/`, and `FRESH_PROMPT.md` are gitignored (local-only) by decision.
- Prepare the public repository and release APK link; upload/push/publish only when requested.
- Suggest the final merge of `develop` into `main` (`--no-ff`) and the `v1.0.0` tag for the user.
- No iOS release, demo video, or additional backend is required by the supplied assessment.
