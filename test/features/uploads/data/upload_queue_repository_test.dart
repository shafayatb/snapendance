import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapendance/features/uploads/data/capture_files.dart';
import 'package:snapendance/features/uploads/data/upload_database.dart';
import 'package:snapendance/features/uploads/data/upload_queue_repository.dart';
import 'package:snapendance/features/uploads/domain/upload_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FailingCaptureFiles extends CaptureFiles {
  FailingCaptureFiles(super.directory);

  @override
  Future<File> save(String temporaryPath, DateTime capturedAt) =>
      Future.error(const FileSystemException('No space left on device'));
}

void main() {
  late Directory temp;
  late Directory captures;
  late String databasePath;
  late Database db;
  late UploadQueueRepository repository;
  var now = DateTime(2026, 10, 14, 9, 12, 4);

  setUpAll(sqfliteFfiInit);

  Future<UploadQueueRepository> openRepository({CaptureFiles? files}) async {
    db = await openUploadDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    return UploadQueueRepository(
      db,
      files ?? CaptureFiles(captures),
      clock: () => now,
    );
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('uploads_test');
    captures = Directory(p.join(temp.path, 'captures'));
    databasePath = p.join(temp.path, 'uploads.db');
    now = DateTime(2026, 10, 14, 9, 12, 4);
    repository = await openRepository();
  });

  tearDown(() async {
    if (db.isOpen) await db.close();
    await temp.delete(recursive: true);
  });

  var shot = 0;

  Future<String> pluginPhoto([String content = 'jpeg bytes']) async {
    final file = File(p.join(temp.path, 'plugin', 'CAP${shot++}.jpg'));
    await file.create(recursive: true);
    await file.writeAsString(content);
    return file.path;
  }

  List<String> storedFiles() => captures.existsSync()
      ? captures.listSync().map((entry) => entry.path).toList()
      : const [];

  test(
    'a capture is copied into app storage and counted in the open batch',
    () async {
      final photo = await pluginPhoto('first photo');

      final item = await repository.addCapture(photo);

      expect(
        File(photo).existsSync(),
        isFalse,
        reason: 'temporary file removed',
      );
      expect(p.dirname(item.filePath), captures.path);
      expect(item.fileName, 'IMG_20261014_091204_000.jpg');
      expect(File(item.filePath).readAsStringSync(), 'first photo');
      expect(item.sizeBytes, 'first photo'.length);
      expect(item.status, ItemStatus.pending);

      final open = await repository.openBatch();
      expect(open.count, 1);
      expect(open.lastFilePath, item.filePath);
    },
  );

  test(
    'submitting freezes the open batch; the next capture starts a new one',
    () async {
      await repository.addCapture(await pluginPhoto());
      now = now.add(const Duration(seconds: 7));
      await repository.addCapture(await pluginPhoto());

      expect(await repository.submitOpenBatch(), 2);
      expect((await repository.openBatch()).count, 0);

      now = now.add(const Duration(minutes: 1));
      await repository.addCapture(await pluginPhoto());

      final queued = await repository.queuedBatches();
      expect(queued, hasLength(1));
      expect(queued.single.items, hasLength(2));
      expect((await repository.openBatch()).count, 1);
      expect(
        await repository.pendingCount(),
        2,
        reason: 'open batch not counted',
      );
    },
  );

  test('an empty batch cannot be submitted', () async {
    expect(await repository.submitOpenBatch(), 0);
    expect(await repository.queuedBatches(), isEmpty);
  });

  test('repeated submit taps queue one batch', () async {
    await repository.addCapture(await pluginPhoto());

    final results = await Future.wait([
      repository.submitOpenBatch(),
      repository.submitOpenBatch(),
    ]);

    expect(results..sort(), [0, 1]);
    expect(await repository.queuedBatches(), hasLength(1));
  });

  test('a failed copy records nothing', () async {
    repository = UploadQueueRepository(
      db,
      FailingCaptureFiles(captures),
      clock: () => now,
    );

    await expectLater(
      repository.addCapture(await pluginPhoto()),
      throwsA(isA<CaptureSaveException>()),
    );
    expect((await repository.openBatch()).count, 0);
  });

  test('a failed database write removes the copied image', () async {
    final photo = await pluginPhoto();
    await db.close();

    await expectLater(
      repository.addCapture(photo),
      throwsA(isA<CaptureSaveException>()),
    );
    expect(storedFiles(), isEmpty);
  });

  test(
    'reconciliation removes orphan files and flags missing images',
    () async {
      final kept = await repository.addCapture(await pluginPhoto());
      final lost = await repository.addCapture(await pluginPhoto());
      await repository.submitOpenBatch();
      final unsent = await repository.addCapture(await pluginPhoto());
      final orphan = File(p.join(captures.path, 'IMG_orphan.jpg'))
        ..writeAsStringSync('no row');
      File(lost.filePath).deleteSync();
      File(unsent.filePath).deleteSync();

      await repository.reconcile();

      expect(orphan.existsSync(), isFalse);
      expect(File(kept.filePath).existsSync(), isTrue);
      final items = (await repository.queuedBatches()).single.items;
      final lostItem = items.singleWhere((item) => item.id == lost.id);
      expect(lostItem.status, ItemStatus.failed);
      expect(lostItem.fileMissing, isTrue);
      expect(
        items.singleWhere((item) => item.id == kept.id).status,
        ItemStatus.pending,
      );
      expect(
        (await repository.openBatch()).count,
        0,
        reason: 'nothing to send',
      );
    },
  );

  test('captures and batches survive reopening the database', () async {
    await repository.addCapture(await pluginPhoto());
    await repository.addCapture(await pluginPhoto());
    await repository.submitOpenBatch();
    await repository.addCapture(await pluginPhoto());
    await db.close();

    repository = await openRepository();

    expect((await repository.openBatch()).count, 1);
    final items = (await repository.queuedBatches()).single.items;
    expect(items, hasLength(2));
    expect(items.every((item) => File(item.filePath).existsSync()), isTrue);
  });

  test('writes are announced on the changes stream', () async {
    final changes = <void>[];
    final subscription = repository.changes.listen(changes.add);

    await repository.addCapture(await pluginPhoto());
    await repository.submitOpenBatch();
    await pumpEventQueue();

    expect(changes, hasLength(2));
    await subscription.cancel();
  });

  test('retry makes a failed item pending again with fresh attempts', () async {
    final item = await repository.addCapture(await pluginPhoto());
    await repository.submitOpenBatch();
    await repository.claimNext(
      token: 't',
      now: now,
      claimFor: const Duration(minutes: 2),
    );
    await repository.recordFailure(
      item.id,
      't',
      now,
      'Rejected',
      permanent: true,
    );

    await repository.retryItem(item.id);

    final retried = (await repository.queuedBatches()).single.items.single;
    expect(retried.status, ItemStatus.pending);
    expect(retried.attempts, 0);
    expect(retried.lastError, isNull);
  });

  test('remove deletes the queue record and any image left', () async {
    final gone = await repository.addCapture(await pluginPhoto());
    final kept = await repository.addCapture(await pluginPhoto());
    await repository.submitOpenBatch();

    await repository.removeItem(gone.id);

    final items = (await repository.queuedBatches()).single.items;
    expect(items.map((item) => item.id), [kept.id]);
    expect(File(gone.filePath).existsSync(), isFalse);
  });
}
