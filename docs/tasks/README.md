# Snapendance Task Backlog

Each file in this folder defines **what** one implementation task delivers: goal, scope, acceptance
criteria, verification, and the decisions its plan must settle. The **how** belongs in an approved
plan saved to `docs/plans/YYYY-MM-DD-<task>.md` when the task starts. A task file is not
authorization to implement; work starts only when the user assigns the task.

## Workflow per task

1. The user assigns a task and creates its branch `feature/NN-<task-file-slug>` from `develop`.
   Read `AGENTS.md`, the task file, and the references it lists.
2. Inspect the current code, settle the task's open decisions, and write the plan. Get approval.
3. Implement the plan's steps one at a time, test-first. After each step, stop at the commit
   checkpoint so the user reviews the diff and commits before the next step. Verify on Android and
   record evidence in `docs/agent-log.md`.
4. Update the task's status below, write the review handoff and `FRESH_PROMPT.md`, suggest the
   commit message(s), and stop. After review approval the user merges into `develop` (`--no-ff`).

Acceptance criteria may be refined in the approved plan. If a plan changes a criterion, update the
task file in the same task so this folder stays the current scope record.

## Tasks

| # | Task | Depends on | Status |
|---|------|------------|--------|
| 01 | [App shell and native attendance entry](01-app-shell-native-bridge.md) | - | In progress |
| 02 | [Attendance: set office location](02-attendance-office-setup.md) | 01 | Not started |
| 03 | [Attendance: live distance and marking](03-attendance-distance-marking.md) | 02 | Not started |
| 04 | [Camera preview and lifecycle](04-camera-preview.md) | 01 | Not started |
| 05 | [Camera zoom, lens, and flash controls](05-camera-zoom-controls.md) | 04 | Not started |
| 06 | [Tap-to-focus](06-camera-tap-focus.md) | 04 | Not started |
| 07 | [Capture and durable batches](07-capture-batches.md) | 04 | Not started |
| 08 | [Sync engine and mock upload API](08-sync-engine.md) | 07 | Not started |
| 09 | [Upload Manager screen](09-pending-uploads-screen.md) | 08 | Not started |
| 10 | [Background sync and connectivity](10-background-sync.md) | 08, 09 | Not started |
| 11 | [Submission](11-submission.md) | all | Not started |

Status values: `Not started`, `Planned` (plan approved), `In progress`, `In review`, `Done`.
Tasks 02-03 (native) and 04-07 (Flutter camera) are independent tracks after task 01.

Task 01 is assigned (2026-10-12); its fresh-context prompt is in the root `FRESH_PROMPT.md`.

## Approved decisions

| Date | Decision |
|------|----------|
| 2026-10-12 | One combined APK from this single project: Flutter app with a native Compose attendance Activity in its Android host. |
| 2026-10-12 | Android package and application ID: `com.shafayatb.snapendance`. |
| 2026-10-12 | Simplified Gitflow: `main` (submission, `v1.0.0`), `develop`, `feature/NN-<task-slug>`; `--no-ff` merges; user runs all Git commands. |
| 2026-10-12 | Flutter presentation uses Cubit (`flutter_bloc`); native attendance uses a ViewModel exposing `StateFlow`. |
| 2026-10-12 | The unavailable API is simulated by an executable mock with repeatable success/failure scenarios. |
| 2026-10-12 | UI follows `docs/design/` with the deviations recorded in its README. |
| 2026-10-12 | Home has two entries (Attendance, Camera & Uploads); no attendance summary on Home; the Upload Manager is reached only from the camera. |
| 2026-10-12 | Light app theme; camera always dark. |
| 2026-10-12 | Local-only (gitignored): the brief PDF, `docs/design/`, `FRESH_PROMPT.md`. |
| 2026-10-12 | Attendance: strict ≤ 50 m, no hysteresis; usable fix ≤ 30 s old and ≤ 25 m accuracy; coordinates panel, no map. |
| 2026-10-12 | Uploads: grouped by batch; retry limit 5; mock timeout 30 s; mock simulation sheet from the camera settings icon. |

## Open decisions and owning task

| Decision | Task |
|----------|------|
| Platform-channel shape; fonts and icons approach | 01 |
| Location provider (fused vs. platform), re-setting the office | 02 |
| Camera permission approach; how the device exposes ultra-wide (lens vs. zoom < 1.0) | 04 |
| Lens button set, flash modes, whether the front-camera flip is included | 05 |
| Batch model (open batch, freeze on submit), queue schema, storage location | 07 |
| Backoff, simulated upload progress, whether the simulation sheet ships in release | 08 |
| Remove action for missing-file items; Pause All inclusion | 09 |
| Work scheduling (unique one-off + periodic fallback), connectivity indicator semantics | 10 |
| Release signing and APK hosting | 11 |
