# Agent log

A record of how generative AI was used to build Snapendance: the prompts the developer entered,
what the AI produced, what the developer decided, and how the result was checked. The README's
AI-usage section summarizes this log and quotes the prompts marked **Essential**.

Conventions:

- Prompts are quoted from the session transcripts as typed (typos kept). `[…]` marks trimmed
  text; `[another project]` replaces the name of an unrelated project.
- Tools: **Claude Code** (model Claude Opus 5.5) for requirements analysis, planning, rules,
  configuration, and implementation; **Claude Design** for the UI design.
- Only AI work that happened in this repository's Claude Code sessions, or that those sessions
  handed to Claude Design, is recorded. The `AGENTS.md` and `docs/agent-reference/` drafts that
  existed before the first session are not covered here.

## 2026-10-12 · Requirements, design, and project rules (Claude Code)

### Requirements review and task backlog · Essential

> Check out @Task_ Senior App Developer Technical Assessment.pdf and The @AGENTS.md . Anything
> needed to added or changed? Should there be more relevant references? What about spliting the
> work into separate tasks md file? Also rename CLUADE to CLAUDE

- **Claude:** compared the brief with the existing rules and listed the gaps: no defined start
  screen, screenshot controls not classified as required or optional, and no task breakdown.
  Renamed the misspelled symlink to `CLAUDE.md`.

> 1.First the package became com.shafayatb.snapendance.snapendence. change it to
> com.shafayatb.snapendance
> 2. One conbined apk. so compose and flutter in the same project.
> And write the doc/tasks.

- **Decided by the developer:** one combined APK (Flutter app hosting a native Compose
  attendance Activity); package `com.shafayatb.snapendance`.
- **Claude:** renamed the Android namespace, application ID, and `MainActivity` package; recorded
  the combined-APK decision; wrote `docs/tasks/` (index plus 11 task files with scope, acceptance
  criteria, verification, and open decisions).
- **Checked:** a debug APK built after the rename (not installed on a device).

### UI design through Claude Design · Essential

> I want to create a claude design for this so give me a prompt. i will also upload the pdf with
> the prompt to claude design.

- **Claude:** wrote the Claude Design prompt below. The developer pasted it into Claude Design
  with the brief PDF; the resulting design was placed in `docs/design/` (kept local-only).

<details>
<summary>Prompt given to Claude Design (written by Claude Code)</summary>

> Design the mobile UI for **Snapendance**, an Android app built for the attached technical
> assessment (*Senior App Developer Technical Assessment.pdf*). Read the PDF first. Its two
> screenshots are the visual reference, and the text defines what the app must do.
>
> **About the app**
> Snapendance is one Android app with two features:
> 1. **Geo-fenced attendance.** The user saves the office's GPS location, then can mark attendance
>    only when within 50 meters of it. A live distance indicator updates as they move. This
>    screen will be built natively in Jetpack Compose.
> 2. **Camera and upload sync.** A custom camera captures batches of photos. The batches go into
>    a durable upload queue that retries automatically in the background when the connection
>    returns. These screens will be built in Flutter.
>
> Both features must look like one product. Every design must map cleanly onto Material 3
> components in both Compose and Flutter. Avoid effects that need custom rendering engines.
>
> **Target:** Android phone, portrait, 412 × 915 dp frame. Specify sizes in dp/sp. Touch targets
> must be at least 48 dp. Text must meet WCAG AA contrast and still work at 1.3× font scale.
>
> **Screens to design**
>
> 1. **Home.** The app's entry point. It has three entries: Attendance, Camera, and Pending
>    Uploads. Show a small summary on the cards where it helps, such as "Office not set", "3
>    images waiting", or the last attendance time. Keep it simple; this is a launcher, not a
>    dashboard.
> 2. **Attendance** (follow the PDF's first screenshot closely). It has a top bar reading
>    "Attendance" with a back arrow. Below that comes the "STEP 1: OFFICE CONTEXT" card: status
>    dot, location panel with a "Lat / Lon" pill, helper text, and an outlined **Set Office
>    Location** button with an add-circle icon. Next is the circular distance ring ("120m AWAY")
>    with a proximity arc, a status chip, and the helper line "Move within 50 meters…". Last is a
>    dashed attendance card with a lock icon and the **Mark Attendance** button. Design these
>    states: office not set yet; fetching location (loading); out of range (red, button locked);
>    in range (green, button enabled, lock removed); attendance marked (confirmation with the
>    time); location permission denied, with a path to settings; approximate location only
>    (precise location needed); location services turned off; weak or stale GPS signal.
>
>    The screenshot line "AVAILABLE 09:00 AM – 10:30 AM" is decorative, not a rule. Replace it
>    with something truthful, such as "Last marked: today 09:12" or nothing. For the location
>    panel, show two variants: a map tile, and a map-free coordinates panel. The project may not
>    use a map SDK, and the map-free version must not pretend to be a live map.
> 3. **Camera Preview** (follow the PDF's camera screenshot). Dark, full-bleed live preview. The
>    top bar has close (X), flash, and a settings icon. Include: a vertical zoom slider on the
>    right edge; rounded zoom buttons (0.5×, 1×, 2×) with the selected one highlighted; the bottom
>    row: last-capture thumbnail with a count badge, the shutter, and a flip-camera button; a
>    full-width **UPLOAD BATCH (n)** button. Design these states: tap-to-focus ring at the tap
>    point; pinch zoom in progress, with a zoom readout; device without an ultra-wide lens (no
>    0.5× button); flash unsupported; capture in progress; empty batch (upload button disabled);
>    camera permission denied; camera unavailable or error; "Batch queued" confirmation after
>    upload.
>
>    The settings icon opens a small sheet titled **"Upload simulation"**. It picks the mock API
>    outcome: Success, Fail once then succeed, Timeout (slow network), No network, Permanent
>    failure. The sheet must be clearly labeled as a simulation.
> 4. **Upload Manager / Pending Uploads** (follow the PDF's second screenshot). Header "Upload
>    Manager" with a connection pill, in three variants: "Stable link", "Offline", and "Connected
>    – uploads failing". Below it, overall batch progress ("8 of 12 uploaded") with a progress
>    bar, then "PENDING UPLOADS (n)". Each item is an image thumbnail with its name, size, and a
>    status line. Show every status: Queued, Waiting for connection, Uploading (with progress),
>    Retrying (attempt 3/5), Synced, Failed (with reason and a retry action). Include the **START
>    NEW UPLOAD BATCH** button, an empty state ("Nothing waiting to upload"), and a placeholder
>    for a thumbnail whose local file is missing. Show items grouped by batch with a per-batch
>    progress line, plus a flat-list alternative so I can choose.
>
> **Visual direction**
> The attendance reference is light: navy title, blue accents, white cards, a soft blue-grey
> background, red and green status colors. The camera and Upload Manager references are dark.
> Build one design system that supports both, with the camera always dark, and propose whether
> the Upload Manager stays dark or follows the app theme. Provide: color tokens for light and
> dark, including status colors for in range, out of range, pending, uploading, synced, and
> failed; a type scale (one Google Font family or Roboto); spacing, radius, and elevation tokens;
> specs for the reusable components: status chip, distance ring, connection pill, upload item
> row, zoom pill buttons, and primary/secondary/locked buttons.
>
> Use real-sounding sample data. Don't use the reference's placeholder file names
> (RAW_DATA_NODE.dat and so on), because the queue holds only photos.
>
> **Do not add** login, an admin dashboard, attendance history screens, time-window rules, video
> recording, or any features beyond the PDF. Polish and detail are welcome; extra features are
> not.
>
> **Deliverables:** all screens and states listed above, laid out as a flow; the design-system
> page; short annotations on interactive behavior: what is disabled when, what animates, and what
> the user sees during transitions.

</details>

> i have added a design folder. please check it

- **Claude:** reviewed the six design files against the brief and flagged conflicts: a 55 m
  "re-lock" band that breaks the strict 50 m rule, a "timed out" failure label that implies
  timeouts are not retried, and a Home attendance summary that would need native data in Flutter.

> yes apply it, drop home summary, use 30s, delete uploads

- **Decided by the developer:** strict 50 m; no attendance summary on Home; 30 s mock timeout;
  remove the design's `uploads/` folder.
- **Claude:** exported all frames to PNG (`docs/design/screens/`), wrote the design README with a
  deviations table, and updated the rules, product reference, and task files to match.
- **Checked:** spot-checked rendered frames for fonts, icons, and layout.

> add the design in gitignore

> we will handle screenshots later in the project delivery time.

- **Decided by the developer:** `docs/design/` stays local-only; publishing any of it is a
  submission-time decision (noted in task 11).

### Guard-rail hooks · Essential

> Before we start shall we add pre hooks and post hooks?

> add all four hooks

- **Claude:** added Claude Code hooks in `.claude/settings.json`: a Git guard blocking history,
  branch, remote, and GitHub write commands; a protected-files guard (brief PDF, design export,
  `local.properties`, signing files); and Dart format and analyze after each Dart edit.
- **Checked:** each script was tested with synthetic inputs (a `$(git stash)` bypass was found and
  fixed) and then live in the session; probe files were deleted.

### Git workflow and commit checkpoints · Essential

> Are the git rules defined? like will this project follow git flow?

> yes adopt it

> I think git rules should be in a separate file under agent-reference

- **Decided by the developer:** simplified Gitflow (`main`, `develop`, `feature/NN-<slug>`,
  `--no-ff` merges), documented in `docs/agent-reference/git.md`.

> Do not one shot a task. before commiting i want check the git difference. small task scope and
> commit is better. in [another project] what you did was completed everything then separated it
> into commits. i don't want that.

- **Decided by the developer:** every task plan lists commit-sized steps; the agent implements
  one step, stops, and waits for the developer to review the diff and commit.
- **Claude:** added the rule to `AGENTS.md` and `git.md` and saved it as a session preference.

### Handoff prompt and local-only files

> Where is the Fresh prompt.md?

> write the fresh prompt for task 01

> Add @FRESH_PROMPT.md to gitignore

> add the brief PDF to gitignore too

- **Claude:** wrote `FRESH_PROMPT.md`, a self-contained starting prompt for task 01, and recorded
  the brief PDF, `docs/design/`, and `FRESH_PROMPT.md` as local-only (gitignored) by decision.

## 2026-10-13 · Rules cleanup and task 01 start (Claude Code)

### Compact the agent rules

> […] the agents.md file is too large now. compact it or move some sections to agent-references

- **Claude:** cut `AGENTS.md` from 130 to 75 lines. The source-of-truth order moved to the
  product reference; detailed rules stay in the implementation, verification, delivery, and Git
  references, with one-line pointers in `AGENTS.md`.
- **Checked:** the `CLAUDE.md` symlink still resolves; `git diff --check` passed.

### Start task 01 and allow branch creation · Essential

> run @FRESH_PROMPT.md

> you make branches. no problem.

> yes, update the hook to allow branch creation

- **Claude:** stopped at the read-only Git check (no `develop` or feature branch existed). The
  Git guard blocked branch creation even after the developer allowed it, so at the developer's
  request the hook now allows plain branch creation (`switch -c`, `checkout -b`, `branch <name>`)
  while still blocking switching, force variants, deletion, commits, pushes, and merges.
- **Checked:** 21 allow/deny cases against the updated hook, all passing. The developer
  committed the change; Claude then created `develop` and `feature/01-app-shell-native-bridge`.
- **Claude:** read the task, design frames `H1`/`A1`, the design tokens, and the Android/Gradle
  setup (finding that AGP's built-in Kotlin is disabled and Flutter applies KGP 2.3.20), checked
  current Compose BOM and activity-compose versions, and wrote the task 01 plan
  (`docs/plans/2026-10-13-01-app-shell-native-bridge.md`) for approval.

### AI disclosure · Essential

> before starting are you keeping an agent log? the requirement states that readme should include
> […] We can have the essential prompts in the readme then reference the agent log. What do you
> think?

> yes, backfill only claude. […]

- **Decided by the developer:** the README quotes the essential prompts and links to this log;
  the backfill covers Claude sessions only.
- **Claude:** started this log, backfilled from the two Claude Code session transcripts, and
  marked the essential prompts.

### Task 01, step 1: Home replaces the counter

> committed, plan approved, start step 1

- **Decided by the developer:** the task 01 plan is approved as written.
- **Claude:** first wrote a hand-rolled `formatHomeDate` test-first (tests failed against an
  empty stub, then passed). Added `SnapendanceApp` and the H1 Home layout with the static Attendance subtitle, set the
  launcher label to "Snapendance", and removed the counter demo, its test, and `cupertino_icons`.

> Short form date works. No need to add verbiage. like Tue would work. And use date format rather
> than making your own weekdays and months

- **Decided by the developer:** short date ("Tue, 13 Oct") using `intl`'s `DateFormat`.
- **Claude:** replaced the hand-rolled formatter with `DateFormat('EEE, d MMM')` inline in Home
  and removed the formatter and its tests, which would now only test `intl`.
- **Checked:** the pattern prints "Tue, 13 Oct", "Sun, 18 Oct", "Fri, 1 Jan" for sample dates;
  `dart format`, `flutter analyze`, `flutter build apk --debug`. No Flutter tests remain after
  this step.

> Test on the connected device first

- **Checked on device:** Samsung Galaxy A04s (SM-A047F), Android 14, debug APK. Launch shows
  the Snapendance Home with "Tue, 13 Oct" and the Attendance card, not the counter; the APK's
  application label is "Snapendance"; rotation to landscape and back keeps the layout intact.
  The default Material theme (Roboto, purple) is expected until step 2. On this 360 dp-wide
  screen the Attendance subtitle wrapped to two lines.

> shorten it, then I'll commit

- **Decided by the developer:** Attendance subtitle shortened to "Office setup and check-in"
  (fits on one line on the 360 dp screen).

### Task 01, step 2: Flutter theme and fonts

> start step 2

- **Claude:** added the light tokens (`lib/app/theme/app_tokens.dart`: colors, status colors,
  spacing, radius, font families) and `buildLightTheme()` with the type scale and a
  `StatusColors` `ThemeExtension`. Bundled static IBM Plex Sans 400/600/700 and Plex Mono 500
  TTFs from IBM's GitHub releases (`@ibm/plex-sans@1.1.0`, `@ibm/plex-mono@2.5.0`; the npm
  packages ship no TTFs) with `OFL.txt`. Home now uses the tokens.
- **Claude, after the first device screenshot:** the status bar had a grey scrim and the nav
  bar was black, the card shadow was heavier than the design's Level 1, and the pin was filled.
  Switched to edge-to-edge with transparent bars and dark icons, lowered the shadow alpha, and
  used the outlined pin (closer to H1's Material Symbols glyph).
- **Checked:** `dart format`, `flutter analyze`, `flutter build apk --debug`; on the Galaxy A04s
  (Android 14) Home matches H1 in font, colors, spacing, card, and status bar. No Flutter tests
  in this step (pure styling, per the plan).
- **Separate review (read-only agent):** changes requested, Minor findings only, all confirmed
  against the code and engine source. Fixed: edge-to-edge applies only from API 29 and nav-bar
  styling only from API 26 (`PlatformPlugin.java`), so the comment was corrected and the nav bar
  uses the opaque page color; the global card theme no longer sets elevation/shape (it would have
  broken later `Card.outlined` rows); secondary/tertiary roles map to the primary tokens instead
  of M3's teal defaults, with `onErrorContainer` set; card subtitle line height 18 px as in H1.
  Deferred: the mono text style (Upload Manager task).
- **Decided by the developer:** keep the outlined pin. Plan D7 amended (rounded, or outlined
  where the design glyph is unfilled) and the icon deviation added to `docs/design/README.md`.
- **Checked after fixes:** `dart format`, `flutter analyze`, `flutter build apk --debug`; Home
  unchanged on the Galaxy A04s. Android 7-9 bar behavior is reasoned from engine source, not run.

> ignore the UI differences unless i tell you to. don't need to be perfect for this assignment task

- **Decided by the developer:** small visual differences from the design are not pursued unless
  requested; reviews no longer report them.
- **Separate review of the fixes (read-only agent):** approved, no findings; it confirmed the
  engine API gating, the per-card elevation/shape, and the color-role mapping. `dart format` and
  `flutter analyze` clean.

### Task 01, step 3: Compose enabled, empty native screen

> run @FRESH_PROMPT.md

- **Claude:** added the Compose compiler plugin `org.jetbrains.kotlin.plugin.compose` 2.3.20
  (matches KGP) in `settings.gradle.kts` and `:app`, `buildFeatures { compose = true }`, the
  Compose BOM, `activity-compose` 1.13.0, `ui`, `material3`, `ui-tooling-preview`, and
  `ui-tooling` (debug only). Added `AttendanceActivity` (`ComponentActivity` + `setContent`)
  with an empty `AttendanceScreen`, registered with `exported="false"`, `singleTop`, and the
  same empty task affinity as `MainActivity`. The application has no theme, so a theme-less
  Activity would show the platform action bar: added `AttendanceTheme`
  (`Theme.Material.Light.NoActionBar`, window background `#EEF2F7` from a new
  `attendance_background` color). Edge-to-edge is left for step 4 with the top bar.
- **Problem:** the planned BOM `2026.09.00` failed `checkDebugAarMetadata`: Compose ui 1.12.x
  (BOMs `2026.08.00`+) needs AGP 9.1.0 and compileSdk 37, while the Flutter template pins AGP
  9.0.1 and compileSdk 36. Claude checked the AAR metadata on Google Maven: ui 1.11.4 needs
  compileSdk 35 / AGP 8.6.0.
- **Decided by the developer:** use BOM `2026.06.01` (ui 1.11.4, material3 1.4.0) rather than
  upgrade the toolchain. Plan D11 amended.
- **Plan risk resolved:** the Compose plugin applies alongside the implicitly applied KGP; no
  explicit `kotlin-android` was needed.
- **Checked:** `./gradlew :app:assembleDebug`, `flutter build apk --debug`, `flutter analyze`,
  `git diff --check`; `aapt2` shows the packaged Activity attributes and theme. On the Galaxy A04s
  (Android 14) the debug APK installs and the Flutter Home launches unchanged. `am start` of
  `AttendanceActivity` from the shell is denied ("not exported"), so the empty screen itself
  was not seen on the device; it has no entry point until step 5. No tests in this step (build
  configuration and an empty screen, per the plan).
- **Separate review (read-only agent):** approved, no Critical or Major findings; it confirmed the
  BOM compatibility claim against Google Maven, the resolved versions, and the packaged manifest.
  Fixed both optional findings: the sync note in `app_tokens.dart` now names the third copy of
  the background color (`colors.xml`), and the plan's file list includes `colors.xml`.

### Task 01, step 4: Compose theme and attendance top bar

> run @FRESH_PROMPT.md

- **Claude, test first:** added the instrumented test setup (`testInstrumentationRunner`,
  Compose `ui-test-junit4` from the BOM, `androidx.test:runner` 1.7.0, `androidx.test.ext:junit`
  1.3.0, `ui-test-manifest` debug only) after checking AAR metadata on Google Maven: the
  `androidx.test` artifacts have no compileSdk/AGP constraints, Compose test 1.11.4 needs
  compileSdk 35 / AGP 8.6.0. `AttendanceActivityTest` taps the node with content description
  "Navigate back" and asserts the Activity is finishing. Against the empty screen it failed as
  expected on the Galaxy A04s: `Expected exactly '1' node but could not find any node that
  satisfies: (ContentDescription = 'Navigate back')`. The v1 `createAndroidComposeRule` is
  deprecated in 1.11.4, so the test uses the `junit4.v2` rule.
- **Claude, implementation:** `AttendanceTokens.kt` (same token names and values as
  `app_tokens.dart`), `AttendanceTheme.kt` (light `MaterialTheme` with the same role mapping, the
  design type scale in IBM Plex Sans, `StatusColors` data class in a `CompositionLocal`), IBM
  Plex TTFs copied to `res/font/`, `ic_arrow_back.xml` from Google's Material Symbols Rounded
  Android vectors (only the AppCompat tint attribute removed), title and content description in
  `strings.xml`, and the A1 top bar (M3 `TopAppBar`, which handles the status-bar inset) with an
  empty `Scaffold` body and a themed `@Preview`. The arrow calls `finish()` through the
  Activity's `onNavigateBack` callback; system Back is not overridden. `enableEdgeToEdge` uses
  light system-bar styles so icons stay dark even in system dark mode; per the activity 1.13.0
  source, the black dark scrim applies only to the nav bar on API 24-25.
- **Checked:** the test passes; a mutation (`onNavigateBack = {}`) failed it with
  `AttendanceActivity should finish`, then was restored. `assembleDebug`,
  `connectedDebugAndroidTest`, `flutter build apk --debug`, `flutter analyze`, `git diff --check`.
  A1 on the Galaxy A04s (Android 14), seen through a throwaway instrumented test that held the
  screen open (deleted afterwards): back arrow and "Attendance" in Plex SemiBold, navy on
  `#EEF2F7`, dark status-bar icons, transparent gesture nav bar. Not seen: Android 7-13 bar
  behavior (reasoned from source), and the screen opened from Flutter (step 5).
- **Separate review (read-only agent):** approved, no Critical or Major findings; it confirmed
  all six implementation claims (AAR metadata, required `@OptIn`, edge-to-edge behavior by API
  level, v1 rule deprecation, vector source, byte-identical fonts) and ran the device test four
  times. Fixed its Minor finding: Compose color roles the design does not set fell back to M3's
  purple defaults while Flutter falls back to `surface`/`onSurface`/`onPrimary` (checked in
  Flutter's `color_scheme.dart`); those roles are now set explicitly. Also took its optional
  notes: a wrapped KDoc line, an accurate `ui-test-manifest` comment, and `colors.xml` naming
  `AttendanceTokens.kt`. Re-checked with `assembleDebug` and `connectedDebugAndroidTest`.

### Task 01, step 5: open attendance over the method channel

> run @FRESH_PROMPT.md

- **Claude, test first:** `test/app/home/home_screen_test.dart` pumps the real Home with a real
  `AttendanceLauncher`, registers a mock handler on `com.shafayatb.snapendance/navigation`
  (the name written out in the test, so a rename in the app fails it), checks the Attendance card
  is exposed as a button with a tap action, taps it, and asserts exactly one `openAttendance` call
  with no arguments. Before the API existed it failed to compile; with the launcher and the
  constructor parameter added but the tap unwired, it failed as expected: `Expected: has
  semantics with actions: [tap] with flags: isButton ... missing actions: [tap]`.
- **Claude, implementation:** `AttendanceLauncher` (`lib/app/native/attendance_launcher.dart`, a
  const concrete class around the `MethodChannel`) is created in `main.dart` and passed through
  `SnapendanceApp` to `HomeScreen` by constructor. The card is a `Card` (`Clip.antiAlias` for the
  ripple) with `Semantics(button: true)` and an `InkWell`; the card's merged label is unchanged.
  `MainActivity.configureFlutterEngine` registers the handler: `openAttendance` starts
  `AttendanceActivity` with an explicit intent and replies `null`; other methods get
  `notImplemented()`. The `startActivity` failure mapping stays in step 6: Claude checked the
  engine's `MethodChannel.java`, which catches a handler's `RuntimeException` and replies with an
  error envelope, so step 5 does not crash on a launch failure.
- **Checked:** the test passes. Mutations, each restored: method `openAttendence` failed it
  (`Expected: 'openAttendance' Actual: 'openAttendence'`); channel `.../nav` failed it
  (`Expected: an object with length of <1> Actual: []`). `dart format`, `flutter analyze`,
  `flutter test`, `flutter build apk --debug`, `assembleDebug`, `connectedDebugAndroidTest`
  (existing native test still passes), `git diff --check`.
- **Checked on device:** Galaxy A04s (Android 14), debug APK reinstalled after the instrumented
  run. Android's accessibility tree shows the card as a clickable Button. Tapping it opens A1;
  the back arrow and system Back each return to Home; six round trips in all (three each), every
  screen confirmed. Afterwards the task holds only `MainActivity` (`sz=1`); logcat shows no crash
  or channel errors. Not checked here: rapid double taps (step 7).
- **Separate review (read-only agent):** approved, no Critical or Major findings; it confirmed
  the channel/method names, the single reply on every path, no Activity leak (the engine is owned
  by `MainActivity`), the semantics merge, and the engine claim. Fixed both Minor findings: the
  redundant `ensureSemantics()` handle (`testWidgets` enables semantics by default and the
  handle leaked if an expect failed) and the launcher doc comment ("accepted the request to
  start it", since `startActivity` only queues the launch). Its Optional note is for step 6: the
  `onTap: attendanceLauncher.open` tear-off drops the future and must become an awaited, caught
  call. Re-checked with `dart format`, `flutter analyze`, `flutter test`, `git diff --check`.

### Task 01, step 6: feedback when attendance cannot open

> run @FRESH_PROMPT.md

- **Claude, test first:** two widget tests in `test/app/home/home_screen_test.dart`, using the
  real Home and the real `AttendanceLauncher`. (1) The method handler throws
  `PlatformException(code: 'ATTENDANCE_UNAVAILABLE')`: tapping the card shows "Couldn't open
  Attendance. Please try again.", and a second tap reaches the handler again. (2) No handler: the
  first try (`setMockMethodCallHandler(channel, null)`) never raised `MissingPluginException`,
  because `TestDefaultBinaryMessenger.send` forwards to the real engine when nothing is mocked and
  no reply arrives under fake async. Android's `DartMessenger` sends an empty reply when a channel
  has no handler, and `MethodChannel` turns a null reply into `MissingPluginException`, so the test
  uses a binary `setMockMessageHandler` that returns null. Expected failures before the
  implementation: uncaught `PlatformException(ATTENDANCE_UNAVAILABLE, null, null, null)` and
  uncaught `MissingPluginException(No implementation found for method openAttendance on channel
  com.shafayatb.snapendance/navigation)`, each followed by `Found 0 widgets with text "Couldn't
  open Attendance. Please try again."`.
- **Claude, implementation:** `AttendanceLauncher.open()` turns `PlatformException` and
  `MissingPluginException` into `AttendanceLaunchException`, which keeps the cause for debugging.
  Home replaces the step 5 tear-off, which dropped the future, with `_openAttendance(context)`.
  That method awaits the launch, catches `AttendanceLaunchException`, checks `context.mounted`,
  and replaces any visible SnackBar with the message. Only a SnackBar call is involved; there is
  no stored state and no Cubit (D4). `MainActivity` catches `ActivityNotFoundException` from
  `startActivity` and replies with `result.error("ATTENDANCE_UNAVAILABLE", …)`. Other exceptions
  are left to the engine: its `MethodChannel.java` logs them and replies with an `"error"`
  envelope, so Dart still shows the message. Nothing tests the Kotlin path automatically (the plan
  says so); it is reasoned from the code.
- **Mutation checks**, each restored afterwards:
  - No `MissingPluginException` catch: the no-handler test fails.
  - No `PlatformException` catch: the handler-error test fails.
  - Home back to `onTap: attendanceLauncher.open`: both tests fail with an uncaught
    `AttendanceLaunchException`.
  - Only the first failure shows the SnackBar (the reviewer's mutation, run after the fix below):
    the retry test fails.
- **Checked:**
  - `dart format`, `flutter analyze`, `flutter test` (3/3), `flutter build apk --debug`,
    `assembleDebug`, `git diff --check`.
  - `connectedDebugAndroidTest` passed (1/1).
  - On the Galaxy A04s (Android 14), after reinstalling the debug APK: the card opens A1; the
    arrow and system Back each return to Home (two round trips); the task holds only
    `MainActivity` (`sz=1`); logcat shows no crash or channel errors.
  - The failure SnackBar was seen only in widget tests. A real launch failure cannot be triggered
    on the device without changing app code.
- **Separate review (read-only agent): approved with minor fixes.** No Critical or Major
  findings. It confirmed the engine/SDK claims, the catch widths, `result.success` inside the
  `try`, the `mounted` guard, and that nothing beyond step 6 was added.
  - Fixed its Minor finding: in the retry test, the first SnackBar was still on screen at the last
    check (`pumpAndSettle` does not run the 4 s display timer). As a result, a "show only once"
    regression passed. The test now waits for the first message to time out, asserts it is gone,
    then expects a new one.
  - Not taken:
    - The test for a missing handler does not tap a second time, because the retry test already
      covers the same catch path.
    - Replacing a visible SnackBar is not tested; it is a small UX choice, not a requirement.
    - `tearDown` keeps both handler resets for clarity.
  - Re-checked with `dart format`, `flutter analyze`, `flutter test`, and `git diff --check`.

### Task 01, step 7: verification and records

> committed, continue with step 7

- **Checked on the step 6 commit:** `dart format`, `flutter analyze` (no issues), `flutter test`
  (3/3), `flutter build apk --debug`, `./gradlew :app:assembleDebug`,
  `connectedDebugAndroidTest` (1/1 on the A04s); debug APK reinstalled afterwards.
- **Device run** (manual): Galaxy A04s (SM-A047F), Android 14, debug APK. Activity stacks read with
  `dumpsys activity activities` after every action.
  - Five round trips (arrow, system Back, arrow, system Back, arrow): A1 opened each time; back on
    Home the task held only `MainActivity` (`sz=1`), the same Activity record every time, so Home
    was not recreated.
  - Rapid double taps, five attempts (a one-gesture double tap, two taps fired in parallel from the
    device shell, and taps about 0.1, 0.2, and 0.35 s apart): each produced exactly one
    `START ... AttendanceActivity` in logcat, one instance in the task, and one Back returned Home.
    The second tap never reached the channel, so `singleTop` de-duplication itself was not
    exercised. Per plan D5 no in-flight guard was added.
  - Rotation on A1 (auto-rotate forced off, display rotated to landscape and back, settings
    restored to `accelerometer_rotation=1`, `user_rotation=0`): the top bar survived and stayed
    clear of the cutout side; the arrow (in landscape) and system Back (after rotating back) each
    returned to Home. Home also rendered in landscape.
  - Background/return: Home button, then Recents, on A1 and on Home; each resumed the same
    screen, and the card still opened A1 afterwards.
  - System Back on Home finishes the Flutter task (expected; the next launch is a cold start).
    One tap sent about 2.5 s into a cold debug start did nothing: logcat shows the debug Home
    took 5.2 s to display, so the tap landed before the first frame. Not a defect.
  - Logcat: no crash for the app. The app process logged vendor graphics noise
    (`GraphicBufferAllocator` 4×4 allocation failures) and one `Invalid resource ID 0x00000000`,
    neither fatal nor investigated. A `FATAL EXCEPTION` from the shell `uiautomator` tool was a
    clash with the automation service already registered, not the app.
  - H1 and A1 were captured on the device to check them, then deleted at the developer's request.
    Submission screenshots come later.
- **Not seen on a device:** the failure SnackBar (widget tests only) and the Kotlin
  `result.error("ATTENDANCE_UNAVAILABLE", …)` path (no automated test; reasoned from the code).
  Android 7-13 system-bar behavior is reasoned from source (steps 2 and 4).
- **Records:** the `docs/design/README.md` icon deviation row was confirmed against the code and
  the task 01 fonts/icons item moved from "Still open" to "Resolved" (plan D6/D7). The
  implementation reference no longer claims built-in Kotlin (`android.builtInKotlin=false`; the
  Flutter Gradle plugin applies `kotlin-android`) and describes the Compose setup as done, with
  the Compose ui 1.11.x limit of AGP 9.0.1 / compileSdk 36.
- **Task review (one read-only agent, whole task 01 diff): approved with minor fixes.** No
  Critical or Major findings. It confirmed the channel contract and single reply on every path,
  the Dart error mapping, the Activity configuration, that the tests are meaningful, identical
  token files and fonts, the Compose BOM limit (from the Gradle cache), that `ui-tooling` and
  `ui-test-manifest` are left out of release, and the implementation reference edit.
  - Fixed: `git diff --check develop...HEAD` failed on `assets/fonts/OFL.txt`. The upstream file
    has CRLF line endings and a trailing space on line 21; earlier checks missed it because the
    file was untracked then. It is now LF with no trailing space, and the license text is
    unchanged (`git diff -w --ignore-cr-at-eol` is empty).
  - Fixed: the backlog still showed task 01 in progress and its decisions as open. Also reworded
    the `kotlin-android` note in the implementation reference.
  - Not taken (optional): a "no SnackBar on success" assertion in the success widget test, and
    the manifest comment that says "same affinity" (both Activities set `taskAffinity=""`; they
    share a task because the launch has no `NEW_TASK`). Both would change app code in a
    records-only step; they are left for a later native task.
  - Re-checked: `git diff --check develop` is clean.

## 2026-10-13 · Task 02: attendance office setup (Claude Code)

### Task 02: set the office location · Essential

> run @FRESH_PROMPT.md

Task 02 was chosen from a question ("02 Office setup"). The plan
(`docs/plans/2026-10-13-02-attendance-office-setup.md`, decisions D1-D12) was approved with:

> approved.

Each step then started from a fresh session or after a commit:

> committed. continue with step 2

> start task 2 step 4

> start task 2 step 8

> committed, continue with the records step

> committed, continue with step 11

- **Approach:** native Kotlin/Compose, test first per step. A pure fix policy (≤ 25 m and ≤ 30 s,
  inclusive; no accuracy means inaccurate); a Preferences DataStore office store; a Fused Location
  Provider source streaming 1 s high-accuracy updates; `AttendanceViewModel` saving the first
  accepted fix within 15 s, with one-off events for failures; the Step 1 card (A1, A2, P2); and the
  A6-A8 blocker panel with recovery (ask again, app settings, Play services "turn on location").
- **Decisions beyond the plan:**
  - Step 3: if location updates cannot start (no Play services, permission revoked), the flow fails
    and the attempt reports "no fix" at once instead of waiting 15 s.
  - Step 7: on the phone, one "Keep approximate location" was permanent, so A7 also gets an "Open
    app settings" variant (`ApproximateOnly(canAskAgain)`).
  - Versions: lifecycle 2.10.0 (2.11.0 failed `checkDebugAarMetadata`: compileSdk 37, AGP 9.1);
    `kotlinx-coroutines-test` 1.9.0 to match the app's resolved coroutines.
- **Test-first evidence** (JVM, `testDebugUnitTest`; 35 tests before the review fixes, 40 after):
  - Fix policy (5): the rejection tests failed on an accept-all stub; changing `>` to `>=` on
    accuracy made `fixAtBothLimitsIsAccepted` fail (restored).
  - Store (2): read-back failed on a placeholder; writing longitude into the latitude key made it
    fail (restored). Runs against a real DataStore file, closed and reopened.
  - ViewModel (28): 12 of the first 13 failed on an empty ViewModel; six mutations (no cancel on
    stop, no in-flight guard, 30 s timeout, worst accuracy reported, no replace confirmation, no
    stale message) were each caught (restored). Step 5's permission/services tests failed on their
    assertions first; three that passed on stubs were tightened to assert the blocker shows before
    recovery.
- **Problems found on the device (step 8 run), each fixed as its own step:**
  - Rotating during a fetch cancelled it: recreation passes `ON_STOP`, which sends
    `ScreenStopped`. Captures before/after showed "Getting GPS fix… ±33 m" turn into A1 and the
    location icon go out. The user chose:

    > Lock the orientation for now and keep it as improvements. if we get time then we will optimise it

    `AttendanceActivity` is portrait-only; the proper fix is in the backlog's deferred
    improvements. Re-run: forced landscape mid-fetch, same Activity record, fetch continued.
  - On a cold start the card showed "No office location saved" and the filled button until
    DataStore's first read (still wrong 13.3 s after the tap on the emulator, right by 14.2 s;
    under 0.8 s on the phone), and a tap in that window would skip the replace confirmation. The
    user chose "Fix now as its own step". `isOfficeLoaded` gates the tap and shows a loading
    panel. Test first: `setOfficeWaitsUntilTheSavedOfficeHasLoaded` failed with `expected null,
    but was:<FixAttempt(latestAccuracyMeters=null)>`, then passed.
- **Device run** (manual; debug APK):
  - Galaxy A04s (SM-A047F), Android 14, fresh install: A1 on first run; deny once → A6 "Allow
    location"; deny again → A6 "Open app settings"; approximate-only granted in app settings → A7
    on return without a restart; "Keep approximate location" → A7 "Open app settings"; precise
    turned on in settings → A1 on return. Location off (shell) → a tap shows A8; "No, thanks" on
    the Play services dialog keeps A8; location on, then "Turn on location" clears it (the
    already-on path). The dialog's "Turn on" was not tapped, because it would also switch on
    Google Location Accuracy on the developer's phone.
  - Same phone, real GPS: at a desk the best fix was ±27 m, so the attempt failed with "GPS
    accuracy ±27 m; ±25 m or better is needed." and Retry, saving nothing. Near a window the
    developer saved a ±17 m fix ("Today, 23:11", the phone's 24-hour setting); it survived a
    force-stop and cold reopen. Coordinates are not recorded here.
  - Emulator (Pixel AVD, Android 16, Play services): silent test providers → "Couldn't get a GPS
    fix…" with Retry after 15 s, nothing saved; the location log shows the request added and
    removed 15 s later. Home during a fetch → cancelled silently, request removed at Home. Mock
    fix at ±6 m saved and shown; process death (`run-as … kill`; `am kill` left the process
    running) restored the screen with the office; replace dialog: Cancel kept it, Replace saved a
    new ±8 m fix; force-stop and cold reopen showed it. Test providers removed afterwards.
  - Not seen on a device: the stale-fix message, the save/load storage errors (JVM tests only),
    the loading panel itself (too brief on the phone; the emulator's recording stayed on the
    Flutter splash), and the system location-settings fallback when the Play services dialog
    cannot be shown.
- **Task review (one read-only agent, whole task diff): approved with minor fixes.** No Critical or
  Major findings. It confirmed the fix policy, the 15 s attempt and update removal, the in-flight
  guard, the A6/A7 variants, the services checks, event delivery, no Activity leaks, and both
  device-run fixes. Each finding was checked against the code; the user chose "Fix 1-6 in two
  steps":
  - Fixed (step 10): a double tap sent a second permission request while the dialog was open; the
    system answered it empty ("Can request only one set of permissions at a time"), A6 appeared
    behind the dialog, and the real grant was lost, so no fetch started. Reproduced on the phone
    before the fix; after it, one request and the grant goes straight to the fetch.
  - Fixed (step 10): after a failed read the store was no longer observed, so a later save never
    showed; a corrupt file failed every save. Now a save sets the office on screen, and a corrupt
    file is replaced with an empty one. Also covers the review's test-gap finding.
  - Fixed (step 10): two Replace confirms could start two location collections.
  - Fixed (step 11): `lintDebug` error `NonObservableLocale` (locale read in a composable); a
    rejected 25.1-25.49 m read "±25 m; ±25 m or better is needed" (now rounded up).
  - Step 10 tests, each failing first: `secondTapWhileThePermissionDialogIsOpenDoesNotAskAgain`
    (two requests instead of one), `allowLocationAsksOnceUntilTheDialogAnswers` (no-op stub),
    `officeSavedAfterAFailedReadIsShown` (`null` office), `confirmingReplaceTwiceStartsOneRequest`
    (`expected:<1> but was:<2>`), `corruptFileReadsAsNoOfficeAndCanBeSavedOver`
    (`CorruptionException`). Step 11 had no test: lint is the check (1 error before, 0 after), and
    the rounding is a one-call change; the rounded-up message was not seen on a device.
  - Accepted, not changed: dismissing the permission dialog by tapping outside reads as "won't ask
    again" on Android 11+ (A6 offers app settings; recovery still works). Recorded under plan D5.
- **Checks at the end:** `testDebugUnitTest` 40/40, `lintDebug` 0 errors (7 expected warnings: held
  versions, the portrait lock, the template's `drawable-v21`), `assembleDebug`, `flutter build apk
  --debug`, `connectedDebugAndroidTest` 1/1 on the A04s (before steps 10-11, which change no code
  it covers), `git diff --check` clean.
- **Records:** plan steps 8-12 and the D5/D9 amendments, task file wording (D2, portrait note),
  backlog status, approved decision, and "Deferred improvements", design deviations (A6/A7
  recovery variants, saved office under a blocker, replace dialog, loading panel).
- **Git:** `feature/02-attendance-office-setup`, one commit per step (`841a3a0`..`8ebf9f1`, plus
  this records step), all committed by the user; merge into `develop` is the user's.
