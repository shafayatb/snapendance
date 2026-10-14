import 'package:equatable/equatable.dart';

import '../domain/upload_models.dart';

enum ConnectionLink { stable, offline, failing }

class UploadsState extends Equatable {
  const UploadsState({
    this.loaded = false,
    this.batches = const [],
    this.link = ConnectionLink.stable,
    this.failedActions = 0,
  });

  final bool loaded;

  final List<QueuedBatch> batches;
  final ConnectionLink link;

  final int failedActions;

  Iterable<UploadItem> get _items => batches.expand((batch) => batch.items);

  int get total => _items.length;

  int get uploaded =>
      _items.where((item) => item.status == ItemStatus.uploaded).length;

  int get pending => total - uploaded;

  bool has(ItemStatus status) => _items.any((item) => item.status == status);

  int count(ItemStatus status) =>
      _items.where((item) => item.status == status).length;

  @override
  List<Object> get props => [loaded, batches, link, failedActions];
}
