# Task 02: Attendance - set office location

**Depends on:** 01 · **Track:** native Android

## Goal

Implement the reference's "Step 1: Office Context" card: **Set Office Location** obtains a fresh,
accurate GPS fix and saves it locally, and the saved office survives app restarts.

## In scope

- Manifest location permissions (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) and runtime
  requests from Compose. No background location permission.
- A location source behind an interface (so the ViewModel is testable with a fake) that requests a
  single high-accuracy current fix.
- An office-location store using DataStore (planned) holding latitude, longitude, accuracy, and the
  saved time.
- `AttendanceViewModel` exposing immutable `StateFlow` UI state; the screen collects it with
  lifecycle awareness and sends actions.
- Step 1 card UI from design frames `A1`, `A2`, `P2`: heading "STEP 1: OFFICE CONTEXT" with status
  dot, the coordinates panel ("Lat / Lon" pill, SAVED time, FIX ACCURACY), helper text, and **Set
  Office Location** (filled until an office is saved, outlined afterwards). Empty "No office
  location saved" panel when nothing is saved; "Getting GPS fix…" panel while fetching. No map.
- Failure states (design `A6-A8`): permission denied / permanently denied (open app settings),
  approximate-only (re-request precise), location services off (system turn-on dialog), no fix
  within 15 s (snackbar with Retry), fix too inaccurate or stale, storage error. Permission and
  services are re-checked on resume.

## Out of scope

Live distance, eligibility, Mark Attendance (task 03). Geofencing APIs, background tracking.

## Acceptance criteria

- With precise permission and services on, tapping Set Office Location saves a fix at most 30 s
  old with accuracy at most 25 m, and the card shows its coordinates, save time, and accuracy.
- A fix failing the policy is not saved; the user sees why and can retry.
- Each failure state above shows specific feedback and a recovery action; none saves an office.
- Granting permission or turning on location in system settings recovers on return, without an
  app restart.
- The saved office is shown after process death and app restart.
- Tapping the button while a fix is in flight does not start overlapping requests.

## Verification

- ViewModel tests with fake location source/store: success saves and shows coordinates; each
  failure maps to its state; stale/inaccurate fixes are rejected; duplicate taps are ignored.
- Store test: a saved office reads back after a new store instance.
- Device: real phone for an actual GPS fix; emulator for permission denial, services off, and mock
  locations. Verify rotation and process recreation.

## Decisions for the plan

- Fused location provider (Play services) vs. platform `LocationManager`, and whether to use the
  location-settings resolution dialog for services off.
- Whether re-setting an existing office needs confirmation.

## References

Product reference (Task 1), design frames `A1`, `A2`, `A6-A8`, `P2` and flow notes,
implementation reference, verification reference (Attendance).
Skills: `android-presentation-mvi`, `android-compose-ui`, `android-error-handling`,
`android-testing`. Do not apply `android-di-koin` or Room from `android-data-layer`.
Docs: Fused Location Provider `getCurrentLocation`; runtime permissions and approximate location;
DataStore; `collectAsStateWithLifecycle`.
