# Task 07: Capture and durable batches

**Status:** Not started · **Depends on:** 04 · **Track:** Flutter uploads

## Goal

Capture images into batches that are stored durably on the device, and submit a batch to the upload
queue with the reference's **UPLOAD BATCH (n)** button.

## In scope

- Shutter button that captures a still; ignore taps while a capture is in progress.
- Copy each capture from temporary storage into app-owned durable storage (`path_provider`) before
  recording it. Only then insert its metadata.
- SQLite (`sqflite`, planned) schema for batches and items: stable IDs, batch ID, file path, size,
  capture time, status, attempts, last error, timestamps. Schema versioning from the start.
- Batch model (proposed): one open batch collects captures; submitting freezes it as queued; the next
  capture starts a new batch.
- UI from design `C1`, `C6`, `C7`, `C10`: last-capture thumbnail with count badge (dashed
  placeholder when empty), capture-in-progress shutter state with controls disabled and the
  "Saving photo n…" toast, **UPLOAD BATCH (n)** (disabled at 0), and the "Batch of n photos
  queued" snackbar (4 s). Its VIEW action and the cloud icon's pending badge are wired in task 09.
- Home's Camera & Uploads card shows the pending count when the queue isn't empty (design `H2`).
- Startup reconciliation: files without metadata and metadata without files are handled as defined
  in the plan.

## Out of scope

Uploading, retries, workers (08, 10); the Upload Manager screen (09).

## Acceptance criteria

- Several batches can be captured and submitted; each keeps its own images.
- Captured images and batch state survive app kill and restart.
- A failed copy or database write does not produce a successful-looking item; the user is told.
- An empty batch cannot be submitted; repeated submit taps create one queued batch.
- The badge count and button count match the open batch's stored items.

## Verification

- Repository tests against a real SQLite database in tests (for example `sqflite_common_ffi`) and a
  temporary directory: insert/read, freezing on submit, new batch after submit, reconciliation, and
  failure paths with an injected failing file operation.
- Cubit tests for capture-in-progress guarding and count updates.
- Device: capture multiple batches, force-close, reopen, confirm images and counts.

## Decisions for the plan

- Batch model confirmation and naming.
- Storage directory, file naming, and image size/quality settings.
- Where queue state lives (`features/uploads/data`) and how camera and uploads features share it
  without widgets touching storage.

## References

Product reference (batches), design frames `C1`, `C6`, `C7`, `C10`, `H2`, implementation
reference (Persistence and sync), verification reference (Camera and batches). Docs: `CameraController.takePicture`, `path_provider`, `sqflite`.
