# Snapendance Verification Reference

## Meaningful test-first development

For each production behavior or confirmed bug fix:

1. Identify the externally observable outcome and a plausible regression.
2. Write a focused test at the broadest practical stable boundary.
3. Run it and capture the actual expected failure before writing the behavior.
4. Implement the smallest change that passes it.
5. Run the focused test, then relevant adjacent tests; refactor only while green.

Prefer real domain objects, in-memory fakes, repository boundaries, Cubit/ViewModel state outcomes,
and rendered user interactions. Inject clocks, dispatchers, hardware, and API boundaries where
nondeterminism would prevent a reliable test. Do not mock the class under test.

These alone are not meaningful regression protection: `expect(true, isTrue)`, object/widget
existence, hard-coded copy/constant equality, mock call counts, or matching implementation branches.
They may supplement a behavioral assertion but cannot establish completion. Do not test generated
code or add tests merely for coverage. An internal refactor preserving behavior should generally
leave tests passing.

Static declaration checks can protect a specific manifest or platform contract, but do not prove
installed-app behavior. Do not manufacture failing configuration/string checks to claim TDD.

Label physical hardware and OS checks as manual verification; they do not substitute for
test-first domain/queue behavior.

For meaningful behavioral changes, show the regression test fails when the behavior is removed or
changed, when practical. Record the actual mutation and restore it before finishing; never claim a
mutation check that did not occur.

## Proportional commands

Prefix every command with RTK. Run these only when their corresponding code changed:

```bash
rtk proxy dart format --output=none --set-exit-if-changed <changed-dart-files>
rtk proxy flutter analyze
rtk proxy flutter test <focused-existing-test-path>
rtk proxy flutter build apk --debug
```

From `android/`, native changes may require:

```bash
rtk proxy ./gradlew :app:testDebugUnitTest
rtk proxy ./gradlew :app:assembleDebug
rtk proxy ./gradlew :app:connectedDebugAndroidTest
```

Confirm applicable Gradle tasks/source sets first; do not assume instrumentation tests already
exist. The placeholder test path above must be replaced with a real test for the assigned task.
Use `flutter test` without a path for cross-cutting changes/final integration. Build a release APK
at the final gate, not just the debug variant.

When Git exists, inspect the task diff and run `rtk git diff --check`. Untracked files need separate
inspection; a clean diff does not inspect them. Do not initialize Git just to run a verification
command. Expand checks only for relevant shared changes, failures, or unresolved concerns.

## Feature evidence

### Attendance

- Accurate fixes at 49, exactly 50, and 51 meters yield the documented eligibility policy.
- Missing office, stale/poor-quality fix, approximate permission, and disabled location services
  never accidentally enable attendance.
- Setup survives process recreation; distance updates when the device moves.
- Eligibility is checked again on the action, including movement after the button became enabled.
- Permission denial, rotation, background/return, and opening/closing the native screen recover.

### Camera and batches

- Test supported rear cameras on a physical Android phone, including actual lens/zoom behavior.
- Pinch/slider/buttons agree and remain within supported zoom bounds.
- Tap focus handles preview crop/orientation and unavailable focus capability.
- Camera permission denial, lens switching, capture failures, background/return, and native-screen
  navigation do not leak or lock the camera.
- Multiple batch files and metadata survive restart. A storage failure cannot pretend capture
  succeeded. Check empty batches, repeated actions, and missing image files.

### Sync

- Queue images offline, background the app, restore connectivity, and observe automatic processing
  without another upload tap, allowing for documented Android scheduling delays.
- A reproducible transient mock failure/time-out retains images and later succeeds.
- Partial batch success retries only unfinished items; a permanent failure is explicit.
- Overlapping triggers do not double-process items. New batches added during sync are not stranded.
- Interrupted work and abandoned processing claims recover from durable state.
- Pending Uploads refreshes after background changes and reports accurate per-item/batch outcomes.

Mock evidence establishes simulated upload outcomes and real scheduling/persistence, not real
server delivery or throughput. Test process recreation separately from force-stop; force-stop
restrictions must not be presented as an ordinary scheduler failure.

## Device record and completion claims

For each implementation task record the build, device/emulator and Android version, starting
conditions, actions, expected/actual outcomes, relevant logs/screenshots, and limitations. Use a
physical phone for camera lens/focus and actual GPS checks; an emulator can cover navigation,
permissions, and deterministic location scenarios.

Check readable content, text scaling, touch targets, semantics, layout, navigation, and error
recovery. Visual comparison/goldens supplement interaction and accessibility checks.

Run the installed changed journey after each implementation task. Before submission, exercise
the whole combined journey and offline-to-online recovery using the final release build.

If verification cannot run, name the exact unverified criterion and reason. Do not describe it as
passed or fully complete. Report commands actually run, relevant broader suites skipped, and why.
Never claim evidence from deleted tests, imaginary device runs, or another task's old results.
