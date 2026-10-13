import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapendance/features/uploads/data/capture_files.dart';
import 'package:snapendance/features/uploads/data/sync_engine.dart';
import 'package:snapendance/features/uploads/data/upload_api.dart';
import 'package:snapendance/features/uploads/data/upload_database.dart';
import 'package:snapendance/features/uploads/data/upload_queue_repository.dart';
import 'package:snapendance/features/uploads/domain/upload_models.dart';
import 'package:snapendance/features/uploads/presentation/uploads_cubit.dart';
import 'package:snapendance/features/uploads/presentation/uploads_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class RejectingApi implements UploadApi {
  @override
  Future<void> upload(UploadItem item) async =>
      throw const UploadFailure('Rejected', permanent: true);
}

class AcceptingApi implements UploadApi {
  @override
  Future<void> upload(UploadItem item) async {}
}

void main() {
  late Directory temp;
  late Database db;
  late UploadQueueRepository repository;
  late List<UploadItem> first;
  late List<UploadItem> second;

  setUpAll(sqfliteFfiInit);

  var shot = 0;
  Future<List<UploadItem>> queueBatch(int count) async {
    final items = <UploadItem>[];
    for (var i = 0; i < count; i++) {
      final file = File(p.join(temp.path, 'plugin', 'CAP${shot++}.jpg'))
        ..createSync(recursive: true)
        ..writeAsStringSync('jpeg');
      items.add(await repository.addCapture(file.path));
    }
    await repository.submitOpenBatch();
    return items;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('uploads_cubit_test');
    db = await openUploadDatabase(
      factory: databaseFactoryFfi,
      path: p.join(temp.path, 'uploads.db'),
    );
    repository = UploadQueueRepository(
      db,
      CaptureFiles(Directory(p.join(temp.path, 'captures'))),
    );
    first = await queueBatch(2);
    second = await queueBatch(1);
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  blocTest<UploadsCubit, UploadsState>(
    'loads the queued batches from the database, newest first',
    build: () => UploadsCubit(repository),
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.batches.map((b) => b.items.length), [1, 2]);
      expect(cubit.state.total, 3);
      expect(cubit.state.uploaded, 0);
      expect(cubit.state.pending, 3);
    },
  );

  blocTest<UploadsCubit, UploadsState>(
    'shows a sync run made elsewhere; finished batches leave the list',
    build: () => UploadsCubit(repository),
    act: (cubit) async {
      await cubit.load();
      // A run outside the screen, as the background worker makes it.
      await SyncEngine(repository, AcceptingApi()).run();
      await cubit.load();
    },
    verify: (cubit) {
      expect(cubit.state.batches, isEmpty);
      expect(cubit.state.pending, 0);
    },
  );

  blocTest<UploadsCubit, UploadsState>(
    'retry puts a failed item back in the queue',
    build: () => UploadsCubit(repository),
    act: (cubit) async {
      await SyncEngine(repository, RejectingApi()).run();
      await cubit.load();
      expect(cubit.state.batches.last.items.first.status, ItemStatus.failed);
      await cubit.retry(first.first.id);
    },
    verify: (cubit) {
      final item = cubit.state.batches.last.items.first;
      expect(item.status, ItemStatus.pending);
      expect(item.attempts, 0);
    },
  );

  blocTest<UploadsCubit, UploadsState>(
    'remove drops a missing-file item',
    build: () => UploadsCubit(repository),
    act: (cubit) async {
      File(second.single.filePath).deleteSync();
      await repository.reconcile();
      await cubit.load();
      expect(cubit.state.batches.first.items.single.fileMissing, isTrue);
      await cubit.remove(second.single.id);
    },
    verify: (cubit) {
      expect(cubit.state.batches.map((b) => b.id), [first.first.batchId]);
      expect(cubit.state.total, 2);
    },
  );

  blocTest<UploadsCubit, UploadsState>(
    'resuming the app reloads',
    build: () => UploadsCubit(repository),
    act: (cubit) async {
      await cubit.load();
      await SyncEngine(repository, AcceptingApi()).run();
      await cubit.appResumed();
    },
    verify: (cubit) => expect(cubit.state.pending, 0),
  );
}
