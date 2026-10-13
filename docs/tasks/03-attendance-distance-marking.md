# Task 03: Attendance - live distance and marking

**Depends on:** 02 · **Track:** native Android

## Goal

Show a real-time distance to the saved office and allow **Mark Attendance** only within 50 meters,
revalidating on the action itself.

## In scope

- Foreground location updates while the screen is at least STARTED; stop them otherwise.
- Distance from unrounded coordinates (for example `Location.distanceBetween`) and a pure,
  injectable eligibility policy: office saved, fix ≤ 30 s old and ≤ 25 m accuracy, precise
  permission, and distance ≤ 50 m. Strict boundary: no hysteresis band.
- UI from design frames `A3-A5`, `A9`: distance ring (176 dp, arc = clamp(50 m ÷ distance, 0, 1),
  red out of range, green in range, dotted amber with "~" for a weak/stale fix), status chip,
  helper text, and the attendance card: dashed with lock when locked, green-bordered and enabled
  when eligible, cross-fading into the "Attendance marked" confirmation. The card's bottom line
  shows the last attendance time ("LAST MARKED: …" / "NO ATTENDANCE MARKED YET") in place of the
  reference's time window. Motion timings from the flow notes.
- Mark Attendance obtains/uses a fresh fix, re-checks eligibility, then saves the attendance time
  locally and shows a confirmation. If the re-check fails, nothing is recorded and the user is told.
- States for no office yet, waiting for first fix, location lost/stale, and permission or services
  changing while on the screen.

## Out of scope

Attendance time windows, attendance history beyond the last record, background check-in, showing
attendance data on the Flutter Home screen.

## Acceptance criteria

- The distance updates as the device moves without leaving the screen.
- Eligibility at 49 m and exactly 50 m is enabled; 51 m is disabled (unrounded values), including
  when moving outward from an enabled state.
- Missing office, stale or inaccurate fix, approximate permission, or services off never enables
  the button.
- Moving out of range after the button became enabled prevents recording on tap.
- A successful mark persists and is shown again after restart.
- Location updates stop when the screen is backgrounded or closed.

## Verification

- Policy unit tests for the boundary cases and each disqualifying condition (injected clock).
- ViewModel tests with a fake location stream: updates change distance/eligibility; tap revalidates;
  success persists; failure records nothing.
- Device: physical walk test (record approximate distances observed); emulator mock-location route
  across the 50 m boundary; background/return confirms updates pause and resume.

## Decisions for the plan

- Update interval and minimum displacement for location requests.
- Whether a second mark on the same day is allowed after the confirmation.
- Display rounding and unit switching (m vs. km) for large distances.

## References

Product reference (Task 1), design frames `A3-A5`, `A9` and the deviations table (A4 hysteresis is
rejected), verification reference (Attendance), implementation reference
(lifecycle, errors). Skills: `android-compose-ui` (animation of the ring), `android-presentation-mvi`,
`android-testing`. Docs: `requestLocationUpdates`, `Location.distanceBetween`,
`repeatOnLifecycle` / `collectAsStateWithLifecycle`.
