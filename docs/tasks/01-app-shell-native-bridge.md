# Task 01: App shell and native attendance entry

**Depends on:** - · **Track:** shared

## Goal

Replace the Flutter counter starter with the Snapendance app shell and prove the combined-APK
boundary: a Flutter home screen opens a native Jetpack Compose attendance Activity and Back returns
to Flutter.

## In scope

- Flutter: `lib/app/` composition (app widget, theme, home screen). App title and Android launcher
  label "Snapendance". Remove the counter demo and its starter widget test.
- Home screen (design `H1`) with an **Attendance** entry and a static subtitle; no live
  attendance summary (attendance data stays native). Task 04 adds the **Camera & Uploads** entry;
  do not add placeholder entries or routes for unbuilt features.
- Light theme tokens from `docs/design/` (colors, type scale, spacing, radius, status colors) in
  both Flutter (`ThemeData` + `ThemeExtension`) and Compose (`MaterialTheme` + status colors),
  with the fonts and icons approach approved in the plan.
- Android host: enable Compose for AGP 9 / Kotlin 2.3.20 (see the implementation reference),
  add an `AttendanceActivity` (`ComponentActivity` + `setContent`) registered in the manifest.
- `AttendanceScreen` composable showing only the top app bar from design `A1` ("Attendance" with
  a back arrow) and an empty body. The back arrow and system Back finish the Activity.
- A minimal `MethodChannel` operation (for example `openAttendance`) from `MainActivity`, called
  from Flutter through a small Dart class the home screen receives via its constructor.

## Out of scope

Location, permissions, persistence, camera, `flutter_bloc` (unless the plan needs it now), any
data returned from native to Flutter.

## Acceptance criteria

- Launching the app shows the Snapendance home screen matching design `H1`, not the counter.
- Tapping Attendance opens the native Compose `AttendanceScreen`.
- Back arrow and system Back return to the same Flutter home state; repeating the round trip
  several times works without a crash or duplicate Activities.
- A failed channel call (for example, a missing handler) shows user feedback instead of crashing.
- Debug APK builds; `flutter analyze` is clean.

## Verification

- Widget test: tapping Attendance calls the injected native-navigation boundary; a failing
  boundary shows the error feedback. (Fake boundary, real widget.)
- Device: install the debug APK, run the round trip, rotate on the native screen, and background/
  return. Record the device and Android version.

## Decisions for the plan

- Channel name, method names, and error mapping.
- Fonts and icons: bundle IBM Plex Sans/Mono (OFL) as assets in Flutter and `res/font` in Compose
  (no runtime download); Material Symbols Rounded font vs. Material Icons Rounded equivalents.
- How shared design tokens are kept consistent between the Dart and Kotlin themes.
- Activity launch mode / task behavior so Back returns to Flutter predictably.

## References

`AGENTS.md`; design README and frames `H1`, `A1`, `screens/design-system.png`; implementation
reference (native boundary, Compose enablement); verification reference.
Skills: `android-compose-ui` (Compose patterns only; ignore its KMP/design-system module advice).
Docs: Flutter platform channels; Compose `ComponentActivity.setContent`; AGP 9 Compose compiler setup.
