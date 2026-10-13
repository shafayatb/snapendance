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
| 02 | [Attendance: set office location](02-attendance-office-setup.md) | 01 | Done |
| 03 | [Attendance: live distance and marking](03-attendance-distance-marking.md) | 02 | Done |
| 04 | [Camera preview and lifecycle](04-camera-preview.md) | 01 | Done |
| 05 | [Camera zoom, lens, and flash controls](05-camera-zoom-controls.md) | 04 | Done |
| 06 | [Tap-to-focus](06-camera-tap-focus.md) | 04 | Done |
| 07 | [Capture and durable batches](07-capture-batches.md) | 04 | Not started |
| 08 | [Sync engine and mock upload API](08-sync-engine.md) | 07 | Not started |
| 09 | [Upload Manager screen](09-pending-uploads-screen.md) | 08 | Not started |
| 10 | [Background sync and connectivity](10-background-sync.md) | 08, 09 | Not started |
| 11 | [Submission](11-submission.md) | all | Not started |

Status values: `Not started`, `Planned` (plan approved), `In progress`, `In review`, `Done`.
Update a task's status here as it moves; task files do not carry status.
Tasks 02-03 (native) and 04-07 (Flutter camera) are independent tracks after task 01.

Tasks 01-06 are done. Because of the 2026-10-14 20:00 deadline, the remaining work runs in a
triaged mode (approved 2026-10-14): tasks 04-06 as one camera task and 07-10 as one uploads task,
agent commits and merges, no per-step checkpoints, one review at the end.

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
| 2026-10-14 | Task 03: live distance from one tracking request (1 s, no displacement filter); Mark Attendance re-checks with a fix taken after the tap; one mark per calendar day; distance rounded up for display. See the task 03 plan. |
| 2026-10-14 | Deadline 2026-10-14 20:00: triaged mode (merged tasks 04-06 and 07-10, agent commits and merges, one final review). |
| 2026-10-14 | Tasks 04-06 (camera): `permission_handler`; portrait-only app; first back camera at `veryHigh`, cover-cropped; zoom buttons from the real range (0.5× only below 1.0; the A04s shows 1×, 2×, 5×); flash Off/Auto/On only with a flash unit; no flip button; camera released when hidden or paused, reopened at 1× with flash off. See the camera plan, C1-C8. |
| 2026-10-13 | Task 02: Fused Location Provider; first fix accepted within 15 s from a stream of updates; replacing a saved office needs confirmation; Preferences DataStore; the attendance screen is portrait-only for now. See the task 02 plan, D1-D2, D8, D10, and step 8. |

## Open decisions and owning task

| Decision | Task |
|----------|------|
| Batch model (open batch, freeze on submit), queue schema, storage location | 07 |
| Backoff, simulated upload progress, whether the simulation sheet ships in release | 08 |
| Remove action for missing-file items; Pause All inclusion | 09 |
| Work scheduling (unique one-off + periodic fallback), connectivity indicator semantics | 10 |
| Release signing and APK hosting | 11 |

## Deferred improvements

Found during a task, deliberately left for later. Pick one up only when the user assigns it.

| Found in | Improvement | Why deferred |
|----------|-------------|--------------|
| 03 | Listen for location turned on/off on screen (`PROVIDERS_CHANGED_ACTION`, plan D8) instead of noticing at the 30 s stale check; show the last fix's age in the A9 helper. | Cut for the deadline. |
| 04 | Switch between several physical back cameras (wide/ultra-wide/tele as separate cameras); today only the first back camera and its zoom range are used. | The A04s exposes one back camera; nothing to test it on. |
| 02 | Keep a running GPS fetch across Activity recreation (send `ScreenStopped` only when not `isChangingConfigurations`), then remove the portrait lock. Until then, a dark-mode, font-size, locale, or split-screen change still cancels a fetch silently, and Android 16 ignores the lock on screens ≥ 600 dp wide. | User chose the portrait lock for the deadline. |
