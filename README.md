# Snapendance

Snapendance is an Android app built for the Intelligent Machines senior app developer assessment.
It combines two features in one APK:

- **Geo-fenced attendance** (native Kotlin + Jetpack Compose). Save the office location from the
  phone's GPS, watch the live distance to it, and mark attendance only within 50 meters.
- **Camera and resilient uploads** (Flutter). A custom camera with pinch zoom, a zoom slider, zoom
  presets, flash, and tap-to-focus captures photos into batches. Submitted batches go into a
  durable queue that uploads in the background, survives restarts, and retries automatically when
  the network returns.

**Release APK:** [snapendance release APK (Google Drive)](https://drive.google.com/file/d/1Cm6mu6jIDfzDc_nlEkrMrbQmQgPMQ3sl/view?usp=sharing)

## Screenshots

All captured from the signed release APK on a Samsung Galaxy A04s (Android 14). Coordinates are
pixelated.

| Home | Attendance: in range | Attendance: marked |
|------|----------------------|--------------------|
| <img src="docs/screenshots/home.png" width="240"> | <img src="docs/screenshots/attendance-in-range.png" width="240"> | <img src="docs/screenshots/attendance-marked.png" width="240"> |

| Weak GPS blocks marking | Location services off | Camera: tap-to-focus |
|-------------------------|-----------------------|----------------------|
| <img src="docs/screenshots/attendance-weak-gps.png" width="240"> | <img src="docs/screenshots/attendance-location-off.png" width="240"> | <img src="docs/screenshots/camera-focus.jpg" width="240"> |

| Camera: batch of 3 | Upload Manager: uploading | Two batches queued offline |
|--------------------|---------------------------|----------------------------|
| <img src="docs/screenshots/camera-batch.jpg" width="240"> | <img src="docs/screenshots/uploads-progress.png" width="240"> | <img src="docs/screenshots/uploads-offline.png" width="240"> |

| Attendance: out of range | Mock API failure: retrying | Mock API scenarios |
|--------------------------|----------------------------|--------------------|
| <img src="docs/screenshots/attendance-out-of-range.jpg" width="240"> | <img src="docs/screenshots/uploads-retrying.png" width="240"> | <img src="docs/screenshots/mock-api.png" width="240"> |

| Pinch, slider, presets, focus | Offline → online: automatic upload |
|-------------------------------|------------------------------------|
| <img src="docs/screenshots/camera-zoom-focus.gif" width="240"> | <img src="docs/screenshots/offline-auto-retry.gif" width="240"> |

## Project structure and approach

### One APK, two UI stacks

The project is a Flutter app whose Android host also contains a native Compose screen. Flutter owns
Home, the camera, and the Upload Manager. Tapping **Attendance** on Home calls the
`com.shafayatb.snapendance/navigation` method channel (`openAttendance`), and `MainActivity`
starts the native `AttendanceActivity`. A second channel (`.../device`, `hasCameraFlash`) tells
Flutter whether the phone has a flash unit.

```
lib/                                  Flutter (Dart)
  main.dart, app/                     start-up, Home, theme, native launcher
  features/camera/
    data/                             CameraService over the camera plugin
    domain/                           zoom presets, tap → focus point mapping
    presentation/                     CameraCubit, CameraState, CameraPage
  features/uploads/
    data/                             sqflite database, queue repository, sync engine,
                                      mock upload API, WorkManager scheduler, connectivity
    domain/                           batch and item models, upload statuses
    presentation/                     BatchCubit, UploadsCubit, Upload Manager, mock API sheet
android/app/src/main/kotlin/com/shafayatb/snapendance/
  MainActivity.kt                     Flutter host and method channels
  attendance/
    location/                         Fused Location Provider source, fix policy, distance
    office/, marking/                 DataStore stores for the office and the day's mark,
                                      AttendanceEligibility (the 50 m rule)
    ui/                               AttendanceViewModel, AttendanceScreen and its cards
```

Both sides follow the same layering: the UI renders immutable state and sends user intents; a
Cubit or ViewModel owns the state; repositories and services own storage, hardware, and the
network. Widgets and composables never touch the database, files, GPS, or uploads directly.

### Flutter Cubits

| Cubit | Owns | Main intents |
|-------|------|--------------|
| `CameraCubit` | Camera lifecycle and controls: initializing, permission denied or permanently denied (with Open settings), unavailable (no camera or it failed to open), ready; zoom within the camera's real range; flash Off/Auto/On (only with a flash unit); the focus marker. Releases the camera when the app pauses or the Upload Manager covers it and reopens it on return. | `start`, `retry`, `appPaused`/`appResumed`, `screenCovered`/`screenUncovered`, `setZoom`, `pinchStarted`/`pinchUpdated`, `cycleFlash`, `tapToFocus` |
| `BatchCubit` | The open batch being captured: photo count and last thumbnail, saving state, notices (capture failed, batch queued, empty batch). Submitting freezes the batch as queued and schedules the upload work. | `load`, `capture`, `submit`, `setScenario` (mock API), `appResumed` |
| `UploadsCubit` | The Upload Manager: queued batches with per-photo status (pending, uploading, retrying, uploaded, failed), attempt counts, last errors, and a connectivity hint. Polls the database while visible. | `start`, `load`, `retry`, `remove`, `appResumed` |

### Native attendance (Kotlin, Coroutines/Flow)

`AttendanceViewModel` exposes one `StateFlow<AttendanceUiState>` and a channel of one-off
`AttendanceEvent`s, and takes `AttendanceAction`s from `AttendanceScreen` (MVI). While the screen is
resumed and an office is saved, it tracks location updates and computes the distance.
`AttendanceEligibility` decides whether a mark is allowed: a saved office, precise permission,
location services on, a fix at most 30 s old with at most 25 m accuracy, and a distance of at most
50.0 m (no rounding, no hysteresis). **Mark Attendance** checks again with a fresh fix taken after
the tap, so walking away after the button turns on is caught. One mark per calendar day is saved in
DataStore. Permission denial, approximate-only permission, location services off, and weak or stale
fixes each have their own message and action.

### Durable uploads

- Each photo is saved as a file under the app's documents directory and recorded in `uploads.db`
  (sqflite) before the batch count goes up. Files stay on the phone after upload.
- Submitting a batch marks it queued and enqueues a unique WorkManager job (`upload-queue`) with a
  network constraint and exponential backoff from 30 s. A 15-minute periodic job is a backstop.
- The sync engine claims one photo at a time (claims expire after 2 minutes, so a killed run never
  leaves a photo stuck in "uploading"), calls the API, and records the result. Every attempt counts;
  after 5 the photo is **failed** and waits for a manual **Retry**, which resets its attempts.
  A permanent rejection fails the photo at once, and a photo whose file has disappeared is failed
  with "Local file missing" and can be removed.
- The upload API does not exist, so it is a mock (`MockUploadApi`) with repeatable scenarios:
  success, fail once, timeout (30 s), no network, and permanent failure. Choose one from the
  **MOCK API** sheet behind the camera's settings icon; the choice persists and applies to
  background runs. Everything else (GPS, camera, storage, WorkManager) is real.

## Generative AI usage

The app was built with **Claude Code** (Claude Opus 5.5) for requirements analysis, planning,
project rules, and implementation, and **Claude Design** for the UI design. The developer set the
rules, approved every plan and decision, and reviewed the work; tests were written first, and each
task was run on Android (the Galaxy A04s, or an emulator with test locations for task 03). The final
release build was then exercised end to end on the phone. The full record, with each session's
prompts, decisions, and evidence, is in [`docs/agent-log.md`](docs/agent-log.md). A selection of the
essential prompts, quoted as typed:

**Requirements review and task breakdown**

> Check out @Task_ Senior App Developer Technical Assessment.pdf and The @AGENTS.md . Anything
> needed to added or changed? Should there be more relevant references? What about spliting the
> work into separate tasks md file?

> One combined apk. so compose and flutter in the same project.
> And write the doc/tasks.

**UI design** (Claude Code wrote the Claude Design prompt; it is in the log)

> I want to create a claude design for this so give me a prompt. i will also upload the pdf with
> the prompt to claude design.

**Guard rails and Git workflow**

> Before we start shall we add pre hooks and post hooks?

> Are the git rules defined? like will this project follow git flow?

> Do not one shot a task. before commiting i want check the git difference. small task scope and
> commit is better. […]

**AI disclosure**

> before starting are you keeping an agent log? the requirement states that readme should include
> […] We can have the essential prompts in the readme then reference the agent log.


**Running tasks.** Each task started from a short handoff file and an approved plan:

> run @FRESH_PROMPT.md

`FRESH_PROMPT.md` (kept local) is the handoff the agent writes at the end of each task, so the next
session starts with a clean context. Early on it was a full briefing; later it shrank to a few
lines pointing at the backlog, the plan, and the log. The first one, for task 01 (the machine path
replaced with `<project root>`):

<details>
<summary>FRESH_PROMPT.md for task 01 (2026-10-12)</summary>

```markdown
# Fresh prompt: Task 01, app shell and native attendance entry

You are working on **Snapendance**, the Intelligent Machines senior app developer assessment:
one combined Android APK where a Flutter app hosts a native Kotlin/Jetpack Compose attendance
screen (Task 1 of the brief) and Flutter provides the camera and resilient batch uploads (Task 2).
Android is the only target; iOS is out of scope. Project root:
`<project root>`.

**Assigned task:** Task 01 in `docs/tasks/01-app-shell-native-bridge.md`, assigned by the user on
2026-10-12. Implement only this task. Do not scaffold later tasks or add their dependencies.

## Current state

- Flutter counter starter, untouched. Android package/application ID `com.shafayatb.snapendance`;
  `MainActivity` (Kotlin, `FlutterActivity`) at `android/app/src/main/kotlin/com/shafayatb/snapendance/`.
- Toolchain at last check: Flutter 3.44.6, Dart 3.12.2, AGP 9.0.1 (built-in Kotlin), Kotlin
  Gradle plugin 2.3.20, Gradle 9.1.0. Re-check before choosing dependency versions.
- Compose is **not** enabled yet. A debug APK built successfully after the package rename.
- No Git repository existed at last check. Claude Code hooks in `.claude/settings.json` block
  agent Git writes, block edits to protected files, and format + analyze edited Dart files.
- `docs/design/` is local-only (gitignored); it holds the UI design and exported frames.

## Read first, in this order

1. `AGENTS.md` (rules; source-of-truth order; small steps with commit checkpoints).
2. `docs/tasks/README.md`, then `docs/tasks/01-app-shell-native-bridge.md` (scope, acceptance).
3. `docs/design/README.md` (adopted choices and deviations), frames
   `docs/design/screens/H1-first-run.png` and `A1-office-not-set.png` (top bar only for this task),
   and `docs/design/screens/design-system.png`. Exact token values are in
   `docs/design/Design System.dc.html` (script `renderVals()`).
4. `docs/agent-reference/product.md` (App shell section), `implementation.md` (Compose under
   AGP 9, native boundary), `verification.md`, `git.md`, `delivery.md`.
5. The current code: `pubspec.yaml`, `lib/main.dart`, `test/widget_test.dart`,
   `android/app/build.gradle.kts`, `android/settings.gradle.kts`, the manifest, `MainActivity.kt`.

## Task 01 scope (summary; the task file is authoritative)

- Replace the counter starter: `lib/app/` composition, app title and launcher label
  "Snapendance", Home screen matching design `H1` with an **Attendance** entry and a static
  subtitle (no live attendance summary). No placeholder entries for later features.
- Light design tokens (colors, type, spacing, radius, status colors) in Flutter (`ThemeData` +
  `ThemeExtension`) and Compose (`MaterialTheme` + status colors).
- Enable Compose for AGP 9 / Kotlin 2.3.20; add `AttendanceActivity` (`ComponentActivity` +
  `setContent`) with an `AttendanceScreen` showing only the "Attendance" top bar with back arrow.
- A minimal `MethodChannel` call (e.g. `openAttendance`) from Flutter through a small Dart class
  injected into the Home screen; back arrow and system Back return to Flutter.

**Acceptance criteria:**

- Launch shows the Snapendance Home (design `H1`), not the counter.
- Tapping Attendance opens the native Compose `AttendanceScreen`.
- Back arrow and system Back return to the same Flutter Home; repeated round trips work without a
  crash or duplicate Activities.
- A failed channel call shows user feedback instead of crashing.
- Debug APK builds; `flutter analyze` is clean.

**Decisions to settle in the plan:** channel and method names and error mapping; fonts (bundle
IBM Plex Sans/Mono, no runtime download) and icons (Material Symbols Rounded font vs. Material
Icons Rounded equivalents); keeping Dart and Kotlin tokens consistent; Activity launch mode so
Back returns to Flutter predictably. Ask the user about anything consequential.

## How to work

1. **Git first (read-only).** Check whether a repository exists and which branch is current. If
   there is no repository, or the branch is not `feature/01-app-shell-native-bridge` created from
   `develop`, tell the user the exact commands from `docs/agent-reference/git.md` and wait. Never
   run Git write commands yourself.
2. **Plan before code.** Write `docs/plans/2026-10-12-01-app-shell-native-bridge.md`: decisions,
   files, test strategy, and **ordered commit-sized steps**, each with a Conventional Commit
   message. A reasonable starting split, to refine: Flutter Home replacing the counter; Flutter
   theme tokens and fonts; Compose enablement and an empty `AttendanceActivity`; Compose theme and
   top bar; method channel with the injected Dart boundary and its widget test; failure feedback.
   Show the plan and get approval before any production change.
3. **One step at a time.** For each step: write the meaningful failing test first and observe the
   failure (where the step has observable behavior), make the minimum change, run the focused
   checks, then **stop at the commit checkpoint**: list changed files, what to look for in the
   diff, checks run, and the suggested commit message. Wait for the user to commit before the next
   step. Never build the whole task and split it afterwards.
4. **Verify.** `dart format`/`flutter analyze`, focused `flutter test`, `flutter build apk --debug`
   (prefix shell commands with `rtk`). Install on an Android device or emulator (ask the user
   which) and run the round trip, rotation on the native screen, and background/return. Record
   device and Android version. Report anything unverified honestly.
5. **Finish.** Append the task entry to `docs/agent-log.md` (actual prompts, decisions, evidence),
   update the task status in `docs/tasks/README.md`, write the review handoff in
   `/tmp/snapendance-agent-review/` per `delivery.md`, replace this `FRESH_PROMPT.md` with the
   prompt for the next assigned task (or one that awaits assignment), give the completion report
   including the merge step for the user, and end with **STOPPED — ready for a fresh context.**

Leave all changes unstaged and uncommitted. Do not add co-author or generated-by trailers.
```

</details>

**Steering the implementation**

> Short form date works. No need to add verbiage. like Tue would work. And use date format rather
> than making your own weekdays and months

> Test on the connected device first

> one thing i think should be improved. after clicking upload, the screen should go the
> @upload_manager_page.dart.

How the work was organized: [`AGENTS.md`](AGENTS.md) holds the agent rules, `docs/tasks/` the
backlog, and `docs/plans/` one approved plan per task. Claude Code hooks in `.claude/` block edits to
protected files and run `dart format` and `dart analyze` after Dart edits. A separate read-only
review agent checked tasks 01, 02, and the failure-handling fix; to meet the deadline, tasks 03-10
were merged without one, and a final review covered the submission.

## How to run

### Requirements

- Flutter 3.44.6 (stable) with Dart 3.12.2
- JDK 17 and the Android SDK with platform 37 (compile SDK); minimum Android 7.0 (API 24)
- A physical Android phone is recommended: the camera and GPS need real hardware

### Build and run

```bash
git clone <repository-url> snapendance
cd snapendance
flutter pub get
flutter run                       # debug build on a connected phone
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
```

Release builds are signed with the key in `android/key.properties` when that file exists (it is
gitignored). Without it, a clone's release build is signed with the local debug key, so the command
above works as is. To sign with your own key, create `android/key.properties`:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

A relative `storeFile` is resolved from `android/app/`.

### Tests

```bash
flutter analyze
flutter test                                       # Flutter unit and widget tests
cd android && ./gradlew :app:testDebugUnitTest     # native attendance unit tests
```

`android/gradlew` is generated by the first `flutter run` or `flutter build`, so run one of those
before the Gradle command in a fresh clone.

### Permissions

- **Location (precise)** for attendance. Approximate-only location is refused with an explanation.
- **Camera** for capture.
- **Notifications** are not requested; uploads run in the background without them.

### Using the app

1. **Attendance:** tap **Set Office Location** at the office, then **Mark Attendance** when the
   ring shows you within 50 m.
2. **Camera & Uploads:** capture photos, tap **UPLOAD BATCH** to queue the batch, and watch it in
   the Upload Manager (cloud icon). Start another batch at any time.
3. **Offline test:** turn on airplane mode, submit a batch, then turn the network back on. The
   queued photos upload without opening the app.
4. **Failure test:** pick a scenario in the MOCK API sheet (settings icon) and submit a batch.
   The scenario stays until you switch back to **Success**.

## Background uploads: what to expect

- Uploads run in a WorkManager job that needs a network connection. Android decides when it runs:
  usually within seconds of the network returning, but Doze, battery saver, and app standby can
  delay it, and after a failure the next try waits for exponential backoff (30 s, then longer). The
  15-minute periodic job is a backup.
- Force-stopping the app (Settings → Force stop) cancels its scheduled work until the app is opened
  again; that is Android's rule for stopped apps. Swiping the app away from Recents should not cancel
  it on stock Android, though some vendors' battery managers do.
- The connectivity shown in the Upload Manager is a hint from the OS, not proof of Internet access.

## Known limitations

- The upload API is a mock; there is no backend.
- Only the first back camera is used. Phones that expose ultra-wide or telephoto as separate
  cameras reach them only through the zoom range the first camera reports.
- The attendance screen notices location services being switched off at its 30 s stale check, not
  instantly. It is portrait-only, because a configuration change would cancel a running GPS fetch.
- If a zoom, flash, or focus call fails in the hardware, the UI still shows the new value.
- A camera permission left as "don't ask again" from an earlier install can show as plain "denied",
  where **Allow camera access** does nothing; grant it in system settings.
- "Marked today" refreshes when the attendance screen resumes, not at midnight while it stays open.
- The camera plugin merges `RECORD_AUDIO` and `WRITE_EXTERNAL_STORAGE` into the manifest although
  still capture needs neither.
- iOS is not supported (`ios/` is unused starter scaffolding).

### Not verified on a device

These are covered by automated tests only, or not at all:

- Swiping the app away from Recents, or the process being recreated, while uploads are running.
- The Timeout and Permanent-failure mock scenarios, and manual **Retry** and **Remove** in the
  Upload Manager.
- The flash firing during capture.
- The start-up error screen (database cannot open) and the storage-error messages.
- The attendance 10 s no-fix message, and large font scales.

Tested on a Samsung Galaxy A04s (Android 14) with the signed release APK: location permission
denied and granted, office saved, weak GPS blocking a mark, a mark at 29 m, location services off,
out of range at 67 m, camera permission denied and granted, pinch, slider, presets, tap focus,
flash modes, several batches, offline queueing with automatic upload in the foreground and in the
background, and the Fail-once scenario retrying after backoff.
