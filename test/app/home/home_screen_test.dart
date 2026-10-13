import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapendance/app/home/home_screen.dart';
import 'package:snapendance/app/native/attendance_launcher.dart';
import 'package:snapendance/features/camera/data/camera_service.dart';
import 'package:snapendance/features/uploads/presentation/batch_cubit.dart';
import 'package:snapendance/features/uploads/presentation/batch_state.dart';

// Written out here rather than imported, so a renamed channel in the app fails
// this test instead of moving with it. Must match MainActivity.kt.
const _navigationChannel = MethodChannel(
  'com.shafayatb.snapendance/navigation',
);

const _launchFailedMessage = "Couldn't open Attendance. Please try again.";

class MockCameraService extends Mock implements CameraService {}

class MockBatchCubit extends MockCubit<BatchState> implements BatchCubit {}

void main() {
  late List<MethodCall> receivedCalls;
  late MockCameraService cameraService;
  late MockBatchCubit batch;

  Widget home() => BlocProvider<BatchCubit>.value(
    value: batch,
    child: MaterialApp(
      home: HomeScreen(
        attendanceLauncher: AttendanceLauncher(),
        cameraService: cameraService,
      ),
    ),
  );

  setUp(() {
    receivedCalls = [];
    cameraService = MockCameraService();
    batch = MockBatchCubit();
    when(() => batch.state).thenReturn(const BatchState());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navigationChannel, (call) async {
          receivedCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(_navigationChannel, null)
      ..setMockMessageHandler(_navigationChannel.name, null);
  });

  testWidgets('tapping the Attendance button asks Android to open attendance', (
    tester,
  ) async {
    await tester.pumpWidget(home());

    final attendanceCard = find.bySemanticsLabel(RegExp('^Attendance'));
    expect(
      tester.getSemantics(attendanceCard),
      isSemantics(isButton: true, hasTapAction: true),
    );

    await tester.tap(attendanceCard);
    await tester.pump();

    expect(receivedCalls, hasLength(1));
    expect(receivedCalls.single.method, 'openAttendance');
    expect(receivedCalls.single.arguments, isNull);
  });

  testWidgets(
    'shows feedback when Android fails to open attendance, and Home can retry',
    (tester) async {
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_navigationChannel, (call) async {
            attempts++;
            throw PlatformException(code: 'ATTENDANCE_UNAVAILABLE');
          });
      await tester.pumpWidget(home());

      final attendanceCard = find.bySemanticsLabel(RegExp('^Attendance'));
      await tester.tap(attendanceCard);
      await tester.pumpAndSettle();

      expect(find.text(_launchFailedMessage), findsOneWidget);

      // Let the first message time out, so the next check sees a new one.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(_launchFailedMessage), findsNothing);

      await tester.tap(attendanceCard);
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text(_launchFailedMessage), findsOneWidget);
    },
  );

  testWidgets('shows feedback when Android has no navigation handler', (
    tester,
  ) async {
    // Android answers a channel with no handler with an empty reply, which
    // Flutter turns into a MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          _navigationChannel.name,
          (message) async => null,
        );
    await tester.pumpWidget(home());

    await tester.tap(find.bySemanticsLabel(RegExp('^Attendance')));
    await tester.pumpAndSettle();

    expect(find.text(_launchFailedMessage), findsOneWidget);
  });

  testWidgets(
    'tapping Camera & Uploads opens the camera, which starts by checking permission',
    (tester) async {
      // The camera stays in its starting state for the whole test.
      when(
        () => cameraService.permission(),
      ).thenAnswer((_) => Completer<CameraPermission>().future);
      await tester.pumpWidget(home());

      final cameraCard = find.bySemanticsLabel(RegExp('^Camera & Uploads'));
      expect(
        tester.getSemantics(cameraCard),
        isSemantics(isButton: true, hasTapAction: true),
      );

      await tester.tap(cameraCard);
      // Past the route transition; the camera's progress spinner never settles.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byTooltip('Close camera'), findsOneWidget);
      verify(() => cameraService.permission()).called(1);

      await tester.tap(find.byTooltip('Close camera'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close camera'), findsNothing);
      expect(cameraCard, findsOneWidget);
    },
  );

  testWidgets('the camera card shows how many images wait to upload (H2)', (
    tester,
  ) async {
    when(() => batch.state).thenReturn(const BatchState(pendingCount: 4));
    await tester.pumpWidget(home());

    expect(find.text('4 images waiting'), findsOneWidget);
    expect(find.text('Capture a batch of photos'), findsNothing);
  });

  testWidgets('with nothing waiting the camera card keeps its subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(home());

    expect(find.text('Capture a batch of photos'), findsOneWidget);
  });
}
