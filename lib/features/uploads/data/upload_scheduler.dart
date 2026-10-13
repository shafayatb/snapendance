import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'capture_files.dart';
import 'sync_engine.dart';
import 'upload_api.dart';
import 'upload_database.dart';
import 'upload_queue_repository.dart';

/// Asks Android to run the upload queue (plan U8). A boundary, so Cubits are tested without
/// WorkManager.
abstract interface class UploadScheduler {
  /// Enqueues a network-constrained run. Safe to call often: it never strands a newly queued
  /// batch behind a run that is already going.
  Future<void> scheduleUploads();
}

/// [UploadScheduler] on Android WorkManager through the `workmanager` plugin.
///
/// One unique one-off work, `upload-queue`, with `update` (native APPEND_OR_REPLACE): a request
/// made while a run is going is chained after it, so batches submitted during a run get a later
/// run. A 15-minute periodic task is the recovery path if the one-off work is ever lost.
/// Scheduling is the OS's: runs wait for a network and may be delayed; a force-stopped app runs
/// nothing until it is opened again.
class WorkmanagerUploadScheduler implements UploadScheduler {
  const WorkmanagerUploadScheduler();

  static const _uniqueWork = 'upload-queue';
  static const _periodicWork = 'upload-queue-periodic';
  static const _task = 'uploadQueue';
  static final _constraints = Constraints(networkType: NetworkType.connected);

  /// Registers the worker callback and the periodic recovery task; call once at startup.
  static Future<void> initialize() async {
    await Workmanager().initialize(uploadCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _periodicWork,
      _task,
      frequency: const Duration(minutes: 15),
      constraints: _constraints,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  Future<void> scheduleUploads() => Workmanager().registerOneOffTask(
    _uniqueWork,
    _task,
    constraints: _constraints,
    existingWorkPolicy: ExistingWorkPolicy.update,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(seconds: 30),
  );
}

/// One worker run: uploads with the stored mock scenario. Returns the worker result: true when
/// nothing is left to retry, false to have WorkManager retry with backoff. Never throws, since
/// a thrown error would end the work for good.
Future<bool> runUploadWork(
  UploadQueueRepository repository, {
  Duration? latency,
}) async {
  try {
    final scenario = await repository.mockScenario();
    final api = latency == null
        ? MockUploadApi(scenario)
        : MockUploadApi(scenario, latency: latency);
    final remaining = await SyncEngine(repository, api).run();
    return !remaining;
  } on Object catch (error) {
    debugPrint('Upload work failed, will retry: $error');
    return false;
  }
}

/// WorkManager's entry point. It may run in a fresh background isolate, so it builds its own
/// database, file, and API dependencies; it shares nothing with the UI.
@pragma('vm:entry-point')
void uploadCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Left open: sqflite may share the native connection with the app's own isolate.
    final repository = UploadQueueRepository(
      await openUploadDatabase(),
      await CaptureFiles.appDocuments(),
    );
    return runUploadWork(repository);
  });
}
