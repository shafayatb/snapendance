import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'capture_files.dart';
import 'sync_engine.dart';
import 'upload_api.dart';
import 'upload_database.dart';
import 'upload_queue_repository.dart';

abstract interface class UploadScheduler {
  Future<void> scheduleUploads();
}

class WorkmanagerUploadScheduler implements UploadScheduler {
  const WorkmanagerUploadScheduler();

  static const _uniqueWork = 'upload-queue';
  static const _periodicWork = 'upload-queue-periodic';
  static const _task = 'uploadQueue';
  static final _constraints = Constraints(networkType: NetworkType.connected);

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

Future<bool> runUploadTask(
  Future<UploadQueueRepository> Function() openRepository,
) async {
  final UploadQueueRepository repository;
  try {
    repository = await openRepository();
  } on Object catch (error) {
    debugPrint('Opening upload storage failed, will retry: $error');
    return false;
  }
  return runUploadWork(repository);
}

@pragma('vm:entry-point')
void uploadCallbackDispatcher() {
  Workmanager().executeTask(
    (task, inputData) => runUploadTask(
      () async => UploadQueueRepository(
        await openUploadDatabase(),
        await CaptureFiles.appDocuments(),
      ),
    ),
  );
}
