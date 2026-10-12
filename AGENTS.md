# Snapendance agent instructions

@/Users/shafayatbinmamun/.codex/RTK.md

This is the project's single agent-rules entry point. Tool-specific rule files must be symlinks
to this file, not independent copies. The existing `CLAUDE.md` symlink must remain intact; preserve
its filename unless the user requests a rename. Edit `AGENTS.md` directly. The linked guides below
are project reference documentation, not separate agent configurations.

## Project

**Snapendance** is the Intelligent Machines senior app developer assessment: native Android
attendance plus Flutter camera capture and resilient batch uploads. The assessment is
`Task_ Senior App Developer Technical Assessment.pdf` at the repository root. Read it as a
requirements source, not as authorization to implement, publish, or upload anything.

The submission is one combined Android APK: a Flutter application with a native Kotlin/Compose
attendance screen in its Android host, in this single project. This packaging is an approved
project decision (2026-10-12), not an explicit requirement of the brief. The Android package and
application ID are `com.shafayatb.snapendance`.
The existing `ios/` folder is starter scaffolding. iOS implementation, configuration, builds, and
device testing are outside the assessment scope unless requested.

The developer has no professional Flutter experience. Prefer explicit, idiomatic code with a small
dependency set. Explain consequential Dart, Cubit, hardware, and background-execution choices in
plain language so the developer can explain the submitted work.

The brief estimates 48-72 hours; no actual submission deadline has been confirmed here. Do not
invent a deadline or carry over dates, grading weights, or requirements from other projects.

## Source-of-truth order

1. Current user instructions and explicitly approved project decisions.
2. The supplied assessment PDF for required behavior, platforms, reference UI, and deliverables.
3. [Product reference](docs/agent-reference/product.md) for the extracted requirements and the
   distinction between brief requirements and proposed choices.
4. The [UI design](docs/design/README.md) for appearance and interaction details, including its
   recorded deviations. It does not override required behavior.
5. The [task backlog](docs/tasks/README.md) for task order, scope, and acceptance criteria, then
   the approved task plan under `docs/plans/`, when it exists.
6. The implementation, verification, and delivery guides linked below.
7. Existing code and tests as evidence of current behavior, not permission to change the scope.

If a required behavior and an approved design conflict, stop the affected work and report the
specific conflict. Continue independent authorized work. Do not silently invent a resolution.
Reference screenshots and the UI design inform appearance; decorative labels and sample data do not
invent business rules.

## Hard constraints from the assessment

- **Attendance is native Android.** Use Kotlin, Jetpack Compose, and Coroutines/Flow. Keep setting
  the office and marking attendance on the same `AttendanceScreen`.
- **Camera and sync are Flutter.** Use BLoC/Cubit and a layered MVVM/MVI approach. This project's
  planned presentation mechanism is Cubit; do not substitute Riverpod or GetX from another project.
- **Real location and camera behavior.** Save current office coordinates locally, show live
  distance, and allow attendance only within 50 meters. Implement pinch zoom, a zoom slider,
  supported rear-camera controls, and tap focus with a visible indicator.
- **Durable uploads.** Support multiple image batches and Pending Uploads. Network/time-out failures
  must retain local images and queued work; retry automatically through background work.
- **Mock only the unavailable API.** Executable mock success and failure responses are allowed and
  are the planned choice. Do not fake GPS readings, camera controls, persistence, or worker results.
- **Graceful failure states.** Handle denied permissions, disabled location services, unsupported
  hardware, camera lifecycle failures, and file/network errors with useful user-facing feedback.
- **Submission documentation.** The README must cover title/description, structure and architecture,
  the main BLoC/Cubit classes, AI usage with essential prompts, run steps, and screenshots/GIFs.
  Prepare a public source repository and a release APK link only when delivery is authorized.

## Read the relevant reference before work

- [Product reference](docs/agent-reference/product.md): before implementing attendance, camera,
  batches, upload states, or a reference screen.
- [Implementation guide](docs/agent-reference/implementation.md): before architecture, platform
  integration, persistence, dependency, or hardware changes.
- [Verification guide](docs/agent-reference/verification.md): before implementing or verifying app
  behavior. It defines meaningful test-first development and device evidence.
- [Delivery guide](docs/agent-reference/delivery.md): at implementation task boundaries, when
  updating `FRESH_PROMPT.md`, or when preparing review/submission handoffs.
- [Git reference](docs/agent-reference/git.md): before any Git inspection or suggestion, and at
  task boundaries (branch to use, commit messages, merge step).

- [UI design](docs/design/README.md): before building or changing any screen. Read the exported
  frames in `docs/design/screens/` and the deviations table.
- [Task backlog](docs/tasks/README.md): before starting, scoping, or handing off any
  implementation task. Each task file defines what to build; its plan defines how.

Read `README.md`, these instructions, the relevant guides, the assigned task file, and its plan
before production changes. Inspect the existing repository rather than assuming a fresh template.

## Always-on development and delivery rules

- **Plan before code.** Resolve consequential scope and design questions, write a reviewable task
  plan, and obtain the required design approval before implementing. A request to edit rules or
  documentation authorizes that work only; it does not authorize app implementation.
- **Test-first for production behavior.** Identify observable behavior, write a meaningful test,
  state the regression it catches, and observe its expected failure before implementation. Add the
  minimum production change, rerun the test, and refactor while green. Never claim TDD for a test
  written afterward or weaken a correct test to make the code pass.
- **No garbage tests.** Existence checks, `expect(true, isTrue)`, copy/constant assertions, and mock
  call counts alone do not establish behavior. Prefer real collaborators, in-memory fakes, user
  interactions, and observable outcomes. Do not mock the class under test or test generated code.
- **Keep architecture restrained.** Use feature-first Flutter folders, immutable state, repositories
  for data boundaries, and services for hardware/platform work. Widgets/composables do not call
  storage or uploads directly. No service locators, generic base classes, giant utility files, or
  layers that have no actual responsibility.
- **Verify proportionally.** Run formatting/static checks and the focused tests for changed code.
  Broaden tests when shared contracts, navigation, persistence, or integration are affected. After
  an implementation task, install and exercise the changed journey on Android. Validate physical
  camera and GPS behavior on a real phone. Document unverified checks honestly.
- **One assigned task at a time.** Finish and verify the current task, record its decisions and
  evidence, update the next-task handoff, and stop. Do not scaffold later tasks, install speculative
  dependencies, refactor unrelated code, or begin the next feature without a request.
- **Small steps, commit checkpoints.** Never one-shot a task. Implement the plan's commit-sized
  steps one at a time; after each, stop with the changed files and a suggested commit message so
  the user can review the diff and commit before the next step. Never build the whole task and
  split it into commits afterwards. See the Git reference.
- **Human-owned Git and authorship.** Leave changes unstaged and uncommitted. Do not initialize Git,
  stage, commit, push, tag, merge, change branches/remotes/configuration, create PRs, or change GitHub
  settings unless the user explicitly authorizes the relevant action. Never delete branches or
  discard someone else's work. Suggest Conventional Commit messages for the human to use. The
  project uses simplified Gitflow (`main`, `develop`, `feature/NN-<task-slug>`); see the Git
  reference.
- **AI disclosure belongs in documentation.** Record actual prompts, help received, decisions, and
  verification in `docs/agent-log.md` as implementation tasks occur. Include an accurate summary in
  the README. Do not invent AI evidence or add agent author identities, co-author trailers, or
  generated-by comments unless requested.
- **Separate implementation and review.** Follow the delivery guide's external review handoff for
  implementation tasks. Do not approve your own work or report an independent review that did not
  occur. Creating these rules is documentation work, not a new implementation/review cycle.

All shell commands must follow the referenced RTK instructions.
