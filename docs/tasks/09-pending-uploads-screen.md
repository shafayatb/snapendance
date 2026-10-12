# Task 09: Upload Manager screen

**Status:** Not started · **Depends on:** 08 · **Track:** Flutter uploads

## Goal

Build the **Upload Manager** screen (design `U1-U3`, `U5`, light theme) with the "Pending Uploads"
list grouped by batch, driven by `UploadsCubit` from the durable queue, showing accurate per-item,
per-batch, and overall progress.

## In scope

- `UploadsCubit` reading queue state from the repository; widgets never touch storage directly.
- Header "Upload Manager" with back to the camera, and the BATCH SYNC PROGRESS card ("n of m
  uploaded", percentage, short note such as "Retrying automatically").
- "PENDING UPLOADS (n)" grouped by batch: batch header with time, "n of m uploaded", and a thin
  progress bar; a "n more synced in this batch" line when synced items are collapsed.
- Item rows: thumbnail (decoded from the local file), file name (mono), size, and status line:
  queued, waiting for connection, uploading, retrying (attempt x/5, no countdown unless task 08
  provides one), synced (time), failed (after 5 attempts or permanent, with reason; may wrap to
  two lines) with a Retry action. Missing local file: dashed placeholder and a failed reason.
- **START NEW UPLOAD BATCH** returns to the camera with an empty batch.
- Empty state "Nothing waiting to upload" (`U5`).
- Entry points: the camera's cloud icon with the pending-count badge and VIEW on the "Batch
  queued" snackbar. No Home entry: the Upload Manager is reached only from the camera.
- Refresh when the app resumes and when the engine changes state, so background changes appear.

## Out of scope

The connection pill and background scheduling (10). Pause All unless approved. Flat list (`U4`)
and dark theme variant.

## Acceptance criteria

- The list and progress reflect the database, including after app restart.
- Each item state renders its correct label; retrying shows the stored attempt count and limit.
- Progress counts are derived from item outcomes and match the list.
- Changes made by a sync run outside the screen appear without restarting the app.
- Large lists scroll smoothly; thumbnails are decoded at display size.

## Verification

- Cubit tests with a seeded test database: initial load, state changes after an engine run, resume
  refresh.
- Widget tests: each item state's label and the progress text; empty state; missing file.
- Device: queue batches, run the engine with failing and succeeding scenarios, watch the screen.

## Decisions for the plan

- Whether a missing-file item offers **Remove** (design `U1`), which deletes its queue record.
- What manual Retry on a Failed item resets (attempt count, status).
- Whether Pause All is included and what it means for queued work.

## References

Product reference (upload UI note), design frames `U1-U3`, `U5`, `C1`, `C10` and the deviations
table, verification reference (Sync, UI checks). Skills:
`flutter-build-responsive-layout`, `flutter-add-widget-test` (if installed).
