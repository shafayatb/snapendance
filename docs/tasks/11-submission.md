# Task 11: Submission

**Depends on:** all · **Track:** delivery

## Goal

Produce the assessment deliverables: a complete README, real screenshots/GIFs, a signed release
APK, and a repository ready to publish. Publishing and uploading happen only when the user asks.

## In scope

- Release signing with a keystore kept outside source; signing values read from an untracked
  properties file or environment. Confirm nothing secret is tracked.
- Release build (`flutter build apk --release`), installed and exercised end to end on a physical
  phone: attendance setup and marking, camera controls, multiple batches, offline → online
  automatic retry.
- README replacing the starter text, with the brief's sections:
  1. Project title and description (Snapendance).
  2. Project structure and approach: combined APK, Flutter feature-first layered architecture,
     Cubit summaries (`CameraCubit`, `UploadsCubit`), native `AttendanceViewModel` with Flow.
  3. Generative AI usage with essential prompts, drawn from `docs/agent-log.md` (real prompts only).
  4. How to run: clone, toolchain versions, `flutter pub get`, run/build commands, permissions.
  5. Screenshots/GIFs of the installed app (sanitized locations; no personal images).
- Notes on the mock API, scheduling delays, force-stop, and anything unverified.
- Final review of `.gitignore`, local paths, and `local.properties`. The brief PDF,
  `docs/design/`, and `FRESH_PROMPT.md` stay untracked.

## Out of scope

iOS builds, demo video, backend. Pushing to GitHub or uploading the APK without a request.

## Acceptance criteria

- The release APK installs and all required journeys pass on a physical phone (recorded).
- README covers all five required sections accurately; every screenshot comes from the real app.
- No signing material, API keys, personal data, or machine-specific paths in tracked files.
- `flutter analyze` is clean and the full `flutter test` suite and native unit tests pass.
- A short list of known limitations is in the README.

## Verification

Full final gate from the delivery reference. Record the device, Android version, and results.

## Decisions for the plan

- APK hosting location (for example Google Drive) and repository name/visibility timing.
- `docs/design/`, `FRESH_PROMPT.md`, and the brief PDF are gitignored (local-only). Decide whether
  any design frames are published, and fix links to local-only files in `AGENTS.md`, `product.md`,
  and the task files that would break in a public clone.

## References

Delivery reference (Final submission gate), product reference (Submission), verification
reference. Docs: Flutter "Build and release an Android app" (signing).
