import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapendance/features/uploads/domain/upload_models.dart';
import 'package:snapendance/features/uploads/presentation/upload_manager_page.dart';
import 'package:snapendance/features/uploads/presentation/uploads_cubit.dart';
import 'package:snapendance/features/uploads/presentation/uploads_state.dart';

class MockUploadsCubit extends MockCubit<UploadsState>
    implements UploadsCubit {}

void main() {
  late MockUploadsCubit cubit;
  final today = DateTime.now();
  var nextId = 1;

  UploadItem item(
    ItemStatus status, {
    int attempts = 0,
    String? lastError,
    DateTime? uploadedAt,
  }) {
    final id = nextId++;
    return UploadItem(
      id: id,
      batchId: 4,
      filePath: '/missing/IMG_$id.jpg',
      fileName: 'IMG_20261014_0912${id.toString().padLeft(2, '0')}.jpg',
      sizeBytes: 3400000,
      capturedAt: today,
      status: status,
      attempts: attempts,
      lastError: lastError,
      uploadedAt: uploadedAt,
    );
  }

  setUp(() {
    cubit = MockUploadsCubit();
    when(() => cubit.retry(any())).thenAnswer((_) async {});
    when(() => cubit.remove(any())).thenAnswer((_) async {});
    when(() => cubit.appResumed()).thenAnswer((_) async {});
  });

  Future<void> show(
    WidgetTester tester,
    List<QueuedBatch> batches, {
    ConnectionLink link = ConnectionLink.stable,
  }) async {
    tester.view
      ..physicalSize = const Size(412, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(
      () => cubit.state,
    ).thenReturn(UploadsState(loaded: true, batches: batches, link: link));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<UploadsCubit>.value(
          value: cubit,
          child: const UploadManagerView(),
        ),
      ),
    );
  }

  QueuedBatch batch(List<UploadItem> items) =>
      QueuedBatch(id: 4, submittedAt: today, items: items);

  testWidgets('each item state shows its label', (tester) async {
    await show(tester, [
      batch([
        item(ItemStatus.pending),
        item(ItemStatus.uploading),
        item(ItemStatus.retrying, attempts: 3, lastError: 'timed out'),
        item(
          ItemStatus.failed,
          attempts: 5,
          lastError: 'Failed after 5 attempts · last: timed out',
        ),
        item(ItemStatus.failed, attempts: 1, lastError: 'Rejected by server'),
        item(ItemStatus.uploaded, uploadedAt: DateTime(2026, 10, 14, 9, 16)),
      ]),
    ]);

    expect(find.text('QUEUED'), findsOneWidget);
    expect(find.text('UPLOADING'), findsOneWidget);
    expect(find.text('RETRYING · ATTEMPT 3/5'), findsOneWidget);
    expect(
      find.text('FAILED AFTER 5 ATTEMPTS · LAST: TIMED OUT'),
      findsOneWidget,
    );
    expect(find.text('FAILED · REJECTED BY SERVER'), findsOneWidget);
    expect(find.text('SYNCED 09:16'), findsOneWidget);
    expect(find.text('Retry'), findsNWidgets(2));
  });

  testWidgets('progress is counted from the items', (tester) async {
    await show(tester, [
      batch([
        item(ItemStatus.uploaded, uploadedAt: today),
        item(ItemStatus.uploaded, uploadedAt: today),
        item(ItemStatus.uploaded, uploadedAt: today),
        item(ItemStatus.pending),
      ]),
    ]);

    expect(
      find.text('3 of 4 uploaded'),
      findsNWidgets(2),
      reason: 'card and batch',
    );
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('PENDING UPLOADS (1)'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Batch 4 · Today'), findRichText: true),
      findsOneWidget,
    );
    expect(find.text('2 more synced in this batch'), findsOneWidget);
  });

  testWidgets('a retry tap retries that item', (tester) async {
    final failed = item(
      ItemStatus.failed,
      attempts: 1,
      lastError: 'Rejected by server',
    );
    await show(tester, [
      batch([failed]),
    ]);

    await tester.tap(find.text('Retry'));
    verify(() => cubit.retry(failed.id)).called(1);
  });

  testWidgets('a missing image shows a placeholder and can be removed', (
    tester,
  ) async {
    final missing = item(ItemStatus.failed, lastError: localFileMissingError);
    await show(tester, [
      batch([missing]),
    ]);

    expect(find.text('FAILED · LOCAL FILE MISSING'), findsOneWidget);
    expect(find.text('— · file not found'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Remove'));
    verify(() => cubit.remove(missing.id)).called(1);
  });

  testWidgets('nothing queued shows the empty state', (tester) async {
    await show(tester, const []);

    expect(find.text('Nothing waiting to upload'), findsOneWidget);
    expect(find.text('START NEW UPLOAD BATCH'), findsOneWidget);
  });

  testWidgets('offline: the pill, waiting items, and a paused note', (
    tester,
  ) async {
    await show(tester, [
      batch([
        item(ItemStatus.pending),
        item(ItemStatus.retrying, attempts: 2),
        item(ItemStatus.uploaded, uploadedAt: today),
      ]),
    ], link: ConnectionLink.offline);

    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('WAITING FOR CONNECTION'), findsNWidgets(2));
    expect(find.text('Paused until online'), findsOneWidget);
  });

  testWidgets('connected with failing uploads says so', (tester) async {
    await show(tester, [
      batch([item(ItemStatus.retrying, attempts: 1)]),
    ], link: ConnectionLink.failing);

    expect(find.text('CONNECTED · UPLOADS FAILING'), findsOneWidget);
    expect(find.text('RETRYING · ATTEMPT 1/5'), findsOneWidget);
  });

  testWidgets('a working connection reads as a stable link', (tester) async {
    await show(tester, const []);

    expect(find.text('STABLE LINK'), findsOneWidget);
  });

  testWidgets('a Retry or Remove that could not be stored is reported', (
    tester,
  ) async {
    final shown = batch([item(ItemStatus.failed, attempts: 5)]);
    whenListen(
      cubit,
      Stream.value(
        UploadsState(loaded: true, batches: [shown], failedActions: 1),
      ),
      initialState: UploadsState(loaded: true, batches: [shown]),
    );
    await show(tester, [shown]);
    await tester.pump();

    expect(find.text('Couldn’t update the upload. Try again.'), findsOneWidget);
  });
}
