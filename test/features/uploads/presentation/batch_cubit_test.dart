import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapendance/features/camera/data/camera_service.dart';
import 'package:snapendance/features/uploads/data/upload_queue_repository.dart';
import 'package:snapendance/features/uploads/domain/upload_models.dart';
import 'package:snapendance/features/uploads/presentation/batch_cubit.dart';
import 'package:snapendance/features/uploads/presentation/batch_state.dart';

class MockUploadQueueRepository extends Mock implements UploadQueueRepository {}

void main() {
  late MockUploadQueueRepository repository;
  late StreamController<void> changes;
  late OpenBatch open;
  late int pending;

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
    changes = StreamController<void>.broadcast();
    open = const OpenBatch();
    pending = 0;
    when(() => repository.changes).thenAnswer((_) => changes.stream);
    when(() => repository.openBatch()).thenAnswer((_) async => open);
    when(() => repository.pendingCount()).thenAnswer((_) async => pending);
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
    'load shows the stored open batch and pending count',
    setUp: () {
      open = const OpenBatch(count: 3, lastFilePath: '/c.jpg');
      pending = 4;
    },
    build: () => BatchCubit(repository),
    act: (cubit) => cubit.load(),
    expect: () => [
      const BatchState(openCount: 3, lastFilePath: '/c.jpg', pendingCount: 4),
    ],
  );

  blocTest<BatchCubit, BatchState>(
    'a capture shows saving, then the stored count and thumbnail',
    build: () => BatchCubit(repository),
    act: (cubit) => cubit.capture(() async => '/tmp/a.jpg'),
    expect: () => [
      const BatchState(saving: true),
      const BatchState(openCount: 1, lastFilePath: '/stored/tmp/a.jpg'),
    ],
  );

  blocTest<BatchCubit, BatchState>(
    'a shutter tap during a capture is ignored',
    build: () => BatchCubit(repository),
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
    build: () => BatchCubit(repository),
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
    build: () => BatchCubit(repository),
    act: (cubit) => cubit.capture(() async => '/tmp/a.jpg'),
    expect: () => [
      const BatchState(saving: true),
      const BatchState(notice: BatchNotice(BatchNoticeKind.captureFailed, 1)),
    ],
  );

  blocTest<BatchCubit, BatchState>(
    'submitting queues the batch and announces its size',
    setUp: () => open = const OpenBatch(count: 2, lastFilePath: '/b.jpg'),
    build: () => BatchCubit(repository),
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
    'an empty batch is not submitted',
    build: () => BatchCubit(repository),
    act: (cubit) => cubit.submit(),
    expect: () => <BatchState>[],
    verify: (_) => verifyNever(() => repository.submitOpenBatch()),
  );

  blocTest<BatchCubit, BatchState>(
    'repeated submit taps submit once',
    setUp: () => open = const OpenBatch(count: 2, lastFilePath: '/b.jpg'),
    build: () => BatchCubit(repository),
    seed: () => const BatchState(openCount: 2, lastFilePath: '/b.jpg'),
    act: (cubit) => Future.wait([cubit.submit(), cubit.submit()]),
    verify: (_) => verify(() => repository.submitOpenBatch()).called(1),
  );

  blocTest<BatchCubit, BatchState>(
    'a write elsewhere reloads the counts',
    build: () => BatchCubit(repository),
    act: (cubit) async {
      await cubit.load();
      pending = 5;
      changes.add(null);
      await pumpEventQueue();
    },
    expect: () => [const BatchState(), const BatchState(pendingCount: 5)],
  );
}
