# Task 04: Camera preview and lifecycle

**Depends on:** 01 · **Track:** Flutter camera

## Goal

Add `CameraPreviewScreen` with a working rear-camera preview, a `CameraCubit`, permission and
failure handling, and correct release/reacquire of the camera across app lifecycle changes.

## In scope

- Add `flutter_bloc` and the `camera` plugin (verify the current version and its Android CameraX
  implementation against the toolchain). No audio: still capture does not need the microphone.
- `features/camera/` with a camera service boundary around the plugin and `CameraCubit` with
  explicit states: initializing, permission denied, no camera available, ready, error.
- Full-bleed dark preview (design `C1`) with correct aspect ratio and cropping, top/bottom scrims,
  and the close (X) button returning to home. Home gains the **Camera & Uploads** entry (design
  `H1`/`H2`); its pending-count summary arrives with task 07.
- Blocked states from design `C8` (permission denied: explanation, Open app settings, Back to home)
  and `C9` (camera unavailable: Try again). Permission is re-checked on resume.
- Dark camera theme tokens from the design system (camera only).
- Dispose the controller when the app goes inactive/backgrounded and reinitialize on resume.
- **Spike:** on the physical test phone, record what `availableCameras()` returns and the min/max
  zoom of each back camera, to decide in task 05 whether 0.5x is a separate lens or a zoom ratio
  below 1.0 on the logical camera. Save findings in `docs/agent-log.md`.

## Out of scope

Zoom, lens buttons, flash (05), focus (06), capture and batches (07).

## Acceptance criteria

- With permission granted, the preview appears and is not stretched.
- Denied and permanently denied permission show explanations with a retry or settings action.
- No camera or camera-in-use failures show an error state instead of a crash.
- Backgrounding and returning restores the preview; leaving the screen releases the camera; the
  native Attendance screen and other apps can use the camera afterwards.
- Spike findings are recorded for the test device.

## Verification

- Cubit tests with a fake camera service: init success, permission denied, no cameras, init
  failure, and pause/resume transitions.
- Widget test: each Cubit state renders its UI and recovery action.
- Device: physical phone for preview and lifecycle; deny/grant permission paths; rotate if the
  screen supports rotation.

## Decisions for the plan

- Permission flow: the plugin's own access errors vs. `permission_handler`.
- Orientation policy (portrait-locked camera screen vs. rotation support).
- Preview resolution preset.

## References

Product reference (Task 2), design frames `C1`, `C8`, `C9`, `H1`, implementation reference (camera
lifecycle), verification reference (Camera and batches). Skills: `flutter-apply-architecture-best-practices`, `flutter-add-widget-test`
(if installed). Docs: `camera` package and its lifecycle example; `flutter_bloc` Cubit docs.
