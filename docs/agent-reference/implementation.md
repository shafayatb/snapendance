# Snapendance Implementation Reference

## Existing starting point

As inspected on 2026-10-12, the project is a Flutter starter with Android and iOS host folders, the
counter demo, and its starter widget test. `pubspec.yaml` uses Dart SDK constraint `^3.12.2`.
The Android namespace/application ID is `com.shafayatb.snapendance`, with a Kotlin `MainActivity`
extending `FlutterActivity`. Toolchain at that time: Flutter 3.44.6, Dart 3.12.2, AGP 9.0.1,
Kotlin Gradle plugin 2.3.20, Gradle 9.1.0. AGP's built-in Kotlin is off
(`android.builtInKotlin=false` in `android/gradle.properties`); the Flutter Gradle plugin applies
`kotlin-android` to `:app` implicitly. The iOS bundle ID keeps its
generated value; iOS is out of scope. Inspect again before each task; these facts may change.

Do not rename packages, rewrite the Gradle setup, or replace the starter until that change is part
of the assigned task. Check the installed Flutter/Dart, Java, Android, Gradle, and Kotlin versions
before selecting compatible dependencies. Do not apply old Flutter/Kotlin plugin recipes blindly.

## Intended architecture

Flutter uses a restrained feature-first layout:

```text
lib/
  app/                    application composition, navigation, and theme
  core/                   genuinely shared platform/storage support
  features/
    camera/               camera presentation and hardware boundary
    uploads/              batches, queue persistence, upload UI, and sync engine
```

Within a feature, add `presentation/`, `data/`, and `domain/` only when each has a real
responsibility. A repository owns persisted data; a service isolates hardware or network operations.
Pure rules and models should remain independent of Flutter/plugin imports where practical.

Use `flutter_bloc` with `CameraCubit` and `UploadsCubit` as the planned presentation controllers.
Do not substitute Riverpod, GetX, or another state-management approach.
Widgets render immutable state and send actions. Use explicit constructors for dependency injection
and typed boundary failures mapped to user-facing feedback. Compose collects lifecycle-aware
immutable `StateFlow` state from `AttendanceViewModel` and passes actions to it.

Keep native attendance code in a focused package beneath the current Android application package.
Use a Compose Activity, a ViewModel, a location source/repository, and a local office store. Do not
rewrite attendance in Dart or substitute XML layouts for the required Compose UI.

Compose is enabled since task 01: the Compose compiler Gradle plugin
(`org.jetbrains.kotlin.plugin.compose`, same version as the Kotlin Gradle plugin), `buildFeatures {
compose = true }`, and the Compose BOM. Do not add `composeOptions.kotlinCompilerExtensionVersion`
(the Compose plugin replaces it). `:app` needs no explicit `kotlin-android`; the Flutter plugin
applies it. AGP 9.0.1 and compileSdk 36 limit Compose ui to 1.11.x (BOMs before `2026.08.00`;
the project uses `2026.06.01`). Check AAR metadata before adding AndroidX artifacts
(`checkDebugAarMetadata`).

For the approved combined app, a small platform-channel operation opens the native attendance
Activity. Keep the boundary limited to navigation unless an approved flow needs returned data.
Do not introduce a second Flutter engine, shared database, or large platform bridge speculatively.
Verify Back navigation and resources across the native/Flutter transition.

## State, lifecycle, and errors

- Use explicit states for initialization, permission/error conditions, successful actions, and
  pending work. Keep raw exceptions out of the UI.
- Keep the camera controller behind a lifecycle-aware owner. Dispose/reinitialize as necessary
  when backgrounding, returning, changing lenses, or entering native attendance.
- Clamp zoom to the selected camera's supported bounds. Keep pinch, slider, and buttons consistent.
- Map focus coordinates through preview scaling/cropping and orientation. A visible ring alone
  does not prove a focus request was issued or supported.
- Prevent overlapping capture/lens-switch operations and premature success feedback.
- Stop location updates when no longer needed. Handle precise-versus-approximate permission and
  location-service changes explicitly.
- Avoid storing one-off snackbar/navigation events as persistent booleans requiring resets.
- Prefer small composable widgets/functions, immutable models, clear names, and comments explaining
  decisions. Avoid generated abstractions that make the code harder to read and explain.

## Persistence and sync

Planned tools are SQLite through `sqflite` for batch/image metadata, `path_provider` for durable
image storage, and Android DataStore for the small native office-location record. Final selection
must be verified against actual requirements and compatible package versions.

Store image files outside temporary/cache storage before reporting a durable capture. Use a
stable item ID, batch ID, file path, capture timestamp, status, attempts, and error information.
Do not store image blobs in simple preferences. Handle a failed copy/database operation without
creating a successful-looking queue entry; reconcile orphaned files when necessary.

The queue is the source of truth. UI memory must not own retry state. Model pending, processing,
retryable failure, uploaded, and permanent failure explicitly. Preserve files for network failures.
Record item success before advancing batch progress and do not retry completed items.

The SyncEngine is independent of Cubits. The background callback initializes its own database,
file/API dependencies, and persisted mock configuration. Refresh UI state from storage when the
app resumes. Do not assume callbacks can access foreground objects or update widgets directly.

Use atomic item claims and a recoverable ownership/expiry mechanism to prevent duplicate work
across triggers. Recover abandoned claims after interruption. Keep database transactions short;
do not hold them open over an upload operation. Stable IDs can support idempotency at the API
boundary, but a mock cannot prove production server deduplication.

Use unique network-constrained one-off background work, with backoff for transient failures.
Confirm that batches queued while a worker is active also retain a future processing path.
Reconcile persisted pending work at startup/resume to recover scheduling gaps. Avoid busy loops.

Connectivity events are scheduling hints, not proof of Internet access or stable bandwidth.
Handle upload timeouts/failures even when a network is connected. Scheduling is OS-controlled;
do not claim instant execution or automatic processing while the app is force-stopped. Use
periodic work only as a documented supplementary recovery mechanism.

## Dependency and scope discipline

Prefer explicit, idiomatic code with a small dependency set. For each new dependency, explain its
concrete need, check maintained official documentation and toolchain compatibility, and add only
what the current task needs. Keep `pubspec.lock` with the application. Do not pin versions from memory or install the whole future stack up front.

Avoid service locators, generic BaseRepository/BaseViewModel classes, global mutable singletons,
giant utility/constants files, one-use wrappers, and code generation solely for style.

Keep credentials, signing material, local machine paths, captured personal images, and precise
location data out of public source and logs. Use sanitized demo evidence. Ask only for permissions
the current flow actually needs; still capture does not require a microphone feature.
