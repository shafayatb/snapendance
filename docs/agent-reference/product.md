# Snapendance Product Reference

## Source-of-truth order

1. Current user instructions and explicitly approved project decisions.
2. The supplied assessment PDF for required behavior, platforms, reference UI, and deliverables.
3. This product reference for the extracted requirements and the distinction between brief
   requirements and proposed choices.
4. The [UI design](../design/README.md) for appearance and interaction details, including its
   recorded deviations. It does not override required behavior.
5. The [task backlog](../tasks/README.md) for task order, scope, and acceptance criteria, then the
   approved task plan under `docs/plans/`, when it exists.
6. The implementation, verification, delivery, and Git references.
7. Existing code and tests as evidence of current behavior, not permission to change the scope.

If a required behavior and an approved design conflict, stop the affected work and report the
specific conflict. Continue independent authorized work. Do not silently invent a resolution.
Reference screenshots and the UI design inform appearance; decorative labels and sample data do not
invent business rules.

## Brief and current scope

Source: `Task_ Senior App Developer Technical Assessment.pdf` at the project root, reviewed on
2026-10-12. The text and screenshots define the assessment. This document extracts the requirements
and records proposed choices; it does not replace direct user instructions.

The two tasks assess different stacks. **Approved (2026-10-12):** one combined APK from this
single project, with the native Compose attendance screen inside the Flutter application's Android
host. The brief does not explicitly require one app or define data sharing between the features;
none is planned.

The Flutter project name is `snapendance`; the product name is **Snapendance**. Android is the
assessment target. Preserve the generated iOS scaffold without undertaking iOS work.

## Task 1: Geo-Fenced Attendance System - Native Android

Required:

- One Compose `AttendanceScreen` for office setup and attendance.
- A Set Office Location action that obtains the current GPS coordinates and saves them locally.
- A Mark Attendance action that is enabled/functional only within 50 meters of the saved office.
- A real-time distance indicator while the screen is active.
- Useful permission, location-service, and hardware error handling.

Use the screenshot's office-location card, coordinates, distance/range hierarchy, and attendance
action as the UI reference, refined by `docs/design/` (frames `A1-A9`, `P2`). The screenshot's
sample coordinates and 09:00-10:30 time window are not specified business rules. Never hard-code
them as live data or impose the time window; the design replaces that line with the last
attendance time.

Approved choices (2026-10-12):

- Eligibility is strict: enabled only at a distance of at most 50 meters, using unrounded
  distance. No hysteresis band (the design's 55 m re-lock suggestion is rejected).
- A usable fix is at most 30 seconds old with reported accuracy at most 25 meters and precise
  permission. Otherwise the screen shows the weak/stale GPS state. These are project safeguards,
  not employer-specified thresholds or guarantees of GPS accuracy.
- The location panel is the coordinates panel (saved coordinates, save time, fix accuracy). No map
  SDK or static map image.
- Use foreground location updates only. No background geofencing, background location
  permission, or automatic check-in.
- Obtain a fresh fix for office setup and revalidate eligibility on the attendance action.
- Keep the last attendance time locally and show it on the attendance card. Extended history is
  out of scope.

## Task 2: Advanced Camera & Sync Engine - Flutter

Required:

- `CameraPreviewScreen` with a functioning camera preview.
- Pinch-to-zoom, a zoom slider, and rounded controls reflecting available rear cameras/zoom choices.
- Tap-to-focus with a visible marker at the tap point.
- Multiple batches of captured images and a Pending Uploads list.
- Background work that retries pending uploads as network conditions permit.
- Failed/low-bandwidth/offline uploads remain queued with their local images.
- Automatic retry without needing another upload tap.

Show 0.5x only when the device/plugin can supply the corresponding capability. Lens switching and
digital zoom are different controls; do not fabricate optical labels. Handle unavailable focus or
camera features explicitly. The suggested upload screenshot's non-image files, decorative status
copy, and extra controls do not extend the required feature set.

UI follows `docs/design/` (camera `C1-C11`, Upload Manager `U1-U5`). Approved from the design:
the Upload Manager is reached only from the camera (cloud icon with pending badge, or VIEW on the
"Batch queued" snackbar); uploads are grouped by batch; the camera is dark and the rest of the app
is light; the camera's settings icon opens the labeled mock-API simulation sheet; the retry limit
is 5 attempts. An item becomes Failed only after the limit or on a permanent failure, and its label
says so. See the design README's deviations table for labels that must not be copied literally.

Proposed batch model: an open batch collects images, submission freezes its membership and queues
it, and a subsequent capture starts a new batch. Settle this behavior in the camera/batch plan.

## App shell

Flutter home screen with two entries: **Attendance** (opens the native screen) and **Camera &
Uploads**. The Attendance entry shows no live summary, because attendance data stays native and is
not shared with Flutter. The Camera & Uploads entry may show the pending upload count, which is
Flutter-owned data.

Persist image files in app-owned durable storage and queue metadata locally. Display batch progress
from per-image outcomes. A partially successful batch retries unfinished images without repeating
confirmed successes. Recover interrupted processing and prevent concurrent uploads of the same item.

## API simulation

The employer supplies no API and permits either commented-out API calls or hard-coded mock success
and failure responses. Use an executable `MockUploadApi` behind an upload boundary so queue and
retry behavior can be demonstrated.

Use repeatable scenarios: success, fail once then succeed, timeout (30 s, simulating low
bandwidth), no network, and permanent failure (design frame `C11`). Persist configuration/attempt state needed by background work; random results or
UI-only flags make a recovery demo unreliable. Label the simulation in the app and README.

Real captures, durable persistence, scheduling, and retry transitions must work. Mock receipts do
not establish real server delivery, HTTP behavior, or throughput. Record those limits accurately.

## Scope limits

Do not add authentication, an administration dashboard, a backend, iOS delivery, video recording,
OCR, analytics, subscriptions, attendance time restrictions, or feature-to-feature data sharing
without a request. Do not trade away required camera controls or durable retry behavior for polish.
Do not carry over dates, grading weights, or requirements from other projects.

## Submission

The brief requires:

1. Complete functioning source in a public GitHub repository.
2. A README covering project title/description, architecture/structure and BLoC/Cubit summaries,
   generative AI usage with essential prompts, clone/run steps, and screenshots or GIFs.
3. A link to the built release APK.

The 48-72 hour estimate is not a confirmed dated deadline. No iOS binary or demo video is required
by the text. Screenshots/GIFs should show the actual installed app. Publication/upload is a separate
delivery action, not authorized by the presence of these requirements.
