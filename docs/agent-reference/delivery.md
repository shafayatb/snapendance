# Snapendance Delivery Reference

## Task scope and preparation

Work on one explicitly assigned task at a time. A task has one reviewable outcome and acceptance
criteria; attendance, camera controls, persistence, and background recovery are not a single giant
acceptance gate. Keep the app buildable after each implementation task.

Before product implementation, read the project instructions/references, inspect the current code,
settle consequential decisions, and save the agreed plan to `docs/plans/YYYY-MM-DD-<task>.md`.
The plan breaks the task into ordered, commit-sized steps, each with a suggested commit message.
Show the plan before implementing, then implement one step at a time and stop at each commit
checkpoint for the user's diff review ([Git reference](git.md)), after the step review and
handoff below. Never one-shot a task. The current request to write agent rules does not authorize
app implementation, a new Git repository, or publication.

The preparatory documents are not an approved product design or implementation plan. Preserve
proposed-versus-approved labels. If no next task has been assigned or agreed, say so rather than
inventing approval in a handoff prompt.

## Git

Git ownership, the simplified Gitflow branch workflow, and commit conventions are in the
[Git reference](git.md). Read it at task boundaries and before suggesting any Git step.

## Step checkpoint: review and handoff

Before reporting any step's commit checkpoint, in this order:

1. **Separate review.** Dispatch a read-only review agent with a self-contained prompt: the step
   as written in the plan, the diff and new files, the specs to check against, and the checks to
   run. It returns severity-ordered findings with file/line references, command results, skipped
   checks, and a verdict; it never edits files. Confirm each finding against the code, fix
   confirmed in-scope ones (re-review if the fix is non-trivial), and report out-of-scope ones
   without implementing them.
2. **Log** the step in `docs/agent-log.md`, including the review verdict. Leave out any prompt the
   user asks not to log.
3. **Handoff.** Replace `FRESH_PROMPT.md` for the next step (see the fresh-context boundary).
4. **Checkpoint report:** files changed, what to look for in the diff, checks run, the review
   verdict and findings, and the suggested commit message. Then stop.

Routine docs/rules-only edits skip the review agent unless the user asks for one.

## Implementation task completion report

Deliver a report in chat with:

1. **Completed task:** exact scope and acceptance status, including anything incomplete.
2. **TDD evidence:** each test written first, the plausible regression, actual expected failure,
   and current result. Distinguish manual hardware checks from test-first evidence.
3. **Files changed:** each created/modified/deleted file and why.
4. **Verification:** commands/results, device scenarios, and broader checks deliberately skipped.
5. **Decisions/deviations:** confirmed constraints, assumptions, approved choices, and limitations.
6. **Git** (per the [Git reference](git.md)): current branch and status when Git exists, unrelated changes, the suggested
   Conventional Commit message(s), and the merge step for the user (for example
   `git switch develop && git merge --no-ff feature/NN-<slug>` after review approval). If no
   repository exists, report that without initializing one.
7. **Next task:** the approved next task or a clear statement that none has been assigned.
8. **Fresh-context handoff:** one self-contained prompt and its path.

Append the task's actual user request, approach, decisions, problems, test/device evidence, and
Git status to `docs/agent-log.md`. Do not record a commit that did not happen or put sensitive
credentials/location/image data into the log.

For meaningful behavioral changes, demonstrate that the regression test fails when the relevant
behavior is removed or changed, when practical. Record the actual mutation and restore it before
finishing. Never mutate unrelated work or claim a mutation check that did not occur. Keep tests
claimed as regression protection in the repository.

## Fresh-context boundary

At every step checkpoint, replace the entire root `FRESH_PROMPT.md` with one prompt for the next
step of the current task; after the task's last step, with one prompt for the next task. Print
that prompt in chat as well. The prompt must stand alone and include:

- Snapendance's name, Android target, native attendance/Flutter camera boundary, and current scope.
- The exact next step (from the approved plan) or next task and its acceptance criteria, or
  instructions to await an assignment.
- The commits expected to exist before it starts, and to stop and ask if they do not.
- The task's feature branch name and that the user creates it from `develop` before work starts.
- Relevant references, approved design/plan, current code/tests, and prior verification evidence.
- Read/inspect-before-editing instructions and strict meaningful test-first development.
- Implement only that task; do not scaffold later work; leave changes unstaged/uncommitted.
- Finish verification, update the report/log and `FRESH_PROMPT.md`, and stop.

Do not append historical prompts, leave a finished step's or task's prompt active, or execute the
new prompt yourself. End an implementation-task report with **STOPPED — ready for a fresh context.**

Routine docs/rules/symlink-only edits need a concise file/check report. They do not create a new
implementation review cycle or require `FRESH_PROMPT.md`, a new task log, or a device run.

## External review handoff

After an implementation task, use the project-specific local handoff directory:

```text
/tmp/snapendance-agent-review/
  task-report.md
  codex-review.md
  status.txt
```

On macOS the real directory is `/private/tmp/snapendance-agent-review/`. This is temporary review
state, not a permanent project record. Preserve durable decisions/evidence in the project log.

Before a continued implementation task, read any existing report/status/review. A status of
`changes-requested` applies only to the task identified in its report; verify and address its
confirmed in-scope findings before new work. Approval for another task is never inherited.

The implementer writes `task-report.md` with the report above plus the exact task, date, and
acceptance status. If a different task's review files exist, archive them into a uniquely named
task subfolder without overwriting prior history. Then set `status.txt` to `ready-for-review`.
Do not write `codex-review.md` or approve your own work.

A separate reviewer inspects the task-related code/tests/specs and runs proportional checks,
then writes a severity-ordered review with file/line references, command results, skipped checks,
and a verdict. The reviewer sets status to `approved` or `changes-requested` and stays read-only
with respect to product code/tests unless the user asks for implementation. Do not dispatch a
reviewer for routine documentation edits or claim a review without a real reviewer.

Confirm review findings against the actual code. Reproduce behavioral findings test-first, record
the remedy and evidence, and keep fixes within the assigned scope. Report out-of-scope findings
without implementing them automatically. Update the task report and return it to `ready-for-review`
after fixes; only the reviewer can approve.

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
