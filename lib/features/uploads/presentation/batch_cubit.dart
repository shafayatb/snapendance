import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../camera/data/camera_service.dart';
import '../data/upload_queue_repository.dart';
import '../domain/upload_models.dart';
import 'batch_state.dart';

/// The open batch the camera fills, and the pending-upload count (plan U9).
///
/// Provided app-wide, so Home and the camera show the same stored counts. The shutter passes the
/// camera's `takePicture`, so this Cubit and `CameraCubit` do not hold each other.
class BatchCubit extends Cubit<BatchState> {
  BatchCubit(this._repository) : super(const BatchState()) {
    _changes = _repository.changes.listen((_) => load());
  }

  final UploadQueueRepository _repository;
  late final StreamSubscription<void> _changes;
  int _noticeSerial = 0;
  bool _submitting = false;

  /// Reads the counts again from storage.
  Future<void> load() async {
    final stored = await _read();
    if (!isClosed) emit(_withStored(stored));
  }

  /// Takes a photo and stores it in the open batch. Ignored while one is being saved.
  Future<void> capture(Future<String> Function() takePicture) async {
    if (state.saving) return;
    emit(state.copyWith(saving: true));
    try {
      await _repository.addCapture(await takePicture());
    } on CameraCaptureException {
      return _captureFailed();
    } on CaptureSaveException {
      return _captureFailed();
    }
    final stored = await _read();
    if (!isClosed) emit(_withStored(stored).copyWith(saving: false));
  }

  void _captureFailed() {
    if (isClosed) return;
    emit(
      state.copyWith(
        saving: false,
        notice: BatchNotice(BatchNoticeKind.captureFailed, ++_noticeSerial),
      ),
    );
  }

  Future<(OpenBatch, int)> _read() async =>
      (await _repository.openBatch(), await _repository.pendingCount());

  BatchState _withStored((OpenBatch, int) stored) {
    final (open, pending) = stored;
    return state.copyWith(
      openCount: open.count,
      lastFilePath: () => open.lastFilePath,
      pendingCount: pending,
    );
  }

  /// Queues the open batch. Ignored when it is empty, while saving, or while a submit runs.
  Future<void> submit() async {
    if (_submitting || state.saving || state.openCount == 0) return;
    _submitting = true;
    try {
      final count = await _repository.submitOpenBatch();
      final stored = await _read();
      if (isClosed) return;
      emit(
        _withStored(stored).copyWith(
          notice: count == 0
              ? null
              : BatchNotice(
                  BatchNoticeKind.batchQueued,
                  ++_noticeSerial,
                  count: count,
                ),
        ),
      );
    } finally {
      _submitting = false;
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
