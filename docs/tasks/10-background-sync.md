# Task 10: Background sync and connectivity

**Status:** Not started · **Depends on:** 08, 09 · **Track:** Flutter uploads

## Goal

Run the `SyncEngine` through a background worker so queued uploads retry automatically when a
connection returns, without user intervention, including while the app is in the background.

## In scope

- `workmanager` plugin (verify current version and Android setup). A top-level callback dispatcher
  that builds its own database, file, and mock API dependencies and runs the engine.
- Unique one-off work with a network-connected constraint and backoff, enqueued when a batch is
  submitted and when pending work exists at startup/resume. Use "keep/append" semantics so batches
  submitted during a run are not stranded.
- Periodic work only as a documented supplementary recovery path.
- Worker result mapping: retry on transient failure, success when nothing is left.
- `connectivity_plus` (or equivalent) as a hint to enqueue work and for the Upload Manager's
  connection pill (design `U1-U3`): STABLE LINK, OFFLINE (items show "waiting for connection"), and
  CONNECTED · UPLOADS FAILING (connected, but recent uploads failed). Connectivity is not treated
  as proof of Internet access.
- Manifest permissions needed for network state; nothing more.

## Out of scope

A foreground service, instant upload guarantees, behavior after force-stop.

## Acceptance criteria

- Queue images offline, background the app, restore the network: pending items upload without
  another tap, within Android's scheduling delay.
- A timeout/low-bandwidth scenario leaves images queued and a later run succeeds.
- Batches submitted while a worker is running are processed by that run or a later one.
- The Upload Manager shows background results when reopened or resumed.
- The connection pill reflects connectivity changes.
- README-ready notes describe scheduling delays and the force-stop limitation.

## Verification

- Tests for the scheduling decision logic (when to enqueue, which policy) with a fake scheduler.
- Test that the callback's dependency setup runs the engine against a test database.
- Device (record each): airplane mode capture → background → network back; app swiped away (not
  force-stopped); process recreation; repeated triggers. Use `adb shell dumpsys jobscheduler` or
  WorkManager diagnostics to observe scheduling when useful.

## Decisions for the plan

- Work names, existing-work policy, backoff policy, and periodic interval.
- Whether a connectivity regain in the foreground also triggers an immediate run.
- Exactly when the pill switches to "uploads failing" and back (for example the last attempt's
  result).

## References

Design frames `U1-U3`, implementation reference (Persistence and sync: scheduling, claims),
verification reference
(Sync), product reference (resilient sync). Docs: `workmanager` package; Android WorkManager
constraints and backoff; `connectivity_plus`.
