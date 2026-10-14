import 'package:equatable/equatable.dart';

import '../domain/upload_models.dart';

enum BatchNoticeKind { captureFailed, batchQueued, emptyBatch, submitFailed }

/// A one-off message. [serial] makes a repeated notice a new state.
class BatchNotice extends Equatable {
  const BatchNotice(this.kind, this.serial, {this.count = 0});

  final BatchNoticeKind kind;
  final int serial;

  /// Photos queued, for [BatchNoticeKind.batchQueued].
  final int count;

  @override
  List<Object> get props => [kind, serial, count];
}

/// The camera's batch (C1, C6, C7, C10) and the pending-upload count (H2, cloud badge).
class BatchState extends Equatable {
  const BatchState({
    this.openCount = 0,
    this.lastFilePath,
    this.pendingCount = 0,
    this.saving = false,
    this.notice,
    this.scenario = MockScenario.success,
  });

  /// Stored photos in the open batch.
  final int openCount;
  final String? lastFilePath;
  final int pendingCount;

  /// A capture is being taken or stored; the camera controls are disabled.
  final bool saving;
  final BatchNotice? notice;

  /// How the mock server answers (C11 sheet).
  final MockScenario scenario;

  BatchState copyWith({
    int? openCount,
    String? Function()? lastFilePath,
    int? pendingCount,
    bool? saving,
    BatchNotice? notice,
    MockScenario? scenario,
  }) {
    return BatchState(
      openCount: openCount ?? this.openCount,
      lastFilePath: lastFilePath != null ? lastFilePath() : this.lastFilePath,
      pendingCount: pendingCount ?? this.pendingCount,
      saving: saving ?? this.saving,
      notice: notice ?? this.notice,
      scenario: scenario ?? this.scenario,
    );
  }

  @override
  List<Object?> get props => [
    openCount,
    lastFilePath,
    pendingCount,
    saving,
    notice,
    scenario,
  ];
}
