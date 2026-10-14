import 'dart:io';

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapendance/features/uploads/data/capture_files.dart';
import 'package:snapendance/features/uploads/data/connectivity_service.dart';
import 'package:snapendance/features/uploads/data/sync_engine.dart';
import 'package:snapendance/features/uploads/data/upload_api.dart';
import 'package:snapendance/features/uploads/data/upload_database.dart';
import 'package:snapendance/features/uploads/data/upload_queue_repository.dart';
import 'package:snapendance/features/uploads/data/upload_scheduler.dart';
import 'package:snapendance/features/uploads/domain/upload_models.dart';
import 'package:snapendance/features/uploads/presentation/uploads_cubit.dart';
import 'package:snapendance/features/uploads/presentation/uploads_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class RejectingApi implements UploadApi {
  @override
  Future<void> upload(UploadItem item) async =>
      throw const UploadFailure('Rejected', permanent: true);
}

class CountingScheduler implements UploadScheduler {
  int scheduled = 0;
  Object? failure;

  @override
  Future<void> scheduleUploads() async {
    if (failure case final error?) throw error;
    scheduled++;
  }
}

class FakeConnectivity implements ConnectivityService {
  bool connected = true;
  final changes = StreamController<bool>.broadcast();

  @override
  Future<bool> isConnected() async => connected;

  @override
  Stream<bool> get connectedChanges => changes.stream;

  void set(bool value) {
    connected = value;
    changes.add(value);
  }
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
  late CountingScheduler scheduler;
  late FakeConnectivity connectivity;

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
    scheduler = CountingScheduler();
    connectivity = FakeConnectivity();
    first = await queueBatch(2);
    second = await queueBatch(1);
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  blocTest<UploadsCubit, UploadsState>(
    'loads the queued batches from the database, newest first',
    build: () => UploadsCubit(repository, scheduler, connectivity),
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
    build: () => UploadsCubit(repository, scheduler, connectivity),
    act: (cubit) async {
      await cubit.load();
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
    build: () => UploadsCubit(repository, scheduler, connectivity),
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
      expect(scheduler.scheduled, 1, reason: 'the retry needs a run');
    },
  );

  blocTest<UploadsCubit, UploadsState>(
    'remove drops a missing-file item',
    build: () => UploadsCubit(repository, scheduler, connectivity),
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
    build: () => UploadsCubit(repository, scheduler, connectivity),
    act: (cubit) async {
      await cubit.load();
      await SyncEngine(repository, AcceptingApi()).run();
      await cubit.appResumed();
    },
    verify: (cubit) => expect(cubit.state.pending, 0),
  );

  group('connection pill', () {
    blocTest<UploadsCubit, UploadsState>(
      'follows connectivity; regaining it asks for a run',
      build: () => UploadsCubit(repository, scheduler, connectivity),
      act: (cubit) async {
        cubit.start();
        await pumpEventQueue();
        expect(cubit.state.link, ConnectionLink.stable);
        connectivity.set(false);
        await pumpEventQueue();
        expect(cubit.state.link, ConnectionLink.offline);
        expect(scheduler.scheduled, 0);
        connectivity.set(true);
        await pumpEventQueue();
      },
      verify: (cubit) {
        expect(cubit.state.link, ConnectionLink.stable);
        expect(scheduler.scheduled, 1);
      },
    );

    blocTest<UploadsCubit, UploadsState>(
      'connected but the last attempt failed reads as uploads failing',
      build: () => UploadsCubit(repository, scheduler, connectivity),
      act: (cubit) async {
        await SyncEngine(repository, RejectingApi()).run();
        await cubit.load();
        expect(cubit.state.link, ConnectionLink.failing);
        await cubit.retry(first.first.id);
        await SyncEngine(repository, AcceptingApi()).run();
        await cubit.load();
      },
      verify: (cubit) => expect(cubit.state.link, ConnectionLink.stable),
    );
  });

  group('storage errors', () {
    blocTest<UploadsCubit, UploadsState>(
      'a failed load keeps the list shown',
      build: () => UploadsCubit(repository, scheduler, connectivity),
      act: (cubit) async {
        await cubit.load();
        await db.close();
        await expectLater(cubit.load(), completes);
      },
      verify: (cubit) => expect(cubit.state.total, 3),
    );

    blocTest<UploadsCubit, UploadsState>(
      'a failed retry is reported',
      build: () => UploadsCubit(repository, scheduler, connectivity),
      act: (cubit) async {
        await cubit.load();
        await db.close();
        await cubit.retry(first.first.id);
      },
      verify: (cubit) {
        expect(cubit.state.failedActions, 1);
        expect(cubit.state.total, 3);
      },
    );

    blocTest<UploadsCubit, UploadsState>(
      'a retry whose scheduling fails is still applied, without an error',
      build: () => UploadsCubit(repository, scheduler, connectivity),
      act: (cubit) async {
        await SyncEngine(repository, RejectingApi()).run();
        scheduler.failure = StateError('WorkManager is not initialized');
        await cubit.retry(first.first.id);
      },
      verify: (cubit) {
        expect(cubit.state.failedActions, 0);
        expect(cubit.state.batches.last.items.first.status, ItemStatus.pending);
      },
    );

    blocTest<UploadsCubit, UploadsState>(
      'a failed remove is reported',
      build: () => UploadsCubit(repository, scheduler, connectivity),
      act: (cubit) async {
        await cubit.load();
        await db.close();
        await cubit.remove(second.single.id);
      },
      verify: (cubit) => expect(cubit.state.failedActions, 1),
    );
  });
}
