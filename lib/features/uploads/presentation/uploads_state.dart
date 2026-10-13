import 'package:equatable/equatable.dart';

import '../domain/upload_models.dart';

/// The connection pill (plan U11).
enum ConnectionLink {
  /// Connected, and the last attempt did not fail.
  stable,

  /// No connection; unfinished items wait for one.
  offline,

  /// Connected, but the most recent upload attempt failed.
  failing,
}

/// The Upload Manager (U1-U5): submitted batches that still have unfinished items.
class UploadsState extends Equatable {
  const UploadsState({
    this.loaded = false,
    this.batches = const [],
    this.link = ConnectionLink.stable,
  });

  final bool loaded;

  /// Newest first; a batch leaves the list once every item is uploaded.
  final List<QueuedBatch> batches;
  final ConnectionLink link;

  Iterable<UploadItem> get _items => batches.expand((batch) => batch.items);

  int get total => _items.length;

  int get uploaded =>
      _items.where((item) => item.status == ItemStatus.uploaded).length;

  /// "PENDING UPLOADS (n)": everything not uploaded, failed included.
  int get pending => total - uploaded;

  bool has(ItemStatus status) => _items.any((item) => item.status == status);

  int count(ItemStatus status) =>
      _items.where((item) => item.status == status).length;

  @override
  List<Object> get props => [loaded, batches, link];
}
