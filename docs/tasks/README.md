# Snapendance Task Backlog

Each file in this folder defines **what** one implementation task delivers: goal, scope, acceptance
criteria, verification, and the decisions its plan must settle. The **how** belongs in an approved
plan saved to `docs/plans/YYYY-MM-DD-<task>.md` when the task starts. A task file is not
authorization to implement; work starts only when the user assigns the task.

The per-task workflow is in the [delivery](../agent-reference/delivery.md) and
[Git](../agent-reference/git.md) references.

Acceptance criteria may be refined in the approved plan. If a plan changes a criterion, update the
task file in the same task so this folder stays the current scope record.

## Tasks

| # | Task | Depends on | Status |
|---|------|------------|--------|
| 01 | [App shell and native attendance entry](01-app-shell-native-bridge.md) | - | Done |
| 02 | [Attendance: set office location](02-attendance-office-setup.md) | 01 | In progress |
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
Update a task's status here as it moves; task files do not carry status.
Tasks 02-03 (native) and 04-07 (Flutter camera) are independent tracks after task 01.

Task 01 is done (2026-10-13). No next task is assigned yet; the root `FRESH_PROMPT.md` says to
await one.

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
| 2026-10-13 | Task 01: one `navigation` channel method `openAttendance`; IBM Plex bundled in Flutter and Android; Material Icons Rounded (Flutter) and Material Symbols Rounded vectors (Compose). See the task 01 plan, D1-D2 and D6-D7. |

## Open decisions and owning task

| Decision | Task |
|----------|------|
| Location provider (fused vs. platform), re-setting the office | 02 |
| Camera permission approach; how the device exposes ultra-wide (lens vs. zoom < 1.0) | 04 |
| Lens button set, flash modes, whether the front-camera flip is included | 05 |
| Batch model (open batch, freeze on submit), queue schema, storage location | 07 |
| Backoff, simulated upload progress, whether the simulation sheet ships in release | 08 |
| Remove action for missing-file items; Pause All inclusion | 09 |
| Work scheduling (unique one-off + periodic fallback), connectivity indicator semantics | 10 |
| Release signing and APK hosting | 11 |
