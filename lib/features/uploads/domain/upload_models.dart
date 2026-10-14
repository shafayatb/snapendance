import 'package:equatable/equatable.dart';

const maxUploadAttempts = 5;

const localFileMissingError = 'Local file missing';

enum MockScenario { success, failOnce, timeout, noNetwork, permanentFailure }

enum BatchStatus { open, queued }

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

class OpenBatch extends Equatable {
  const OpenBatch({this.count = 0, this.lastFilePath});

  final int count;

  final String? lastFilePath;

  @override
  List<Object?> get props => [count, lastFilePath];
}

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
