import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/upload_queue_repository.dart';
import '../data/upload_scheduler.dart';
import '../domain/upload_models.dart';
import 'batch_state.dart';

/// The open batch the camera fills, the pending-upload count, and the mock scenario (plan U9).
///
/// Provided app-wide, so Home and the camera show the same stored counts. The shutter passes the
/// camera's `takePicture`, so this Cubit and `CameraCubit` do not hold each other.
class BatchCubit extends Cubit<BatchState> {
  BatchCubit(
    this._repository,
    this._scheduler, {
    Duration pollInterval = const Duration(seconds: 3),
  }) : super(const BatchState()) {
    _changes = _repository.changes.listen((_) => load());
    // The background worker writes from its own isolate, which [changes] does not see; a
    // count query every few seconds keeps the badge and Home honest.
    _poll = Timer.periodic(pollInterval, (_) => load());
  }

  final UploadQueueRepository _repository;
  final UploadScheduler _scheduler;
  late final StreamSubscription<void> _changes;
  late final Timer _poll;
  int _noticeSerial = 0;
  bool _submitting = false;

  /// Reads the counts again from storage. A failed read keeps the counts shown; the next poll
  /// tries again.
  Future<void> load() async {
    try {
      final stored = await _read();
      if (!isClosed) emit(_withStored(stored));
    } on Exception catch (error) {
      debugPrint('Reading the batch counts failed: $error');
    }
  }

  /// App start and resume: refreshes the counts (the worker may have uploaded) and makes sure
  /// unfinished uploads have a scheduled run, in case one was lost.
  Future<void> appResumed() async {
    await load();
    try {
      if (await _repository.hasUnfinishedWork()) await _scheduleUploads();
    } on Exception catch (error) {
      debugPrint('Checking for unfinished uploads failed: $error');
    }
  }

  /// A failed schedule is left to the periodic recovery task and the next resume.
  Future<void> _scheduleUploads() async {
    try {
      await _scheduler.scheduleUploads();
    } on Object catch (error) {
      debugPrint('Scheduling uploads failed: $error');
    }
  }

  /// Takes a photo and stores it in the open batch. Ignored while one is being saved.
  Future<void> capture(Future<String> Function() takePicture) async {
    if (state.saving) return;
    emit(state.copyWith(saving: true));
    try {
      await _repository.addCapture(await takePicture());
    } on Exception {
      // Includes CameraCaptureException, CaptureSaveException, and database errors.
      return _notify(BatchNoticeKind.captureFailed);
    }
    try {
      final stored = await _read();
      if (!isClosed) emit(_withStored(stored).copyWith(saving: false));
    } on Exception catch (error) {
      // The photo is stored; the next poll shows it.
      debugPrint('Reading the batch after a capture failed: $error');
      if (!isClosed) emit(state.copyWith(saving: false));
    }
  }

  void _notify(BatchNoticeKind kind) {
    if (isClosed) return;
    emit(
      state.copyWith(saving: false, notice: BatchNotice(kind, ++_noticeSerial)),
    );
  }

  Future<(OpenBatch, int, MockScenario)> _read() async => (
    await _repository.openBatch(),
    await _repository.pendingCount(),
    await _repository.mockScenario(),
  );

  BatchState _withStored((OpenBatch, int, MockScenario) stored) {
    final (open, pending, scenario) = stored;
    return state.copyWith(
      openCount: open.count,
      lastFilePath: () => open.lastFilePath,
      pendingCount: pending,
      scenario: scenario,
    );
  }

  /// Queues the open batch. An empty batch only explains how to start one (C7); ignored while
  /// saving or while a submit runs.
  Future<void> submit() async {
    if (_submitting || state.saving) return;
    if (state.openCount == 0) {
      emit(
        state.copyWith(
          notice: BatchNotice(BatchNoticeKind.emptyBatch, ++_noticeSerial),
        ),
      );
      return;
    }
    _submitting = true;
    try {
      final int count;
      try {
        count = await _repository.submitOpenBatch();
      } on Exception {
        return _notify(BatchNoticeKind.submitFailed);
      }
      if (count > 0) await _scheduleUploads();
      final queued = count == 0
          ? null
          : BatchNotice(
              BatchNoticeKind.batchQueued,
              ++_noticeSerial,
              count: count,
            );
      try {
        final stored = await _read();
        if (!isClosed) emit(_withStored(stored).copyWith(notice: queued));
      } on Exception catch (error) {
        // The batch is queued; the next poll shows the new counts.
        debugPrint('Reading the batch after a submit failed: $error');
        if (!isClosed && queued != null) emit(state.copyWith(notice: queued));
      }
    } finally {
      _submitting = false;
    }
  }

  /// Stores how the mock server answers the next uploads (C11).
  Future<void> setScenario(MockScenario scenario) async {
    await _repository.setMockScenario(scenario);
    if (!isClosed) emit(state.copyWith(scenario: scenario));
  }

  @override
  Future<void> close() async {
    _poll.cancel();
    await _changes.cancel();
    return super.close();
  }
}
