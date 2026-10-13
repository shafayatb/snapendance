import 'dart:async';

import '../domain/upload_models.dart';

/// The server refused or could not be reached. [offline]: no connection at all, so the rest of
/// a run would fail the same way. [permanent]: retrying cannot help.
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

/// The upload boundary. Completes when the server confirms the item; throws [UploadFailure].
/// May never answer: the caller applies the timeout.
abstract interface class UploadApi {
  Future<void> upload(UploadItem item);
}

/// The employer supplies no API, so uploads are answered by this mock (design C11). Each
/// scenario is repeatable: "fail once" fails an item's first attempt by its stored count, so it
/// behaves the same after a restart or in the background worker.
class MockUploadApi implements UploadApi {
  MockUploadApi(
    this.scenario, {
    this.latency = const Duration(milliseconds: 600),
  });

  final MockScenario scenario;

  /// Simulated round trip, so uploads are visible on screen.
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
        // No reply at all; the engine's 30 s timeout ends the attempt.
        await Completer<void>().future;
      case MockScenario.noNetwork:
        throw const UploadFailure('No network', offline: true);
      case MockScenario.permanentFailure:
        await Future<void>.delayed(latency);
        throw const UploadFailure('Rejected by server (mock)', permanent: true);
    }
  }
}
