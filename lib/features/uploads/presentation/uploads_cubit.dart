import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/connectivity_service.dart';
import '../data/upload_queue_repository.dart';
import '../data/upload_scheduler.dart';
import '../domain/upload_models.dart';
import 'uploads_state.dart';

class UploadsCubit extends Cubit<UploadsState> {
  UploadsCubit(
    this._repository,
    this._scheduler,
    this._connectivity, {
    this.pollInterval = const Duration(seconds: 2),
  }) : super(const UploadsState());

  final UploadQueueRepository _repository;
  final UploadScheduler _scheduler;
  final ConnectivityService _connectivity;
  bool _connected = true;
  StreamSubscription<bool>? _connection;
  final Duration pollInterval;
  Timer? _poll;
  StreamSubscription<void>? _changes;

  Future<void> start() async {
    _changes = _repository.changes.listen((_) => load());
    _poll = Timer.periodic(pollInterval, (_) => load());
    _connection = _connectivity.connectedChanges.listen(_connectionChanged);
    _connected = await _connectivity.isConnected();
    await load();
  }

  Future<void> _connectionChanged(bool connected) async {
    final regained = connected && !_connected;
    _connected = connected;
    if (regained) await _scheduleUploads();
    await load();
  }

  Future<void> _scheduleUploads() async {
    try {
      await _scheduler.scheduleUploads();
    } on Object catch (error) {
      debugPrint('Scheduling uploads failed: $error');
    }
  }

  Future<void> load() async {
    final List<QueuedBatch> batches;
    final bool failing;
    try {
      batches = await _repository.queuedBatches();
      failing = await _repository.lastAttemptFailed();
    } on Exception catch (error) {
      debugPrint('Reading the upload queue failed: $error');
      return;
    }
    if (isClosed) return;
    emit(
      UploadsState(
        loaded: true,
        link: !_connected
            ? ConnectionLink.offline
            : failing
            ? ConnectionLink.failing
            : ConnectionLink.stable,
        failedActions: state.failedActions,
        batches: [
          for (final batch in batches)
            if (batch.items.any((item) => item.status != ItemStatus.uploaded))
              batch,
        ],
      ),
    );
  }

  Future<void> appResumed() => load();

  Future<void> retry(int itemId) => _act(() async {
    await _repository.retryItem(itemId);
    await _scheduleUploads();
  });

  Future<void> remove(int itemId) => _act(() => _repository.removeItem(itemId));

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      debugPrint('Upload action failed: $error');
      if (!isClosed) {
        emit(
          UploadsState(
            loaded: state.loaded,
            batches: state.batches,
            link: state.link,
            failedActions: state.failedActions + 1,
          ),
        );
      }
    }
    await load();
  }

  @override
  Future<void> close() async {
    _poll?.cancel();
    await _changes?.cancel();
    await _connection?.cancel();
    return super.close();
  }
}
