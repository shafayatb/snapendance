# Plan: Task 12, async failure handling

**Found in:** a code audit after tasks 04-10 (2026-10-14) · **Branch:** `fix/12-async-failure-handling`
(from `develop` at `f85cdbf`) · **Status:** triaged mode (2026-10-14): agent commits each verified
step, one review at the end · **In progress** (approved 2026-10-14)

## Goal

Close the async failure paths that can leave the app stuck or misleading, before task 11.
Every item was confirmed against the code; tests come first wherever a test can show the bug.

## Decisions

| # | Decision | Choice |
|---|----------|--------|
| F1 | Pause overtaken by a resume | `appPaused` emits its blank state only if no open started while it was releasing (generation unchanged after the await). |
| F2 | Upload Manager over the camera | `CameraCubit.screenCovered()` releases the camera like a pause and sets a covered flag; `screenUncovered()` clears it and reopens. `appResumed` does nothing while covered. Both pushes in `camera_page.dart` go through one helper. Task 04's "leaving the screen releases the camera". |
| F3 | Capture save | `BatchCubit.capture` resets `saving` in a `finally`; any storage error (not only the two typed ones) shows the existing "Couldn't save the photo" toast. `load`/`appResumed` failures are logged and keep the last state (the 3 s poll tries again). |
| F4 | Upload Manager actions | `UploadsCubit.load` keeps the last state on failure (the 2 s poll tries again); `retry`/`remove` failures emit a notice, shown as a snackbar: "Couldn't update this upload. Try again." |
| F5 | Worker setup | Opening the database and documents folder moves inside the worker's catch, so a setup failure returns `false` (WorkManager retry with backoff) instead of ending the work. |
| F6 | Uploads entry when the camera is blocked | The Upload Manager button (and the simulation settings) show in every camera state, not only when the preview is live. Flash stays live-only. |
| F7 | App start | Start-up moves into a `bootstrap()` function. `reconcile` and WorkManager setup failures are logged and start-up continues (both run again next launch). If the database cannot open, a small error screen with Try again replaces Home. |
| F8 | Attendance before its record is read | `ScreenResumed` re-checks "marked today" only after the stored record has loaded, so the first resume cannot enable Mark early. |
| F9 | Small corrections | `availableCameras()` also maps `PlatformException` to unavailable. The manifest comment stops claiming "no microphone permission" (the camera plugin merges `RECORD_AUDIO`; removal is already deferred). The zoom comment says a failed call is ignored, not that the newest value wins. |

## Not in this task (added to Deferred improvements at task end)

- Zoom, flash, and focus roll back the UI when the hardware call fails.
- The attendance screen refreshes "marked today" at midnight while it stays open.
- Immutable list snapshots in upload models; not reading uploaded history on every poll; splitting
  `camera_page.dart` and the Upload Manager page into smaller files.
- Pinch, focus, and flash ignored while a capture is saving.

## Steps (commits)

1. `fix(camera): keep a reopened camera when an earlier pause finishes late` (F1). Test: a pause
   whose close completes after a resume reopens; state must end ready.
2. `fix(camera): release the camera behind the Upload Manager` (F2). Cubit blocTests for
   covered/uncovered and a resume while covered; widget test that opening the Upload Manager
   closes the session. Phone: `dumpsys media.camera` shows no client while the Upload Manager is open.
3. `fix(camera): show the Upload Manager button when the camera is blocked` (F6). Widget test with
   permission denied finds the button.
4. `fix(uploads): recover the shutter and the Upload Manager from storage errors` (F3, F4). blocTests
   with a repository that throws on the read after save, on `load`, `retry`, and `remove`.
5. `fix(uploads): retry the worker when its setup fails` (F5). Test: setup that throws returns
   `false`.
6. `fix(app): start the app when upload storage setup fails` (F7). Tests: `bootstrap` with a
   failing reconcile still builds Home; a failing database open shows the error screen, and Try
   again recovers.
7. `fix(attendance): wait for the stored record before allowing a mark` (F8). ViewModel test: with
   a store that has not emitted, `ScreenResumed` leaves `isAttendanceLoaded` false.
8. `fix(camera): treat camera list errors as unavailable` (F9). The `PlatformException` mapping
   sits on the plugin boundary and has no unit seam; checked by analysis and the phone run. Same
   commit: the manifest and zoom comment corrections.
9. Review agent on the whole diff, fixes as their own step, then
   `docs: record the failure-handling task` (backlog row 12 Done, deferred rows, agent log entry
   without the audit prompt, `FRESH_PROMPT.md`).

## Verification

`flutter analyze`, full `flutter test`, `./gradlew testDebugUnitTest`. Galaxy A04s: camera →
Upload Manager → back (released, then preview returns); quick home/return several times (preview
returns each time); camera permission denied → Upload Manager still reachable; attendance opens
and marks as before.
