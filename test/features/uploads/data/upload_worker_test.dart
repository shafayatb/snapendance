import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapendance/features/uploads/data/capture_files.dart';
import 'package:snapendance/features/uploads/data/upload_database.dart';
import 'package:snapendance/features/uploads/data/upload_queue_repository.dart';
import 'package:snapendance/features/uploads/data/upload_scheduler.dart';
import 'package:snapendance/features/uploads/domain/upload_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temp;
  late Database db;
  late UploadQueueRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('worker_test');
    db = await openUploadDatabase(
      factory: databaseFactoryFfi,
      path: p.join(temp.path, 'uploads.db'),
    );
    repository = UploadQueueRepository(
      db,
      CaptureFiles(Directory(p.join(temp.path, 'captures'))),
    );
    final photo = File(p.join(temp.path, 'plugin', 'CAP.jpg'))
      ..createSync(recursive: true)
      ..writeAsStringSync('jpeg');
    await repository.addCapture(photo.path);
    await repository.submitOpenBatch();
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<ItemStatus> status() async =>
      (await repository.queuedBatches()).single.items.single.status;

  test(
    'the worker uploads with the stored scenario and reports done',
    () async {
      final done = await runUploadWork(repository, latency: Duration.zero);

      expect(done, isTrue);
      expect(await status(), ItemStatus.uploaded);
    },
  );

  test('a transient failure asks WorkManager to retry later', () async {
    await repository.setMockScenario(MockScenario.failOnce);

    final done = await runUploadWork(repository, latency: Duration.zero);

    expect(done, isFalse);
    expect(await status(), ItemStatus.retrying);
    expect(await runUploadWork(repository, latency: Duration.zero), isTrue);
    expect(await status(), ItemStatus.uploaded);
  });

  test('a failed run is retried rather than reported as final', () async {
    await db.close();

    expect(await runUploadWork(repository, latency: Duration.zero), isFalse);
  });
}
