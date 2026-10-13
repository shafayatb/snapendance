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
