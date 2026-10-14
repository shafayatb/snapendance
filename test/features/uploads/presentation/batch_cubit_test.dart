import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapendance/features/camera/data/camera_service.dart';
import 'package:snapendance/features/uploads/data/upload_queue_repository.dart';
import 'package:snapendance/features/uploads/data/upload_scheduler.dart';
import 'package:snapendance/features/uploads/domain/upload_models.dart';
import 'package:snapendance/features/uploads/presentation/batch_cubit.dart';
import 'package:snapendance/features/uploads/presentation/batch_state.dart';

class MockUploadQueueRepository extends Mock implements UploadQueueRepository {}

class MockUploadScheduler extends Mock implements UploadScheduler {}

void main() {
  late MockUploadQueueRepository repository;
  late MockUploadScheduler scheduler;
  late bool unfinished;
  late StreamController<void> changes;
  late OpenBatch open;
  late int pending;
  late MockScenario scenario;

  setUpAll(() => registerFallbackValue(MockScenario.success));

  UploadItem stored(String path) => UploadItem(
    id: 1,
    batchId: 1,
    filePath: path,
    fileName: 'IMG.jpg',
    sizeBytes: 3,
    capturedAt: DateTime(2026, 10, 14),
    status: ItemStatus.pending,
  );

  setUp(() {
    repository = MockUploadQueueRepository();
    scheduler = MockUploadScheduler();
    unfinished = false;
    when(() => scheduler.scheduleUploads()).thenAnswer((_) async {});
    when(
      () => repository.hasUnfinishedWork(),
    ).thenAnswer((_) async => unfinished);
    changes = StreamController<void>.broadcast();
    open = const OpenBatch();
    pending = 0;
    scenario = MockScenario.success;
    when(() => repository.changes).thenAnswer((_) => changes.stream);
    when(() => repository.openBatch()).thenAnswer((_) async => open);
    when(() => repository.pendingCount()).thenAnswer((_) async => pending);
    when(() => repository.mockScenario()).thenAnswer((_) async => scenario);
    when(() => repository.setMockScenario(any())).thenAnswer((
      invocation,
    ) async {
      scenario = invocation.positionalArguments.single as MockScenario;
    });
    when(() => repository.addCapture(any())).thenAnswer((invocation) async {
      final path = invocation.positionalArguments.single as String;
      open = OpenBatch(count: open.count + 1, lastFilePath: '/stored$path');
      return stored('/stored$path');
    });
    when(() => repository.submitOpenBatch()).thenAnswer((_) async {
      final count = open.count;
      pending += count;
      open = const OpenBatch();
      return count;
    });
  });

  tearDown(() => changes.close());

  blocTest<BatchCubit, BatchState>(
    'load shows the stored open batch, pending count, and mock scenario',
    setUp: () {
      open = const OpenBatch(count: 3, lastFilePath: '/c.jpg');
      pending = 4;
      scenario = MockScenario.failOnce;
    },
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) => cubit.load(),
    expect: () => [
      const BatchState(
        openCount: 3,
        lastFilePath: '/c.jpg',
        pendingCount: 4,
        scenario: MockScenario.failOnce,
      ),
    ],
  );

  blocTest<BatchCubit, BatchState>(
    'a capture shows saving, then the stored count and thumbnail',
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) => cubit.capture(() async => '/tmp/a.jpg'),
    expect: () => [
      const BatchState(saving: true),
      const BatchState(openCount: 1, lastFilePath: '/stored/tmp/a.jpg'),
    ],
  );

  blocTest<BatchCubit, BatchState>(
    'a shutter tap during a capture is ignored',
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) async {
      final picture = Completer<String>();
      var taken = 0;
      Future<String> takePicture() {
        taken++;
        return picture.future;
      }

      final first = cubit.capture(takePicture);
      await cubit.capture(takePicture);
      picture.complete('/tmp/a.jpg');
      await first;
      expect(taken, 1);
    },
    expect: () => [
      const BatchState(saving: true),
      const BatchState(openCount: 1, lastFilePath: '/stored/tmp/a.jpg'),
    ],
  );

  blocTest<BatchCubit, BatchState>(
    'a failed picture is reported and nothing is stored',
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) =>
        cubit.capture(() => Future.error(const CameraCaptureException('busy'))),
    expect: () => [
      const BatchState(saving: true),
      const BatchState(notice: BatchNotice(BatchNoticeKind.captureFailed, 1)),
    ],
    verify: (_) => verifyNever(() => repository.addCapture(any())),
  );

  blocTest<BatchCubit, BatchState>(
    'a failed save is reported and the count is unchanged',
    setUp: () => when(
      () => repository.addCapture(any()),
    ).thenThrow(const CaptureSaveException('disk full')),
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) => cubit.capture(() async => '/tmp/a.jpg'),
    expect: () => [
      const BatchState(saving: true),
      const BatchState(notice: BatchNotice(BatchNoticeKind.captureFailed, 1)),
    ],
  );

  blocTest<BatchCubit, BatchState>(
    'submitting queues the batch and announces its size',
    setUp: () => open = const OpenBatch(count: 2, lastFilePath: '/b.jpg'),
    build: () => BatchCubit(repository, scheduler),
    seed: () => const BatchState(openCount: 2, lastFilePath: '/b.jpg'),
    act: (cubit) => cubit.submit(),
    expect: () => [
      const BatchState(
        pendingCount: 2,
        notice: BatchNotice(BatchNoticeKind.batchQueued, 1, count: 2),
      ),
    ],
  );

  blocTest<BatchCubit, BatchState>(
    'an empty batch is not submitted; the user is told how to start one',
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) => cubit.submit(),
    expect: () => [
      const BatchState(notice: BatchNotice(BatchNoticeKind.emptyBatch, 1)),
    ],
    verify: (_) => verifyNever(() => repository.submitOpenBatch()),
  );

  blocTest<BatchCubit, BatchState>(
    'repeated submit taps submit once',
    setUp: () => open = const OpenBatch(count: 2, lastFilePath: '/b.jpg'),
    build: () => BatchCubit(repository, scheduler),
    seed: () => const BatchState(openCount: 2, lastFilePath: '/b.jpg'),
    act: (cubit) => Future.wait([cubit.submit(), cubit.submit()]),
    verify: (_) => verify(() => repository.submitOpenBatch()).called(1),
  );

  blocTest<BatchCubit, BatchState>(
    'a write elsewhere reloads the counts',
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) async {
      await cubit.load();
      pending = 5;
      changes.add(null);
      await pumpEventQueue();
    },
    expect: () => [const BatchState(), const BatchState(pendingCount: 5)],
  );

  blocTest<BatchCubit, BatchState>(
    'choosing a mock scenario stores it',
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) => cubit.setScenario(MockScenario.timeout),
    expect: () => [const BatchState(scenario: MockScenario.timeout)],
    verify: (_) => expect(scenario, MockScenario.timeout),
  );

  blocTest<BatchCubit, BatchState>(
    'submitting a batch schedules the upload work',
    setUp: () => open = const OpenBatch(count: 1, lastFilePath: '/a.jpg'),
    build: () => BatchCubit(repository, scheduler),
    seed: () => const BatchState(openCount: 1, lastFilePath: '/a.jpg'),
    act: (cubit) => cubit.submit(),
    verify: (_) => verify(() => scheduler.scheduleUploads()).called(1),
  );

  blocTest<BatchCubit, BatchState>(
    'an empty submit schedules nothing',
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) => cubit.submit(),
    verify: (_) => verifyNever(() => scheduler.scheduleUploads()),
  );

  blocTest<BatchCubit, BatchState>(
    'starting or resuming the app schedules unfinished uploads',
    setUp: () => unfinished = true,
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) => cubit.appResumed(),
    verify: (_) => verify(() => scheduler.scheduleUploads()).called(1),
  );

  blocTest<BatchCubit, BatchState>(
    'with nothing unfinished, resuming schedules nothing',
    build: () => BatchCubit(repository, scheduler),
    act: (cubit) => cubit.appResumed(),
    verify: (_) => verifyNever(() => scheduler.scheduleUploads()),
  );

  blocTest<BatchCubit, BatchState>(
    'counts written by the background worker show up without a tap',
    build: () => BatchCubit(
      repository,
      scheduler,
      pollInterval: const Duration(milliseconds: 10),
    ),
    act: (cubit) async {
      await cubit.load();
      // The worker's isolate writes without announcing it here.
      pending = 7;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    },
    expect: () => [const BatchState(), const BatchState(pendingCount: 7)],
  );

  group('storage errors', () {
    blocTest<BatchCubit, BatchState>(
      'a failed read after a saved photo still frees the shutter',
      setUp: () => when(() => repository.openBatch()).thenAnswer(
        (_) async =>
            open.count > 0 ? throw Exception('database is locked') : open,
      ),
      build: () => BatchCubit(repository, scheduler),
      act: (cubit) => cubit.capture(() async => '/tmp/a.jpg'),
      expect: () => [const BatchState(saving: true), const BatchState()],
    );

    blocTest<BatchCubit, BatchState>(
      'an unexpected storage error while saving is reported',
      setUp: () => when(
        () => repository.addCapture(any()),
      ).thenThrow(Exception('database is locked')),
      build: () => BatchCubit(repository, scheduler),
      act: (cubit) => cubit.capture(() async => '/tmp/a.jpg'),
      expect: () => [
        const BatchState(saving: true),
        const BatchState(notice: BatchNotice(BatchNoticeKind.captureFailed, 1)),
      ],
    );

    blocTest<BatchCubit, BatchState>(
      'any error from the camera frees the shutter',
      build: () => BatchCubit(repository, scheduler),
      act: (cubit) => cubit.capture(
        () => Future.error(StateError('Controller was disposed')),
      ),
      expect: () => [
        const BatchState(saving: true),
        const BatchState(notice: BatchNotice(BatchNoticeKind.captureFailed, 1)),
      ],
    );

    blocTest<BatchCubit, BatchState>(
      'a queued batch is announced even when scheduling and the read fail',
      setUp: () {
        open = const OpenBatch(count: 2, lastFilePath: '/b.jpg');
        when(
          () => scheduler.scheduleUploads(),
        ).thenThrow(StateError('WorkManager is not initialized'));
        when(() => repository.pendingCount()).thenAnswer(
          (_) async =>
              pending > 0 ? throw Exception('database is locked') : pending,
        );
      },
      build: () => BatchCubit(repository, scheduler),
      seed: () => const BatchState(openCount: 2, lastFilePath: '/b.jpg'),
      act: (cubit) => cubit.submit(),
      expect: () => [
        const BatchState(
          openCount: 2,
          lastFilePath: '/b.jpg',
          notice: BatchNotice(BatchNoticeKind.batchQueued, 1, count: 2),
        ),
      ],
    );

    blocTest<BatchCubit, BatchState>(
      'a failed submit is reported and can be tried again',
      setUp: () => when(
        () => repository.submitOpenBatch(),
      ).thenThrow(Exception('database is locked')),
      build: () => BatchCubit(repository, scheduler),
      seed: () => const BatchState(openCount: 2),
      act: (cubit) async {
        await cubit.submit();
        await cubit.submit();
      },
      expect: () => [
        const BatchState(
          openCount: 2,
          notice: BatchNotice(BatchNoticeKind.submitFailed, 1),
        ),
        const BatchState(
          openCount: 2,
          notice: BatchNotice(BatchNoticeKind.submitFailed, 2),
        ),
      ],
    );

    blocTest<BatchCubit, BatchState>(
      'a failed load keeps the counts shown',
      setUp: () => when(
        () => repository.pendingCount(),
      ).thenThrow(Exception('database is locked')),
      build: () => BatchCubit(repository, scheduler),
      seed: () => const BatchState(pendingCount: 4),
      act: (cubit) => expectLater(cubit.load(), completes),
      expect: () => <BatchState>[],
    );

    blocTest<BatchCubit, BatchState>(
      'a failed schedule on resume does not escape',
      setUp: () {
        unfinished = true;
        when(
          () => scheduler.scheduleUploads(),
        ).thenThrow(StateError('WorkManager is not initialized'));
      },
      build: () => BatchCubit(repository, scheduler),
      act: (cubit) => expectLater(cubit.appResumed(), completes),
    );
  });
}
