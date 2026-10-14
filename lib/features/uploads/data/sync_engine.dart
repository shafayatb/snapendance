import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../domain/upload_models.dart';
import 'upload_api.dart';
import 'upload_queue_repository.dart';

class SyncEngine {
  SyncEngine(
    this._repository,
    this._api, {
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 30),
  }) : _clock = clock ?? DateTime.now;

  static const claimDuration = Duration(minutes: 2);

  final UploadQueueRepository _repository;
  final UploadApi _api;
  final DateTime Function() _clock;

  final Duration timeout;

  static final _random = Random.secure();

  Future<bool> run() async {
    final token = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final tried = <int>{};
    while (true) {
      final item = await _repository.claimNext(
        token: token,
        now: _clock(),
        claimFor: claimDuration,
        exclude: tried,
      );
      if (item == null) break;
      tried.add(item.id);

      if (!await File(item.filePath).exists()) {
        await _repository.recordFailure(
          item.id,
          token,
          _clock(),
          localFileMissingError,
          permanent: true,
        );
        continue;
      }
      try {
        await _api.upload(item).timeout(timeout);
        await _repository.recordSuccess(item.id, token, _clock());
      } on TimeoutException {
        await _repository.recordFailure(item.id, token, _clock(), 'timed out');
      } on UploadFailure catch (failure) {
        await _repository.recordFailure(
          item.id,
          token,
          _clock(),
          failure.message,
          permanent: failure.permanent,
        );
        if (failure.offline) break;
      }
    }
    return _repository.hasUnfinishedWork();
  }
}
