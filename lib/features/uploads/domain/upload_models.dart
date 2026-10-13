import 'package:equatable/equatable.dart';

/// Attempts before a transient failure becomes final (approved 2026-10-12).
const maxUploadAttempts = 5;

/// Stored error of an item whose image is no longer on the device.
const localFileMissingError = 'Local file missing';

/// An open batch collects captures; submitting freezes it as queued (plan U1).
enum BatchStatus { open, queued }

/// Plan U4. [retrying] is a transient failure with attempts left; [failed] is final.
enum ItemStatus { pending, uploading, retrying, uploaded, failed }

class UploadItem extends Equatable {
  const UploadItem({
    required this.id,
    required this.batchId,
    required this.filePath,
    required this.fileName,
    required this.sizeBytes,
    required this.capturedAt,
    required this.status,
    this.attempts = 0,
    this.lastError,
    this.lastAttemptAt,
    this.uploadedAt,
  });

  /// Stable; the upload's idempotency key.
  final int id;
  final int batchId;
  final String filePath;
  final String fileName;
  final int sizeBytes;
  final DateTime capturedAt;
  final ItemStatus status;
  final int attempts;
  final String? lastError;
  final DateTime? lastAttemptAt;
  final DateTime? uploadedAt;

  bool get fileMissing =>
      status == ItemStatus.failed && lastError == localFileMissingError;

  @override
  List<Object?> get props => [
    id,
    batchId,
    filePath,
    fileName,
    sizeBytes,
    capturedAt,
    status,
    attempts,
    lastError,
    lastAttemptAt,
    uploadedAt,
  ];
}

/// The batch the camera is filling.
class OpenBatch extends Equatable {
  const OpenBatch({this.count = 0, this.lastFilePath});

  final int count;

  /// The newest capture, for the camera's thumbnail.
  final String? lastFilePath;

  @override
  List<Object?> get props => [count, lastFilePath];
}

/// A submitted batch and its items, oldest capture first.
class QueuedBatch extends Equatable {
  const QueuedBatch({
    required this.id,
    required this.submittedAt,
    required this.items,
  });

  final int id;
  final DateTime submittedAt;
  final List<UploadItem> items;

  int get uploadedCount =>
      items.where((item) => item.status == ItemStatus.uploaded).length;

  @override
  List<Object?> get props => [id, submittedAt, items];
}
