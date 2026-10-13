import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapendance/features/uploads/data/capture_files.dart';
import 'package:snapendance/features/uploads/data/sync_engine.dart';
import 'package:snapendance/features/uploads/data/upload_api.dart';
import 'package:snapendance/features/uploads/data/upload_database.dart';
import 'package:snapendance/features/uploads/data/upload_queue_repository.dart';
import 'package:snapendance/features/uploads/domain/upload_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Answers each upload from [script] (by item id, then call order); records every call.
class ScriptedUploadApi implements UploadApi {
  ScriptedUploadApi([this.script]);

  final FutureOr<void> Function(UploadItem item, int call)? script;
  final calls = <int>[];

  @override
  Future<void> upload(UploadItem item) async {
    calls.add(item.id);
    await script?.call(item, calls.where((id) => id == item.id).length);
  }
}

void main() {
  late Directory temp;
  late Database db;
  late UploadQueueRepository repository;
  var now = DateTime(2026, 10, 14, 9);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sync_test');
    now = DateTime(2026, 10, 14, 9);
    db = await openUploadDatabase(
      factory: databaseFactoryFfi,
      path: p.join(temp.path, 'uploads.db'),
    );
    repository = UploadQueueRepository(
      db,
      CaptureFiles(Directory(p.join(temp.path, 'captures'))),
      clock: () => now,
    );
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  var shot = 0;

  Future<UploadItem> capture() async {
    final file = File(p.join(temp.path, 'plugin', 'CAP${shot++}.jpg'));
    await file.create(recursive: true);
    await file.writeAsString('jpeg');
    now = now.add(const Duration(milliseconds: 10));
    return repository.addCapture(file.path);
  }

  /// A submitted batch of [count] photos.
  Future<List<UploadItem>> queueBatch(int count) async {
    final items = [for (var i = 0; i < count; i++) await capture()];
    await repository.submitOpenBatch();
    return items;
  }

  SyncEngine engine(
    UploadApi api, {
    Duration timeout = const Duration(seconds: 30),
  }) => SyncEngine(repository, api, clock: () => now, timeout: timeout);

  Future<Map<int, UploadItem>> stored() async => {
    for (final batch in await repository.queuedBatches())
      for (final item in batch.items) item.id: item,
  };

  test('uploads every queued item, leaving the open batch alone', () async {
    final queued = await queueBatch(2);
    final open = await capture();
    final api = ScriptedUploadApi();

    final remaining = await engine(api).run();

    expect(api.calls, [for (final item in queued) item.id]);
    expect(api.calls, isNot(contains(open.id)));
    final items = await stored();
    expect(
      items.values.map((item) => item.status),
      everyElement(ItemStatus.uploaded),
    );
    expect(items.values.first.uploadedAt, isNotNull);
    expect(remaining, isFalse);
  });

  test(
    'a network failure keeps the item and its file, counts the attempt, and stops the run',
    () async {
      final items = await queueBatch(2);
      final api = ScriptedUploadApi(
        (item, call) => throw const UploadFailure('No network', offline: true),
      );

      final remaining = await engine(api).run();

      expect(api.calls, [
        items.first.id,
      ], reason: 'the rest would fail the same way');
      final first = (await stored())[items.first.id]!;
      expect(first.status, ItemStatus.retrying);
      expect(first.attempts, 1);
      expect(first.lastError, 'No network');
      expect(File(first.filePath).existsSync(), isTrue);
      expect((await stored())[items.last.id]!.attempts, 0);
      expect(remaining, isTrue);
    },
  );

  test('an upload with no reply times out and stays queued', () async {
    final items = await queueBatch(1);
    final api = ScriptedUploadApi((item, call) => Completer<void>().future);

    await engine(api, timeout: const Duration(milliseconds: 20)).run();

    final item = (await stored())[items.single.id]!;
    expect(item.status, ItemStatus.retrying);
    expect(item.attempts, 1);
    expect(item.lastError, 'timed out');
  });

  test(
    'a later run retries only unfinished items of a partial batch',
    () async {
      final items = await queueBatch(3);
      final flaky = items[1].id;
      final api = ScriptedUploadApi((item, call) {
        if (item.id == flaky && item.attempts == 0)
          throw const UploadFailure('Server error');
      });

      await engine(api).run();
      expect((await stored())[flaky]!.status, ItemStatus.retrying);
      api.calls.clear();

      final remaining = await engine(api).run();

      expect(api.calls, [flaky], reason: 'uploaded items are never sent again');
      expect(
        (await stored()).values.map((item) => item.status),
        everyElement(ItemStatus.uploaded),
      );
      expect(remaining, isFalse);
    },
  );

  test('a run tries each item at most once', () async {
    await queueBatch(2);
    final api = ScriptedUploadApi(
      (item, call) => throw const UploadFailure('Server error'),
    );

    final remaining = await engine(api).run();

    expect(api.calls, hasLength(2));
    expect(remaining, isTrue);
  });

  test(
    'the fifth transient failure is final and says so; the image is kept',
    () async {
      final items = await queueBatch(1);
      final api = ScriptedUploadApi((item, call) => Completer<void>().future);
      final timingOut = engine(api, timeout: const Duration(milliseconds: 5));

      for (var run = 0; run < maxUploadAttempts; run++) {
        await timingOut.run();
      }
      final remaining = await timingOut.run();

      final item = (await stored())[items.single.id]!;
      expect(item.status, ItemStatus.failed);
      expect(item.attempts, maxUploadAttempts);
      expect(item.lastError, 'Failed after 5 attempts · last: timed out');
      expect(File(item.filePath).existsSync(), isTrue);
      expect(api.calls, hasLength(maxUploadAttempts));
      expect(remaining, isFalse);
    },
  );

  test('a permanent failure is final at once', () async {
    final items = await queueBatch(1);
    final api = ScriptedUploadApi(
      (item, call) =>
          throw const UploadFailure('Rejected by server', permanent: true),
    );

    await engine(api).run();
    await engine(api).run();

    final item = (await stored())[items.single.id]!;
    expect(item.status, ItemStatus.failed);
    expect(item.lastError, 'Rejected by server');
    expect(api.calls, hasLength(1));
  });

  test('two concurrent runs never upload the same item twice', () async {
    await queueBatch(4);
    final api = ScriptedUploadApi(
      (item, call) => Future<void>.delayed(const Duration(milliseconds: 5)),
    );

    await Future.wait([engine(api).run(), engine(api).run()]);

    expect(api.calls, hasLength(4));
    expect(api.calls.toSet(), hasLength(4));
  });

  test(
    'a claim from an interrupted run is taken again once it expires',
    () async {
      final items = await queueBatch(1);
      final interrupted = await repository.claimNext(
        token: 'interrupted run',
        now: now,
        claimFor: SyncEngine.claimDuration,
      );
      expect(interrupted?.id, items.single.id);
      final api = ScriptedUploadApi();

      now = now.add(const Duration(minutes: 1));
      await engine(api).run();
      expect(api.calls, isEmpty, reason: 'the claim still holds');

      now = now.add(SyncEngine.claimDuration);
      await engine(api).run();
      expect(api.calls, [items.single.id]);
      expect((await stored())[items.single.id]!.status, ItemStatus.uploaded);
    },
  );

  test(
    'an item whose image is gone fails as a missing file without uploading',
    () async {
      final items = await queueBatch(1);
      File(items.single.filePath).deleteSync();
      final api = ScriptedUploadApi();

      await engine(api).run();

      expect(api.calls, isEmpty);
      expect((await stored())[items.single.id]!.fileMissing, isTrue);
    },
  );

  test('the mock scenario is stored, so a fresh repository reads it', () async {
    expect(await repository.mockScenario(), MockScenario.success);

    await repository.setMockScenario(MockScenario.timeout);

    final fresh = UploadQueueRepository(db, CaptureFiles(temp));
    expect(await fresh.mockScenario(), MockScenario.timeout);
  });

  group('MockUploadApi', () {
    final item = UploadItem(
      id: 7,
      batchId: 1,
      filePath: '/x.jpg',
      fileName: 'x.jpg',
      sizeBytes: 1,
      capturedAt: DateTime(2026),
      status: ItemStatus.pending,
    );
    UploadItem retried(UploadItem item) => UploadItem(
      id: item.id,
      batchId: item.batchId,
      filePath: item.filePath,
      fileName: item.fileName,
      sizeBytes: item.sizeBytes,
      capturedAt: item.capturedAt,
      status: ItemStatus.retrying,
      attempts: 1,
    );
    MockUploadApi mock(MockScenario scenario) =>
        MockUploadApi(scenario, latency: Duration.zero);

    test('success always succeeds', () async {
      await mock(MockScenario.success).upload(item);
      await mock(MockScenario.success).upload(retried(item));
    });

    test('fail once fails the first attempt and accepts the retry', () async {
      await expectLater(
        mock(MockScenario.failOnce).upload(item),
        throwsA(
          isA<UploadFailure>().having((f) => f.permanent, 'permanent', isFalse),
        ),
      );
      await mock(MockScenario.failOnce).upload(retried(item));
    });

    test('timeout never answers', () async {
      await expectLater(
        mock(
          MockScenario.timeout,
        ).upload(item).timeout(const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('no network fails as offline every time', () async {
      for (final attempt in [item, retried(item)]) {
        await expectLater(
          mock(MockScenario.noNetwork).upload(attempt),
          throwsA(
            isA<UploadFailure>().having((f) => f.offline, 'offline', isTrue),
          ),
        );
      }
    });

    test('permanent failure is rejected as permanent', () async {
      await expectLater(
        mock(MockScenario.permanentFailure).upload(item),
        throwsA(
          isA<UploadFailure>().having((f) => f.permanent, 'permanent', isTrue),
        ),
      );
    });
  });
}
