import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/upload_queue_repository.dart';
import '../domain/upload_models.dart';
import 'uploads_state.dart';

/// The Upload Manager's state, read from the durable queue.
///
/// The background worker writes from another isolate, so while the screen is open the queue is
/// read again every [pollInterval], on resume, and after writes made in this isolate.
class UploadsCubit extends Cubit<UploadsState> {
  UploadsCubit(
    this._repository, {
    this.pollInterval = const Duration(seconds: 2),
  }) : super(const UploadsState());

  final UploadQueueRepository _repository;
  final Duration pollInterval;
  Timer? _poll;
  StreamSubscription<void>? _changes;

  /// Loads now and keeps the list current while the screen is open.
  void start() {
    load();
    _changes = _repository.changes.listen((_) => load());
    _poll = Timer.periodic(pollInterval, (_) => load());
  }

  Future<void> load() async {
    final batches = await _repository.queuedBatches();
    if (isClosed) return;
    emit(
      UploadsState(
        loaded: true,
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
    return super.close();
  }
}
