# Plan: Task 12, async failure handling

**Found in:** a code audit after tasks 04-10 (2026-10-14) · **Branch:** `fix/12-async-failure-handling`
(from `develop` at `f85cdbf`) · **Status:** triaged mode (2026-10-14): agent commits each verified
step, one review at the end · **Done** (2026-10-14)

## Goal

Close the async failure paths that can leave the app stuck or misleading, before task 11.
Every item was confirmed against the code; tests come first wherever a test can show the bug.

## Decisions

| # | Decision | Choice |
|---|----------|--------|
| F1 | Pause overtaken by a resume | `appPaused` emits its blank state only if no open started while it was releasing (generation unchanged after the await). |
| F2 | Upload Manager over the camera | `CameraCubit.screenCovered()` releases the camera like a pause and sets a covered flag; `screenUncovered()` clears it and reopens. `appResumed` does nothing while covered. Both pushes in `camera_page.dart` go through one helper, which ignores a tap while covered (double tap) or while a photo is saving. Task 04's "leaving the screen releases the camera". |
| F3 | Capture save | `BatchCubit.capture` always clears `saving`: any error (not only the two typed ones) shows the existing "Couldn't save the photo" toast, and a failed read after a stored photo only logs. A failed submit shows "Couldn't queue the batch. Try again."; a failed schedule after it is left to the periodic task. `load`/`appResumed` failures are logged and keep the last state (the 3 s poll tries again). |
| F4 | Upload Manager actions | `UploadsCubit.load` keeps the last state on failure (the 2 s poll tries again); `retry`/`remove` failures emit a notice, shown as a snackbar: "Couldn't update the upload. Try again." A Retry whose scheduling fails is still applied and not reported (the periodic task runs it). |
| F5 | Worker setup | Opening the database and documents folder moves inside the worker's catch, so a setup failure returns `false` (WorkManager retry with backoff) instead of ending the work. |
| F6 | Uploads entry when the camera is blocked | The Upload Manager button (and the simulation settings) show in every camera state, not only when the preview is live. Flash stays live-only. |
| F7 | App start | Start-up moves into `startApp()` and `AppStartup` (`lib/app/startup.dart`). `reconcile` and WorkManager setup failures are logged and start-up continues (both run again next launch). If the database cannot open, a small error screen with Try again replaces Home; Try again is hidden while a retry runs. |
| F8 | Attendance before its record is read | `ScreenResumed` re-checks "marked today" only after the stored record has loaded, so the first resume cannot enable Mark early. |
| F9 | Small corrections | `availableCameras()` also maps `PlatformException` to unavailable. The manifest comment stops claiming "no microphone permission" (the camera plugin merges `RECORD_AUDIO`; removal is already deferred). The zoom comment says a failed call is ignored, not that the newest value wins. |

## Not in this task (added to Deferred improvements at task end)

- Zoom, flash, and focus roll back the UI when the hardware call fails.
- The attendance screen refreshes "marked today" at midnight while it stays open.
- Immutable list snapshots in upload models; not reading uploaded history on every poll; splitting
  `camera_page.dart` and the Upload Manager page into smaller files.
- Pinch, focus, and flash ignored while a capture is saving.

## Steps (commits)

All done, committed by the agent (triaged mode):

1. `1048f4c` `fix(camera): keep a reopened camera when an earlier pause finishes late` (F1).
2. `e11b6eb` `fix(camera): release the camera behind the Upload Manager` (F2).
3. `2e8f878` `fix(camera): show the Upload Manager button when the camera is blocked` (F6).
4. `f8e31d4` `fix(uploads): recover the shutter and the Upload Manager from storage errors` (F3, F4).
5. `d4f7330` `fix(uploads): retry the worker when its setup fails` (F5).
6. `ef7009f` `fix(app): start the app when upload storage setup fails` (F7).
7. `d1cca5d` `fix(attendance): wait for the stored record before allowing a mark` (F8).
8. `5c17458` `fix(camera): treat camera list errors as unavailable` (F9; no unit seam).
9. Review (approve with fixes: one P2, seven P3), then `d8d9416`
   `fix(uploads): address the failure-handling review`: capture clears `saving` on any error;
   the Upload Manager is not opened while covered or saving; a Retry's failed schedule is not
   reported; Try again is hidden while a retry runs; tests for a submit whose schedule and read
   fail. Not taken: releasing the camera is not serialized with the next open (P3-4); the quick
   home/return run on the phone ended with the camera open each time (deferred).
10. `docs: record the failure-handling task`.

## Verification

`flutter analyze`, full `flutter test`, `./gradlew testDebugUnitTest`. Galaxy A04s: camera →
Upload Manager → back (released, then preview returns); quick home/return several times (preview
returns each time); camera permission denied → Upload Manager still reachable; attendance opens
and marks as before.
