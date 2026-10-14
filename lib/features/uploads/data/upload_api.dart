import 'dart:async';

import '../domain/upload_models.dart';

class UploadFailure implements Exception {
  const UploadFailure(
    this.message, {
    this.permanent = false,
    this.offline = false,
  });

  final String message;
  final bool permanent;
  final bool offline;

  @override
  String toString() => 'UploadFailure: $message';
}

abstract interface class UploadApi {
  Future<void> upload(UploadItem item);
}

class MockUploadApi implements UploadApi {
  MockUploadApi(
    this.scenario, {
    this.latency = const Duration(milliseconds: 600),
  });

  final MockScenario scenario;

  final Duration latency;

  @override
  Future<void> upload(UploadItem item) async {
    switch (scenario) {
      case MockScenario.success:
        await Future<void>.delayed(latency);
      case MockScenario.failOnce:
        await Future<void>.delayed(latency);
        if (item.attempts == 0) {
          throw const UploadFailure('Server error (mock)');
        }
      case MockScenario.timeout:
        await Completer<void>().future;
      case MockScenario.noNetwork:
        throw const UploadFailure('No network', offline: true);
      case MockScenario.permanentFailure:
        await Future<void>.delayed(latency);
        throw const UploadFailure('Rejected by server (mock)', permanent: true);
    }
  }
}
