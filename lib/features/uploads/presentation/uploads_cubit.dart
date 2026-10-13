import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/connectivity_service.dart';
import '../data/upload_queue_repository.dart';
import '../data/upload_scheduler.dart';
import '../domain/upload_models.dart';
import 'uploads_state.dart';

/// The Upload Manager's state, read from the durable queue.
///
/// The background worker writes from another isolate, so while the screen is open the queue is
/// read again every [pollInterval], on resume, and after writes made in this isolate.
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

  /// Loads now and keeps the list and the connection pill current while the screen is open.
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
    // WorkManager also waits for the network; asking again makes sure a run is queued.
    if (regained) await _scheduler.scheduleUploads();
    await load();
  }

  Future<void> load() async {
    final batches = await _repository.queuedBatches();
    final failing = await _repository.lastAttemptFailed();
    if (isClosed) return;
    emit(
      UploadsState(
        loaded: true,
        link: !_connected
            ? ConnectionLink.offline
            : failing
            ? ConnectionLink.failing
            : ConnectionLink.stable,
        batches: [
          for (final batch in batches)
            if (batch.items.any((item) => item.status != ItemStatus.uploaded))
              batch,
        ],
      ),
    );
  }

  Future<void> appResumed() => load();

  Future<void> retry(int itemId) async {
    await _repository.retryItem(itemId);
    await _scheduler.scheduleUploads();
    await load();
  }

  Future<void> remove(int itemId) async {
    await _repository.removeItem(itemId);
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
