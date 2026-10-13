import 'package:equatable/equatable.dart';

import '../domain/upload_models.dart';

/// The Upload Manager (U1-U5): submitted batches that still have unfinished items.
class UploadsState extends Equatable {
  const UploadsState({this.loaded = false, this.batches = const []});

  final bool loaded;

  /// Newest first; a batch leaves the list once every item is uploaded.
  final List<QueuedBatch> batches;

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
  List<Object> get props => [loaded, batches];
}
