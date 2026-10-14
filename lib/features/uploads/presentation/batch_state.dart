import 'package:equatable/equatable.dart';

import '../domain/upload_models.dart';

enum BatchNoticeKind { captureFailed, batchQueued, emptyBatch, submitFailed }

class BatchNotice extends Equatable {
  const BatchNotice(this.kind, this.serial, {this.count = 0});

  final BatchNoticeKind kind;
  final int serial;

  final int count;

  @override
  List<Object> get props => [kind, serial, count];
}

class BatchState extends Equatable {
  const BatchState({
    this.openCount = 0,
    this.lastFilePath,
    this.pendingCount = 0,
    this.saving = false,
    this.notice,
    this.scenario = MockScenario.success,
  });

  final int openCount;
  final String? lastFilePath;
  final int pendingCount;

  final bool saving;
  final BatchNotice? notice;

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
