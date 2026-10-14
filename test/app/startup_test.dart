import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapendance/app/startup.dart';
import 'package:snapendance/features/uploads/data/upload_queue_repository.dart';

class MockUploadQueueRepository extends Mock implements UploadQueueRepository {}

void main() {
  late MockUploadQueueRepository uploadQueue;

  setUp(() {
    uploadQueue = MockUploadQueueRepository();
    when(() => uploadQueue.reconcile()).thenAnswer((_) async {});
  });

  Widget app(UploadQueueRepository queue) => const Text('Home');

  group('startApp', () {
    test('a failed reconcile still starts the app', () async {
      when(
        () => uploadQueue.reconcile(),
      ).thenThrow(const FileSystemException('Storage unavailable'));

      final started = await startApp(
        openUploadQueue: () async => uploadQueue,
        initializeScheduler: () async {},
        buildApp: app,
      );

      expect(started, isA<Text>());
    });

    test('a failed WorkManager setup still starts the app', () async {
      final started = await startApp(
        openUploadQueue: () async => uploadQueue,
        initializeScheduler: () =>
            Future.error(StateError('WorkManager unavailable')),
        buildApp: app,
      );

      expect(started, isA<Text>());
    });
  });

  group('AppStartup', () {
    testWidgets('storage that cannot open offers Try again, which recovers', (
      tester,
    ) async {
      var attempts = 0;
      await tester.pumpWidget(
        AppStartup(
          start: () async {
            if (attempts++ == 0) {
              throw const FileSystemException('Storage unavailable');
            }
            return const MaterialApp(home: Text('Home'));
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Couldn’t start Snapendance'), findsOneWidget);
      expect(find.text('Home'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });
  });
}
