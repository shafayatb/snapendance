# Task 08: Sync engine and mock upload API

**Status:** Not started · **Depends on:** 07 · **Track:** Flutter uploads

## Goal

Build a UI-independent `SyncEngine` that uploads queued images through an `UploadApi` boundary, keeps
images queued on network/timeout failure, retries transient failures, and never re-uploads confirmed
items. Back it with an executable `MockUploadApi`.

## In scope

- `UploadApi` interface; `MockUploadApi` with hard-coded, repeatable scenarios (design `C11`):
  success, fail once then succeed, timeout (no reply for 30 s), no network, permanent failure.
- Scenario configuration persisted (not UI-only) so a background isolate sees the same setting.
- 30 s upload timeout so a slow connection becomes a retryable failure.
- `SyncEngine.run()`: atomically claim pending/retryable items, upload, record each outcome, release.
  Claims expire so an interrupted run is recoverable. No database transaction is held during an
  upload.
- Item states: pending, uploading, retryable failure (with attempt count), uploaded, permanent
  failure. Batch progress derived from item outcomes.
- Retry limit of 5 attempts; after the limit the item is Failed and its stored error says so
  (for example "Failed after 5 attempts · last: timed out"). Failed items keep their image.
- The "Upload simulation" bottom sheet (design `C11`) opened from the camera's settings icon,
  labeled MOCK API, persisting the selected scenario.

## Out of scope

Scheduling and connectivity triggers (10), the Upload Manager UI (09), a real HTTP client.

## Acceptance criteria

- Network/timeout failures leave the item and its file in place with an incremented attempt count.
- A later run uploads retryable items; already uploaded items are skipped.
- A partially successful batch retries only unfinished items.
- Two concurrent runs never upload the same item twice.
- An expired claim from an interrupted run is picked up again.
- Permanent failures and exhausted retries are explicit states with an error message.
- The selected mock scenario is labeled in the UI and is read the same way from a fresh engine
  instance.

## Verification

- Engine tests with a real test SQLite database and a scripted fake/mocked API: every criterion
  above, including concurrency (two runs in parallel) and claim expiry with an injected clock.
- `MockUploadApi` tests: each scenario's sequence of responses is deterministic.
- Device: trigger a run manually (temporary debug action or task 09 UI as planned) and observe states.

## Decisions for the plan

- Per-item backoff, if any, beyond WorkManager's, and whether the engine owns a next-attempt time
  (only then may the UI show a countdown).
- Whether upload progress is simulated per item (design `U1` shows "UPLOADING · 64%") or shown as
  per-item completion only.
- Whether the simulation sheet is visible in the release build for the demo.
- Claim expiry duration.

## References

Product reference (API simulation), design frame `C11` and the deviations table (U1, U3),
implementation reference (Persistence and sync), verification reference (Sync). Skill: `flutter-implement-json-serialization` only if a JSON payload is modeled.
