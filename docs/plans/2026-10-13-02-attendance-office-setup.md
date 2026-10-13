# Plan: Task 02, attendance office setup

**Task:** [02-attendance-office-setup](../tasks/02-attendance-office-setup.md) ·
**Branch:** `feature/02-attendance-office-setup` (from `develop`, plus `5a9dfe7` docs) ·
**Status:** approved 2026-10-13; done 2026-10-13 (steps 8-9 added from the device run, 10-11
from the task review)

## Current state (inspected 2026-10-13)

- `AttendanceActivity` hosts `AttendanceScreen`: top bar and an empty body. No ViewModel, no
  location code, no manifest location permissions. No `configChanges`, so rotation recreates the
  Activity (a ViewModel survives it).
- Dependencies: Compose BOM `2026.06.01`, `activity-compose` 1.13.0, Material 3. Instrumented test
  setup exists (`AttendanceActivityTest`); there is no JVM unit test setup (`src/test`) yet.
- minSdk 24, so `java.time` is unavailable without desugaring; times use epoch millis and
  `SystemClock.elapsedRealtime`.
- Latest stable: `play-services-location` 21.4.0, `datastore-preferences` 1.2.1, lifecycle 2.11.0,
  `kotlinx-coroutines-test` 1.11.0. Each is checked against AGP 9.0.1 / compileSdk 36 with
  `checkDebugAarMetadata` when added; an older line is used if one needs compileSdk 37.

## Decisions (to approve)

| # | Decision | Proposal |
|---|----------|----------|
| D1 | Location provider | Fused Location Provider (`play-services-location`). Better fixes indoors than `LocationManager` and gives the system "turn on location" dialog (`SettingsClient`) that A8 shows. Needs Play services; a device without them gets the "no fix" path. |
| D2 | How a fix is obtained | Not a single `getCurrentLocation` call: `LocationSource.fixes()` is a `callbackFlow` of high-accuracy updates (1 s interval), and the ViewModel takes the **first fix the policy accepts within 15 s**. A first fix that is cached or coarse no longer fails the attempt, A2's "accuracy ±18 m · improving" line shows real values, and task 03 reuses the same flow for live distance. The task file's "single current fix" wording is updated to match. |
| D3 | Fix policy | Pure `LocationFixPolicy`: accepted when accuracy ≤ 25 m and age ≤ 30 s (both inclusive); a fix without accuracy counts as inaccurate. Age uses the fix's elapsed-realtime timestamp, not wall time. Mock-provider fixes are accepted (emulator verification relies on them); recorded as a limitation. |
| D4 | Failure feedback | One-off events through a `Channel`, shown as snackbars with **Retry**: no fix in 15 s; best fix too inaccurate ("GPS accuracy ±40 m; ±25 m or better is needed"); only stale fixes; storage write error. If services turned off during the attempt, the timeout shows the A8 blocker instead. Nothing is saved on any failure; a previously saved office stays shown. |
| D5 | Permission flow | Ask only when **Set Office Location** is tapped (A1 shows the button enabled before any prompt). Request `FINE` + `COARSE` together (required on Android 12+). Result: precise → fetch; coarse only → A7; denied with rationale available → A6 with "Allow location" (asks again); denied without rationale → A6 with "Open app settings". Permanence is learned from the request result, so it is not persisted; after a restart the next tap re-learns it without showing a dialog. Accepted limitation (task review): dismissing the dialog by tapping outside also reads as "won't ask again" on Android 11+, so A6 offers app settings although the system would still ask; recovery still works. |
| D6 | Who does what | The ViewModel owns state and decisions and knows nothing about Activities. The screen reports permission status (`checkSelfPermission`) on every resume and sends request results; it launches the permission request, app settings, and the location-settings resolution (falling back to `ACTION_LOCATION_SOURCE_SETTINGS`) when the ViewModel asks or a recovery button is tapped. Services on/off comes from `LocationSource.isLocationEnabled()`, checked on resume and before each attempt. |
| D7 | Blockers (A6-A8) | Shown in the area below the card (where task 03's ring goes), and they disable Set Office Location. Services off and approximate-only are shown whenever true on resume; the permission blocker only after a denial (first run shows A1). If an office is saved, the card keeps showing it under a blocker; the "Location unavailable" panel is used only when nothing is saved. |
| D8 | Re-setting the office | Allowed, with a confirmation dialog when an office is already saved: "Replace saved office?" / "Your current GPS position will replace the saved office." / Cancel, Replace. The overwrite is not undoable and the outlined button stays prominent, so one tap should not replace it. Not in the design; recorded as a deviation. |
| D9 | Lifecycle | The fetch runs in `viewModelScope`, so rotation does not restart it. It is cancelled on `ON_STOP` (foreground-only location; background updates are throttled) and the card returns to its previous content silently. Taps while a fetch runs are ignored (and the button is disabled). Amended 2026-10-13: rotation did cancel the fetch (recreation passes `ON_STOP`); the screen is locked to portrait (step 8). |
| D10 | Storage | Preferences DataStore, one file `office_location`, through the official `preferencesDataStore` delegate (one instance per process). Keys: latitude, longitude (double), accuracy (float), saved-at epoch millis (long). A read error surfaces as "Couldn't load the saved office location." and the office shows as not set. |
| D11 | Wiring and tests | No DI library: a `viewModelFactory` in `AttendanceActivity` builds `FusedLocationSource`, `DataStoreOfficeStore`, and the clocks. `OfficeStore` is an interface only because ViewModel tests need a failing fake. JVM unit tests with JUnit 4 and `kotlinx-coroutines-test` (no Turbine/AssertK: state is asserted through `uiState.value`, events by collecting the channel). The store test runs against a real file-backed DataStore in a temp folder. |
| D12 | Saved-time format | "Today, 08:41 AM", "Yesterday, 08:41 AM", or "12 Oct, 08:41 AM", using the device's 12/24-hour setting. Coordinates at 4 decimals (about 11 m) in IBM Plex Mono, accuracy as "±6 m". |

## Files

```text
android/app/build.gradle.kts                      play-services-location, datastore, lifecycle, test deps
android/app/src/main/AndroidManifest.xml          ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION
.../attendance/location/LocationFix.kt            lat, lon, accuracy, elapsed-realtime time
.../attendance/location/LocationFixPolicy.kt      ≤ 25 m, ≤ 30 s verdicts
.../attendance/location/LocationSource.kt         interface: fixes(), isLocationEnabled()
.../attendance/location/FusedLocationSource.kt    Play services implementation
.../attendance/office/SavedOffice.kt
.../attendance/office/OfficeStore.kt              interface + DataStoreOfficeStore
.../attendance/ui/AttendanceUiState.kt            state, actions, events
.../attendance/ui/AttendanceViewModel.kt
.../attendance/ui/AttendanceScreen.kt             root (collect, events, launchers) + screen
.../attendance/ui/OfficeContextCard.kt            Step 1 card (A1, A2, P2)
.../attendance/ui/LocationIssuePanel.kt           A6-A8 blocker
.../attendance/AttendanceActivity.kt              ViewModel factory
res/drawable/ic_*.xml                             Material Symbols Rounded: add_circle,
                                                  add_location_alt, location_on, location_disabled,
                                                  location_searching, location_off, open_in_new,
                                                  arrow_forward
res/values/strings.xml                            attendance copy
android/app/src/test/kotlin/.../attendance/       LocationFixPolicyTest, DataStoreOfficeStoreTest,
                                                  AttendanceViewModelTest, fakes
```

## Steps (one commit each; stop after each for review)

1. **Fix policy.** Test first (JVM): 25 m / 30 s accepted, 25.1 m and 30.001 s rejected with
   their reason, missing accuracy rejected (catches an off-by-one or a swapped threshold, which
   would let a bad office through). Adds the `src/test` setup with JUnit 4.
   `feat(attendance): add the usable GPS fix policy`
2. **Office store.** Test first: a saved office reads back from a new store instance on the same
   file, and an empty file reads as no office (catches lost or mis-keyed fields). DataStore
   dependency, `SavedOffice`, `OfficeStore`, `DataStoreOfficeStore`.
   `feat(attendance): persist the office location with DataStore`
3. **Location source.** Manifest permissions, `play-services-location`, `LocationSource`,
   `FusedLocationSource` (updates removed when the flow closes). A thin platform wrapper with no
   test of its own; verified by the build here and on device in step 7.
   `feat(attendance): add a fused location source`
4. **ViewModel: setting the office.** Tests first with fake source/store and a test clock: an
   accepted fix is saved and shown; stale and inaccurate fixes are skipped while a later good fix
   is saved; nothing usable in 15 s emits the matching message and saves nothing; a store error
   emits the storage message; a second tap while fetching starts no second collection; replacing
   a saved office needs confirmation; `ON_STOP` cancels the attempt.
   `feat(attendance): set the office location in AttendanceViewModel`
5. **ViewModel: permission and services.** Tests first: tap without permission asks for it;
   coarse-only gives the approximate blocker; denied with/without rationale gives the two A6
   variants; services off gives A8 and no fetch; a resume with permission granted and services on
   clears the blocker (catches recovery that needs a restart).
   `feat(attendance): handle location permission and services in AttendanceViewModel`
6. **Step 1 card.** Root/screen split, `collectAsStateWithLifecycle`, events, permission launcher,
   snackbars, replace dialog, A1/A2/P2 card and icons. UI only; behavior is covered by steps 4-5.
   Verified by build and a device screenshot.
   `feat(attendance): add the office context card`
7. **Blockers and recovery.** A6-A8 panel, app settings and location-settings resolution, resume
   re-check wiring. Verified on device.
   `feat(attendance): show location blockers with recovery actions`
8. **Portrait lock** (added from the device run). Rotation recreated the Activity, its `ON_STOP`
   sent `ScreenStopped`, and a running fetch was cancelled, against D9. The user chose to lock
   `AttendanceActivity` to portrait for now and defer the proper fix (backlog "Deferred
   improvements"). Verified on the phone.
   `fix(attendance): lock the attendance screen to portrait`
9. **Wait for the saved office to load** (added from the device run). Before DataStore's first
   read, a null office looked like "none saved": the card showed A1 and a tap could replace the
   saved office without the D8 confirmation. `isOfficeLoaded` disables Set Office Location and
   shows a loading panel until then. Test first (JVM).
   `fix(attendance): wait for the saved office before allowing Set Office Location`
10. **Review fixes: permission and store robustness** (added from the task review). One permission
    request per open dialog (a second one got an empty answer and lost the real one); a save
    after a failed read is shown; a corrupt file is replaced; one fetch per Replace confirm.
    Tests first (JVM).
    `fix(attendance): ask for location once per dialog and recover from unreadable office data`
11. **Review fixes: lint and copy** (added from the task review). Locale read from the
    configuration (`lintDebug` error `NonObservableLocale`); a rejected accuracy is rounded up.
    `fix(attendance): read the locale observably and round rejected accuracy up`
12. **Verification and records.** Device run (below), task file wording (D2), design deviations
    (A6/A7 recovery variants, saved office under a blocker, replace dialog, loading panel),
    backlog status, review agent, `docs/agent-log.md`, `FRESH_PROMPT.md`.
    `docs(tasks): record task 02 verification`

## Verification

Commands from `android/`: `rtk proxy ./gradlew :app:testDebugUnitTest`,
`rtk proxy ./gradlew :app:assembleDebug`, `rtk proxy ./gradlew :app:connectedDebugAndroidTest`
(existing back-arrow test still passes), plus `rtk proxy flutter build apk --debug` once at the end.

Device:

- Real phone: set office indoors and near a window; card shows coordinates, time, accuracy ≤ 25 m;
  force-stop and reopen shows the same office; replace flow with confirmation.
- Emulator (`adb emu geo fix`): deny once (A6 "Allow location"), deny permanently (A6 settings,
  grant there, return recovers), approximate only (A7, upgrade recovers), services off (A8 dialog
  recovers), no fix within 15 s, rotation during fetch, background during fetch, process death via
  "Don't keep activities" / `adb shell am kill`.

As run (2026-10-13): permissions, approximate, and services off on the phone (its system dialogs);
emulator test providers (`cmd location providers`) instead of `adb emu geo fix` for no-fix and
mock fixes; process death with `run-as <package> kill`, since `am kill` left the process running
on Android 16. Rotation is covered by the step 8 lock rather than surviving recreation.

## Risks

- `lifecycle` 2.11 or `datastore` 1.2 may require compileSdk 37; fall back to the newest line that
  passes `checkDebugAarMetadata`, as with the Compose BOM in task 01. As built: lifecycle 2.10.0
  (2.11.0 failed `checkDebugAarMetadata`: compileSdk 37, AGP 9.1), datastore 1.2.1,
  `play-services-location` 21.4.0, `kotlinx-coroutines-test` 1.9.0 (matches the resolved
  coroutines core).
- Emulator mock locations may report no accuracy or a fixed accuracy; the policy treats missing
  accuracy as inaccurate, so the emulator run sets accuracy explicitly or uses the extended
  controls.
- Indoors, a ±25 m fix may take longer than 15 s on some phones; the message says to retry near a
  window. The thresholds stay as approved. Seen on the Galaxy A04s: ±27-44 m at a desk, ±17 m near
  a window.
