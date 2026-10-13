# Plan: Task 01, app shell and native attendance entry

**Task:** [01-app-shell-native-bridge](../tasks/01-app-shell-native-bridge.md) ·
**Branch:** `feature/01-app-shell-native-bridge` (from `develop`) · **Status:** awaiting approval

## Current state (inspected 2026-10-13)

- Flutter counter starter (`lib/main.dart`, `test/widget_test.dart`); `cupertino_icons` unused.
- Flutter 3.44.6, Dart 3.12.2, JDK 17, AGP 9.0.1, Gradle 9.1.0, compileSdk 36, minSdk 24.
- `android/gradle.properties` sets `android.builtInKotlin=false`; the Flutter Gradle plugin applies
  `kotlin-android` (KGP 2.3.20, declared in `settings.gradle.kts`) to `:app` implicitly. The
  implementation reference's "built-in Kotlin" note is out of date and is corrected in step 7.
- `MainActivity` is a plain `FlutterActivity`, `singleTop`. Compose is not enabled. No version
  catalog; dependencies are declared inline.
- No Android device was attached at inspection time.

## Decisions (to approve)

| # | Decision | Proposal |
|---|----------|----------|
| D1 | Channel | `MethodChannel("com.shafayatb.snapendance/navigation")`, one method `openAttendance`, no arguments, returns `null`. Registered in `MainActivity.configureFlutterEngine`. |
| D2 | Error mapping | Kotlin: unknown method → `notImplemented()`; `startActivity` failure → `result.error("ATTENDANCE_UNAVAILABLE", …)`. Dart: `AttendanceLauncher.open()` turns `PlatformException` and `MissingPluginException` into one `AttendanceLaunchException`. Home catches it and shows a SnackBar: "Couldn't open Attendance. Please try again." |
| D3 | Dart boundary | A small concrete class `AttendanceLauncher` wrapping the channel, passed to `HomeScreen` through its constructor (created in `main.dart`). No abstract base class. Widget tests use the real class with a mocked platform channel handler. |
| D4 | No Cubit yet | Home has no state beyond a tap; `flutter_bloc` is not added in this task. |
| D5 | Activity launch | `AttendanceActivity`: `exported="false"`, `launchMode="singleTop"`, same task as `MainActivity`. The back arrow calls `finish()`; system Back finishes by default. Rapid double taps are checked on device; a Dart in-flight guard is added only if duplicates appear. |
| D6 | Fonts | Bundle static IBM Plex Sans 400/600/700 and IBM Plex Mono 500 (OFL, the weights in the type scale) twice: Flutter `assets/fonts/` + `pubspec.yaml`, Android `res/font/`. `OFL.txt` included. No runtime download. About 1 MB extra in the APK; accepted for simplicity over loading Flutter assets from Kotlin. |
| D7 | Icons | Flutter: built-in `Icons.*_rounded` (Material Icons Rounded, no dependency). Compose: Material Symbols Rounded vector drawables added per icon (only `arrow_back` now), not the frozen `material-icons-core`/`-extended` libraries. The two families differ slightly in glyph detail; recorded as a design deviation. |
| D8 | Token consistency | Two hand-written token files with identical token names and values, each pointing to `docs/design/Design System.dc.html`: `lib/app/theme/app_tokens.dart` and `.../attendance/ui/theme/AttendanceTokens.kt`. No code generation. A change to one requires the same change to the other (noted in both files). |
| D9 | Theme scope | Light scheme only (camera dark scheme is added with the camera task). Colors, status colors (`ThemeExtension` / `CompositionLocal` data class), type scale, spacing, radius. |
| D10 | Home copy | Header "Snapendance" + today's date ("Monday, 13 October", English, formatted by a small pure function, no `intl`). Attendance card: `location_on` tile, title "Attendance", static subtitle "Set the office and mark attendance" (grey, no status dot, because H1's "Office not set" is live native state). Only the Attendance card. |
| D11 | Compose setup | Plugin `org.jetbrains.kotlin.plugin.compose` 2.3.20 (matches KGP); `buildFeatures { compose = true }`; Compose BOM `2026.09.00` (ui 1.12.1, material3 1.4.0), `activity-compose` 1.13.0, `ui-tooling-preview` (+ `ui-tooling` debug only). `enableEdgeToEdge` with dark status-bar icons; window background `#EEF2F7` to avoid a white flash. |
| D12 | Native test | One instrumented Compose test (`createAndroidComposeRule<AttendanceActivity>`): tapping the back arrow finishes the Activity. Adds `ui-test-junit4`/`ui-test-manifest` and the AndroidX test runner; tasks 02-03 reuse this setup. |
| D13 | Starter cleanup | Remove `cupertino_icons` and the counter test along with the counter. Launcher label and `MaterialApp.title` become "Snapendance". |

## Files

```text
lib/main.dart                                   runApp(SnapendanceApp(attendanceLauncher: ...))
lib/app/app.dart                                SnapendanceApp (MaterialApp, theme, home)
lib/app/theme/app_tokens.dart                   colors, status colors, spacing, radius
lib/app/theme/app_theme.dart                    ThemeData + StatusColors ThemeExtension, text theme
lib/app/home/home_screen.dart                   H1 home, Attendance card, failure SnackBar
lib/app/home/home_date.dart                     formatHomeDate(DateTime)
lib/app/native/attendance_launcher.dart         MethodChannel boundary + AttendanceLaunchException
assets/fonts/                                   IBM Plex TTFs + OFL.txt
test/app/home/home_date_test.dart
test/app/home/home_screen_test.dart
android/settings.gradle.kts, android/app/build.gradle.kts
android/app/src/main/AndroidManifest.xml         label, AttendanceActivity
android/app/src/main/res/values/styles.xml       AttendanceTheme (window background)
android/app/src/main/res/font/                   IBM Plex TTFs (lowercase names)
android/app/src/main/res/drawable/ic_arrow_back.xml
android/app/src/main/kotlin/com/shafayatb/snapendance/MainActivity.kt
.../snapendance/attendance/AttendanceActivity.kt
.../snapendance/attendance/ui/AttendanceScreen.kt
.../snapendance/attendance/ui/theme/AttendanceTokens.kt, AttendanceTheme.kt
android/app/src/androidTest/kotlin/com/shafayatb/snapendance/attendance/AttendanceActivityTest.kt
```

## Steps (one commit each; stop after each for review)

1. **Home replaces the counter.** Test first: `formatHomeDate(DateTime(2026, 10, 12))` is
   `"Monday, 12 October"`, plus a year-boundary and single-digit-day case (catches wrong weekday
   or month indexing). Then `lib/app/` app + Home (default theme), `main.dart`, launcher label,
   remove the counter, its test, and `cupertino_icons`.
   `feat(app): replace counter starter with Snapendance home`
2. **Flutter theme and fonts.** Tokens, `ThemeData`, `StatusColors` extension, bundled fonts, H1
   styling. Pure styling: no test-first claim (a token-equality test would only copy constants);
   verified by `flutter analyze` and a device screenshot against H1.
   `feat(app): add light design tokens and IBM Plex fonts`
3. **Compose enabled, empty native screen.** Gradle plugin, build features, dependencies,
   `AttendanceActivity` with an empty `AttendanceScreen`, manifest entry. Verified by
   `assembleDebug` and `flutter build apk --debug`.
   `chore(android): enable Jetpack Compose and add AttendanceActivity`
4. **Compose theme and top bar.** Test first (instrumented): tapping "Navigate back" finishes
   `AttendanceActivity` (catches a missing or miswired back action). Then the Compose theme,
   fonts, `arrow_back` vector, and the A1 top bar.
   `feat(attendance): add Compose theme and attendance top bar`
5. **Open attendance over the channel.** Test first (widget, mocked channel handler): tapping the
   Attendance card sends `openAttendance` on `com.shafayatb.snapendance/navigation` (catches a
   wrong channel/method name or an unwired tap). Then `AttendanceLauncher`, Home wiring, and the
   `MainActivity` handler.
   `feat(app): open native attendance through a method channel`
6. **Failure feedback.** Tests first: a `PlatformException` from the handler, and no handler at
   all (`MissingPluginException`), each show the SnackBar and leave Home usable (catches an
   uncaught exception or silent failure). Then the exception mapping and SnackBar.
   `feat(app): show feedback when attendance cannot open`
7. **Verification and records.** Device run (round trip ×5, rapid double tap, rotation on the
   native screen, background/return, H1/A1 screenshots), `docs/agent-log.md`, task status,
   design README deviation (D7), implementation reference fix (built-in Kotlin), review handoff,
   `FRESH_PROMPT.md`.
   `docs(tasks): record task 01 verification`

## Verification commands

`rtk proxy dart format --output=none --set-exit-if-changed lib test`, `rtk proxy flutter analyze`,
`rtk proxy flutter test`, `rtk proxy flutter build apk --debug`; from `android/`:
`rtk proxy ./gradlew :app:assembleDebug`, `rtk proxy ./gradlew :app:connectedDebugAndroidTest`
(needs a device). Device: user's choice of physical phone or emulator.

## Risks

- The Compose compiler plugin must apply alongside the implicitly applied KGP; step 3 proves it.
  If it fails, declare `org.jetbrains.kotlin.android` in `:app` explicitly.
- IBM Plex Sans on Google Fonts is now a variable font; static TTFs come from IBM's own release.
