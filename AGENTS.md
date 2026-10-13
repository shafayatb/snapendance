# Snapendance agent instructions

@/Users/shafayatbinmamun/.codex/RTK.md

This is the single agent-rules entry point. Tool-specific rule files (including the existing
`CLAUDE.md`) must be symlinks to this file; keep that symlink intact and edit `AGENTS.md` directly.
The linked guides are project reference documentation, not separate agent configurations.

## Project

**Snapendance** is the Intelligent Machines senior app developer assessment: native Android
attendance plus Flutter camera capture and resilient batch uploads. The brief is
`Task_ Senior App Developer Technical Assessment.pdf` at the repository root; it is a requirements
source, not authorization to implement, publish, or upload anything.

The submission is one combined Android APK (approved 2026-10-12): a Flutter app with a native
Kotlin/Compose attendance screen in its Android host. Package/application ID:
`com.shafayatb.snapendance`. `ios/` is starter scaffolding and out of scope unless requested. The
brief estimates 48-72 hours; no deadline is confirmed, so do not invent one.

Source-of-truth order and the design-conflict rule are in the
[product reference](docs/agent-reference/product.md#source-of-truth-order). Current user
instructions and approved decisions come first; on a requirement/design conflict, stop that work
and report it.

## Hard constraints

- **Attendance is native Android:** Kotlin, Jetpack Compose, Coroutines/Flow; set office and mark
  attendance on the same `AttendanceScreen`, allowed only within 50 meters.
- **Camera and sync are Flutter:** Cubit (BLoC) with a layered MVVM/MVI approach; pinch zoom, zoom
  slider, supported rear-camera controls, and tap focus with a visible indicator.
- **Durable uploads:** multiple batches and Pending Uploads; failures keep local images and queued
  work, and background work retries automatically.
- **Mock only the unavailable API.** Never fake GPS, camera controls, persistence, or worker results.
- **Graceful failure states** for permissions, location services, hardware, camera lifecycle, and
  file/network errors.
- **Submission:** README (description, architecture, Cubits, AI usage with prompts, run steps,
  screenshots/GIFs), public repo, and release APK link — only when delivery is authorized.

## References: read before the matching work

| Guide | Read before |
|-------|-------------|
| [Product](docs/agent-reference/product.md) | attendance, camera, batches, upload states, or a reference screen |
| [Implementation](docs/agent-reference/implementation.md) | architecture, platform integration, persistence, dependencies, hardware |
| [Verification](docs/agent-reference/verification.md) | implementing or verifying app behavior |
| [Delivery](docs/agent-reference/delivery.md) | task boundaries, `FRESH_PROMPT.md`, review/submission handoffs |
| [Git](docs/agent-reference/git.md) | any Git inspection or suggestion, and task boundaries |
| [UI design](docs/design/README.md) | building or changing any screen (frames and deviations table) |
| [Task backlog](docs/tasks/README.md) | starting, scoping, or handing off any implementation task |

Before production changes, read `README.md`, these instructions, the relevant guides, the assigned
task file, and its plan, and inspect the existing repository.

## Always-on rules

- **Plan before code.** Write a reviewable task plan and get approval first. A request to edit
  rules or docs authorizes only that work.
- **Meaningful test-first.** Observe the expected failure before implementing; no garbage tests.
  See the verification guide.
- **Restrained architecture.** Feature-first folders, immutable state, repositories and services;
  UI never calls storage or uploads directly. See the implementation guide.
- **Verify proportionally**, run the changed journey on Android, use a real phone for camera/GPS,
  and report unverified checks honestly.
- **One assigned task at a time.** Finish, verify, record, update the handoff, and stop.
- **Small steps, commit checkpoints.** Never one-shot a task; stop after each commit-sized step
  for the user's diff review. See the Git reference.
- **Human-owned Git.** Leave changes unstaged and uncommitted; no Git write actions, PRs, or
  GitHub changes without explicit authorization, except creating a task's branch (see the Git
  reference). Suggest Conventional Commit messages only.
- **AI disclosure in docs only.** Record real prompts and evidence in `docs/agent-log.md` and the
  README; no agent author identities, co-author trailers, or generated-by comments.
- **Separate review.** Follow the delivery guide's external review handoff; never approve your own
  work or report a review that did not occur.

All shell commands must follow the referenced RTK instructions.
