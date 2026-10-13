# Plan: Task 03, attendance live distance and marking

**Task:** [03-attendance-distance-marking](../tasks/03-attendance-distance-marking.md) ·
**Branch:** `feature/03-attendance-distance-marking` (from `develop` at `e213268`) ·
**Status:** approved 2026-10-14 (D6: one mark per calendar day); done 2026-10-14 in triaged mode
(D8 dropped, steps 4-5 and 6-7 merged, no task review)

## Current state (inspected 2026-10-14)

- Task 02 built `AttendanceViewModel` (office setup, permission, services blockers),
  `FusedLocationSource.fixes()` (high accuracy, 1 s updates, removed when collection ends),
  `LocationFixPolicy` (≤ 25 m, ≤ 30 s), `DataStoreOfficeStore`, and the office card. The area
  below the card shows only the A6-A8 blocker panel; there is no ring and no attendance card.
- The screen sends `ScreenResumed(permission)` on `ON_RESUME` and `ScreenStopped` on `ON_STOP`.
  The Activity is portrait-only (task 02 step 8).
- JVM tests use JUnit 4, `kotlinx-coroutines-test`, `FakeLocationSource` (counts open requests)
  and `FakeOfficeStore`. `android.location.Location` is not usable in JVM tests (stub jar).
- Services turned off from the quick-settings shade do not pause the screen, so today the screen
  only notices on the next resume or attempt.

## Decisions (to approve)

| # | Decision | Proposal |
|---|----------|----------|
| D1 | Update interval and displacement | Reuse `fixes()`: high accuracy, 1 s interval, **no minimum displacement**. A displacement filter would stop updates for a phone lying still, and its last fix would turn stale after 30 s and lock the button. Cost is bounded: updates run only while the screen is visible. |
| D2 | When tracking runs | While the screen is resumed-then-not-stopped (from `ScreenResumed`, which already re-checks permission and services, until `ScreenStopped`), an office is saved, precise permission is held, services are on, and no Set Office attempt is running. **One location request at a time**: tracking pauses during a Set Office attempt (the ring shows "Locating", as in A2) and restarts after it, against the new office. Stopping clears the last fix, so a return starts from "Locating", never from an old distance. |
| D3 | Eligibility policy | Pure `AttendanceEligibility.evaluate(office, fix, permission, servicesOn, now)` returning `NoOffice`, `Blocked`, `WaitingForFix`, `WeakFix(distance, verdict)`, `OutOfRange(distance)`, `InRange(distance)`. Uses `LocationFixPolicy` for the fix, then distance ≤ 50.0 m on the unrounded value. The distance function is injected: `Location.distanceBetween` in the app, a flat fake in tests. |
| D4 | Stale while on the screen | Re-evaluated when a fix arrives and once more when the latest fix turns 30 s old (one timer, reset by each fix; no polling loop). A screen whose GPS stops reporting turns to the A9 weak state and locks. |
| D5 | Mark Attendance | Tap → card shows a progress state → wait up to **10 s** for the first fix taken **after the tap** that the fix policy accepts (from the running tracking request; no second request) → re-check ≤ 50 m → save `{markedAt, distanceMeters}` → confirmation. Failures save nothing and show a snackbar: out of range ("You're 63 m from the office. Move within 50 m to mark attendance. Nothing was recorded."), no usable fix in 10 s (with Retry), storage error (with Retry). Leaving the screen mid-check cancels it silently. |
| D6 | Second mark the same day | **One mark per calendar day** (device time zone). Once marked today, the card shows the A5 confirmation for the rest of the day, also after a restart; the ring keeps tracking. The next day the card returns with "LAST MARKED: YESTERDAY 09:04 AM". Alternative: allow re-marking, which overwrites the last record. |
| D7 | Display rounding and units | Below 1 km: whole meters **rounded up** ("50m" only when the distance is ≤ 50.0, so the number never reads in range while the button is locked). 1-100 km: one decimal ("1.2km"); above that, whole km. Weak fix: "~" prefix and "±65 m ACCURACY" (or "ACCURACY UNKNOWN"). Ring arc uses the unrounded distance. |
| D8 | Services and permission changing on screen | `LocationSource.locationEnabledChanges()`: a `Flow<Boolean>` from a broadcast receiver for `PROVIDERS_CHANGED_ACTION`, collected while the screen is started. Off → A8 blocker, tracking stops; on → blocker clears, tracking resumes. Permission cannot change while the screen is visible: revoking it in settings kills the process, and granting it means leaving the screen, so `ScreenResumed` covers both. |
| D9 | Storage | A second Preferences DataStore file, `attendance_record`, with `marked_at_epoch_millis` (long) and `distance_meters` (float); `AttendanceStore` interface + `DataStoreAttendanceStore`, mirroring the office store (corruption handler, read errors show "No attendance marked yet" with a message). Replacing the office keeps the last record. |
| D10 | Ring, chip, helper | From the design source: `NoOffice` (A1), `Locating` (A2: indeterminate arc 1.2 s loop, "GETTING GPS FIX"), `OutOfRange` (A3), `InRange` (A4), `Weak` (A9: dotted amber; helper "No fresh, accurate GPS fix. Check-in unlocks once one arrives. Try moving near a window."; no "2 min ago" age, which would need a ticking clock), `Unavailable` (provider could not start: "—", "LOCATION UNAVAILABLE", "Leave and reopen this screen to try again."). Marked today: chip "MARKED 09:12 AM" and helper "Distance keeps updating while this screen is open." (A5). Blockers keep replacing the ring (task 02 D7). Motion: number and arc 300 ms ease-out, colors 250 ms, card cross-fade 250 ms. |

## Files

```text
.../attendance/location/LocationSource.kt          + locationEnabledChanges()
.../attendance/location/FusedLocationSource.kt     broadcast receiver flow
.../attendance/location/DistanceCalculator.kt      fun interface; Location.distanceBetween impl
.../attendance/marking/AttendanceEligibility.kt    pure policy (D3)
.../attendance/marking/AttendanceRecord.kt
.../attendance/marking/AttendanceStore.kt          interface + DataStoreAttendanceStore
.../attendance/ui/AttendanceUiState.kt             distance status, card state, mark events
.../attendance/ui/AttendanceViewModel.kt           tracking, stale timer, marking
.../attendance/ui/DistanceRing.kt                  ring, chip, helper (A1-A4, A9)
.../attendance/ui/AttendanceCard.kt                locked / ready / checking / marked (A3-A5)
.../attendance/ui/DistanceFormat.kt                D7 formatting (pure, tested)
.../attendance/ui/AttendanceScreen.kt              wiring, snackbars with per-event retry
.../attendance/AttendanceActivity.kt               factory: attendance store, distance, time zone
res/drawable/ic_*.xml                              lock, where_to_vote, how_to_reg, task_alt
res/values/strings.xml                             ring, chip, card, and mark copy
src/test/.../attendance/                           AttendanceEligibilityTest,
                                                   DataStoreAttendanceStoreTest,
                                                   DistanceFormatTest, ViewModel tests, fakes
```

## Steps (one commit each; stop after each for review)

1. **Eligibility policy.** Test first (JVM): 49 m and exactly 50.0 m in range, 50.01 m and 51 m
   out; no office, no fix, approximate permission, services off, stale (30.001 s), inaccurate
   (25.1 m), and missing accuracy each never in range, even at 0 m (catches `<` vs `≤`, a rounded
   distance, or a skipped condition). `DistanceCalculator` with the framework implementation.
   `feat(attendance): add the attendance eligibility policy`
2. **Attendance store.** Test first against a real DataStore file: a record reads back from a new
   instance, an empty file reads as none, a corrupt file reads as none and can be written over.
   `feat(attendance): persist the last attendance record with DataStore`
3. **Services changes.** `locationEnabledChanges()` in `LocationSource` and the fused source
   (receiver unregistered when collection ends); fake updated. Thin platform wrapper, no test of
   its own; covered by step 4's ViewModel tests through the fake and on device.
   `feat(attendance): report location setting changes`
4. **ViewModel: live distance.** Tests first with the fake source, a flat distance, and a clock
   on the test scheduler: tracking starts on resume with an office and precise permission; each
   fix updates distance and status; 49 → 51 m locks again; no fix for 30 s turns weak; stop
   removes the request and resume restarts it from "Locating"; no tracking without an office or
   under a blocker; a Set Office attempt leaves one request open and tracking resumes after it;
   services off on screen shows A8 and stops tracking, back on resumes; provider failure shows
   unavailable. Updates the task 02 test that expected no request after a save.
   `feat(attendance): track the live distance to the office`
5. **ViewModel: marking.** Tests first: a tap waits for a fix taken after the tap and records
   time and distance when in range; a fix at 51 m after an in-range tap records nothing and
   reports the distance; no usable fix in 10 s records nothing; storage failure reports it; a
   second tap while checking starts no second check; tapping while locked does nothing; a record
   from today shows as marked after restart, one from yesterday does not; stopping mid-check
   records nothing.
   `feat(attendance): mark attendance after re-checking the distance`
6. **Distance ring.** `DistanceFormat` tests first (50.0 → "50m", 50.01 → "51m", 999.2 → "1.0km"
   rather than "1000m", 12 345 → "12.3km", 150 000 → "150km"), then the ring, chip, and helper
   (A1-A4, A9, unavailable) with animations; previews. Verified by build and device screenshots.
   `feat(attendance): show the live distance ring`
7. **Attendance card.** Locked, ready, checking, and marked cards with the last-marked line and
   cross-fade; snackbars for mark events with per-event Retry. Verified on device.
   `feat(attendance): add the Mark Attendance card`
8. **Verification and records.** Device run (below), task file criteria wording if a decision
   changes one, design deviations (A9 helper without age, A5 chip, unavailable state), backlog
   status, review agent, `docs/agent-log.md`, `FRESH_PROMPT.md`.
   `docs(tasks): record task 03 verification`

### As built (2026-10-14)

After step 1 the user set a 20:00 deadline for the whole project and switched to triaged mode.
D8's broadcast receiver was dropped: the 30 s stale check re-reads the location setting, so
location turned off from the shade shows A8 within about 30 s (deferred improvement). Steps 4-5
were one commit (`feat(attendance): track the live distance and mark attendance after a re-check`)
and steps 6-7 another (`feat(attendance): show the live distance ring and the Mark Attendance
card`). The emulator run used test providers instead of a recorded route; the phone walk test
was not run.

## Verification

Commands from `android/`: `rtk proxy ./gradlew :app:testDebugUnitTest`, `:app:lintDebug`,
`:app:assembleDebug`, `:app:connectedDebugAndroidTest` (existing back-arrow test), and
`rtk proxy flutter build apk --debug` at the end; `rtk git diff --check`.

Device:

- Emulator (Android 16, test providers): a mock route from 80 m to 30 m and back across 50 m
  (lock, unlock, lock at 51 m); mark in range; move to 60 m right after the button enables and
  tap (nothing recorded); stop sending fixes for 30 s (weak); Home and return (location log shows
  the request removed and re-added); services off from the shade (A8) and back on; force-stop and
  reopen shows the mark.
- Phone (Galaxy A04s, real GPS): walk away from the saved office and back, recording the
  approximate distances shown at a few points (no coordinates in the log); mark attendance in
  range; reopen after a restart.

## Risks

- Indoors the phone's best fix was ±27 m in task 02, so the screen may sit in the weak state at a
  desk. The thresholds stay as approved; the walk test runs near a window or outdoors.
- `PROVIDERS_CHANGED_ACTION` may arrive more than once per toggle; the flow is de-duplicated.
- Today is the confirmed submission deadline (2026-10-14) and tasks 04-11 have not started.
