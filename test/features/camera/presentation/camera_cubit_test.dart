import 'dart:async';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapendance/features/camera/data/camera_service.dart';
import 'package:snapendance/features/camera/presentation/camera_cubit.dart';
import 'package:snapendance/features/camera/presentation/camera_state.dart';

class MockCameraService extends Mock implements CameraService {}

class MockCameraSession extends Mock implements CameraSession {}

void main() {
  late MockCameraService service;
  late MockCameraSession session;
  late Completer<CameraSession> opened;
  late Completer<CameraPermission> permissionAnswer;

  setUpAll(() {
    registerFallbackValue(CameraFlash.off);
    registerFallbackValue(Offset.zero);
  });

  setUp(() {
    service = MockCameraService();
    session = MockCameraSession();
    opened = Completer<CameraSession>();
    permissionAnswer = Completer<CameraPermission>();
    when(
      () => service.permission(),
    ).thenAnswer((_) async => CameraPermission.granted);
    when(
      () => service.requestPermission(),
    ).thenAnswer((_) async => CameraPermission.granted);
    when(() => service.hasFlash()).thenAnswer((_) async => true);
    when(() => service.open()).thenAnswer((_) async => session);
    when(() => session.minZoom).thenReturn(1);
    when(() => session.maxZoom).thenReturn(8);
    when(() => session.focusPointSupported).thenReturn(true);
    when(() => session.previewAspectRatio).thenReturn(3 / 4);
    when(() => session.setZoom(any())).thenAnswer((_) async {});
    when(() => session.setFlash(any())).thenAnswer((_) async {});
    when(() => session.focusAt(any())).thenAnswer((_) async {});
    when(() => session.close()).thenAnswer((_) async {});
  });

  const ready = CameraState(
    status: CameraStatus.ready,
    minZoom: 1,
    maxZoom: 8,
    presets: [1, 2, 5],
    flashAvailable: true,
    focusSupported: true,
  );

  group('start', () {
    blocTest<CameraCubit, CameraState>(
      'opens the camera when permission is granted',
      build: () => CameraCubit(service),
      act: (cubit) => cubit.start(),
      expect: () => [ready],
    );

    blocTest<CameraCubit, CameraState>(
      'asks for permission and shows the denied state when refused',
      setUp: () {
        when(
          () => service.permission(),
        ).thenAnswer((_) async => CameraPermission.denied);
        when(
          () => service.requestPermission(),
        ).thenAnswer((_) async => CameraPermission.denied);
      },
      build: () => CameraCubit(service),
      act: (cubit) => cubit.start(),
      expect: () => [const CameraState(status: CameraStatus.permissionDenied)],
      verify: (_) => verifyNever(() => service.open()),
    );

    blocTest<CameraCubit, CameraState>(
      'a permanent denial points to app settings without asking',
      setUp: () {
        when(
          () => service.permission(),
        ).thenAnswer((_) async => CameraPermission.permanentlyDenied);
      },
      build: () => CameraCubit(service),
      act: (cubit) => cubit.start(),
      expect: () => [
        const CameraState(status: CameraStatus.permissionPermanentlyDenied),
      ],
      verify: (_) => verifyNever(() => service.requestPermission()),
    );

    blocTest<CameraCubit, CameraState>(
      'a camera that fails to open shows the unavailable state',
      setUp: () {
        when(
          () => service.open(),
        ).thenThrow(const CameraUnavailableException('in use'));
      },
      build: () => CameraCubit(service),
      act: (cubit) => cubit.start(),
      expect: () => [const CameraState(status: CameraStatus.unavailable)],
    );

    blocTest<CameraCubit, CameraState>(
      'an ultra-wide minimum is offered as a preset',
      setUp: () => when(() => session.minZoom).thenReturn(0.6),
      build: () => CameraCubit(service),
      act: (cubit) => cubit.start(),
      expect: () => [
        ready.copyWith(minZoom: 0.6, presets: [0.6, 1, 2, 5]),
      ],
    );
  });

  group('lifecycle', () {
    test('a pause whose release finishes after a quick return keeps the '
        'reopened camera', () async {
      final released = Completer<void>();
      final reopened = MockCameraSession();
      when(() => session.close()).thenAnswer((_) => released.future);
      when(() => reopened.minZoom).thenReturn(1);
      when(() => reopened.maxZoom).thenReturn(8);
      when(() => reopened.focusPointSupported).thenReturn(true);
      when(() => reopened.close()).thenAnswer((_) async {});
      final cubit = CameraCubit(service);
      await cubit.start();
      when(() => service.open()).thenAnswer((_) async => reopened);

      final pausing = cubit.appPaused();
      await cubit.appResumed();
      released.complete();
      await pausing;

      expect(cubit.state, ready);
      expect(cubit.preview, same(reopened));
      await cubit.close();
    });

    blocTest<CameraCubit, CameraState>(
      'going to the background releases the camera and returning reopens it',
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        await cubit.appPaused();
        await cubit.appResumed();
      },
      expect: () => [ready, const CameraState(), ready],
      verify: (_) {
        // Once on pause, once when blocTest closes the cubit.
        verify(() => session.close()).called(2);
        verify(() => service.open()).called(2);
      },
    );

    blocTest<CameraCubit, CameraState>(
      'returning after allowing the camera in settings opens it without asking',
      setUp: () {
        when(
          () => service.permission(),
        ).thenAnswer((_) async => CameraPermission.permanentlyDenied);
      },
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        when(
          () => service.permission(),
        ).thenAnswer((_) async => CameraPermission.granted);
        await cubit.appPaused();
        await cubit.appResumed();
      },
      skip: 1,
      expect: () => [const CameraState(), ready],
      verify: (_) => verifyNever(() => service.requestPermission()),
    );

    blocTest<CameraCubit, CameraState>(
      'a camera opened after the app left is closed at once',
      setUp: () {
        when(() => service.open()).thenAnswer((_) => opened.future);
      },
      build: () => CameraCubit(service),
      act: (cubit) async {
        final opening = cubit.start();
        // Wait until the camera is being opened, then leave the app.
        await untilCalled(() => service.open());
        await cubit.appPaused();
        opened.complete(session);
        await opening;
      },
      expect: () => [const CameraState()],
      verify: (_) => verify(() => session.close()).called(1),
    );

    blocTest<CameraCubit, CameraState>(
      'the resume after the permission dialog does not overtake the request',
      setUp: () {
        when(
          () => service.permission(),
        ).thenAnswer((_) async => CameraPermission.denied);
        when(
          () => service.requestPermission(),
        ).thenAnswer((_) => permissionAnswer.future);
      },
      build: () => CameraCubit(service),
      act: (cubit) async {
        final starting = cubit.start();
        await untilCalled(() => service.requestPermission());
        // The dialog paused the activity; it resumes before the answer arrives.
        await cubit.appResumed();
        when(
          () => service.permission(),
        ).thenAnswer((_) async => CameraPermission.granted);
        permissionAnswer.complete(CameraPermission.granted);
        await starting;
      },
      expect: () => [ready],
    );

    blocTest<CameraCubit, CameraState>(
      'a resume while the camera is opening does not open it a second time',
      setUp: () {
        when(() => service.open()).thenAnswer((_) => opened.future);
      },
      build: () => CameraCubit(service),
      act: (cubit) async {
        final starting = cubit.start();
        await untilCalled(() => service.open());
        // On the phone, the resume after the permission dialog can arrive after the answer.
        final resuming = cubit.appResumed();
        opened.complete(session);
        await Future.wait([starting, resuming]);
      },
      expect: () => [ready],
      verify: (_) => verify(() => service.open()).called(1),
    );

    blocTest<CameraCubit, CameraState>(
      'an open after leaving and returning waits for the earlier open to finish',
      setUp: () {
        final second = MockCameraSession();
        when(() => second.minZoom).thenReturn(1);
        when(() => second.maxZoom).thenReturn(8);
        when(() => second.focusPointSupported).thenReturn(true);
        when(() => second.close()).thenAnswer((_) async {});
        final sessions = [opened.future, Future<CameraSession>.value(second)];
        when(() => service.open()).thenAnswer((_) => sessions.removeAt(0));
      },
      build: () => CameraCubit(service),
      act: (cubit) async {
        final starting = cubit.start();
        await untilCalled(() => service.open());
        await cubit.appPaused();
        final resuming = cubit.appResumed();
        await pumpEventQueue();
        // The camera plugin cannot initialize two cameras at once.
        verify(() => service.open()).called(1);
        opened.complete(session);
        await Future.wait([starting, resuming]);
      },
      expect: () => [const CameraState(), ready],
      verify: (_) {
        verify(() => service.open()).called(1);
        verify(() => session.close()).called(1);
      },
    );

    blocTest<CameraCubit, CameraState>(
      'a resume after a permanent denial keeps the app settings action',
      setUp: () {
        // Android reports a permanent denial only as the answer to a request.
        when(
          () => service.permission(),
        ).thenAnswer((_) async => CameraPermission.denied);
        when(
          () => service.requestPermission(),
        ).thenAnswer((_) async => CameraPermission.permanentlyDenied);
      },
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        // On the phone, the resume after the dialog can arrive after the answer.
        await cubit.appResumed();
      },
      expect: () => [
        const CameraState(status: CameraStatus.permissionPermanentlyDenied),
      ],
    );

    blocTest<CameraCubit, CameraState>(
      'permission revoked while away shows the denied state on return',
      setUp: () {
        when(
          () => service.permission(),
        ).thenAnswer((_) async => CameraPermission.granted);
      },
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        await cubit.appPaused();
        when(
          () => service.permission(),
        ).thenAnswer((_) async => CameraPermission.denied);
        await cubit.appResumed();
      },
      expect: () => [
        ready,
        const CameraState(),
        const CameraState(status: CameraStatus.permissionDenied),
      ],
      verify: (_) => verifyNever(() => service.requestPermission()),
    );

    blocTest<CameraCubit, CameraState>(
      'closing the screen releases the camera',
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        await cubit.close();
      },
      verify: (_) => verify(() => session.close()).called(1),
    );
  });

  group('zoom', () {
    blocTest<CameraCubit, CameraState>(
      'is clamped to the camera range',
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        cubit.setZoom(20);
        cubit.setZoom(0.2);
      },
      skip: 1,
      expect: () => [ready.copyWith(zoom: 8), ready.copyWith(zoom: 1)],
      verify: (_) {
        verify(() => session.setZoom(8)).called(1);
        verify(() => session.setZoom(1)).called(1);
      },
    );

    blocTest<CameraCubit, CameraState>(
      'pinch scales the zoom it started from',
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        cubit.setZoom(2);
        cubit.pinchStarted();
        cubit.pinchUpdated(1.5);
        cubit.pinchUpdated(2);
      },
      skip: 2,
      expect: () => [ready.copyWith(zoom: 3), ready.copyWith(zoom: 4)],
    );

    blocTest<CameraCubit, CameraState>(
      'does nothing before the camera is ready',
      build: () => CameraCubit(service),
      act: (cubit) => cubit.setZoom(2),
      expect: () => <CameraState>[],
    );
  });

  group('flash', () {
    blocTest<CameraCubit, CameraState>(
      'cycles off, auto, on, off',
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        cubit.cycleFlash();
        cubit.cycleFlash();
        cubit.cycleFlash();
      },
      skip: 1,
      expect: () => [
        ready.copyWith(flash: CameraFlash.auto),
        ready.copyWith(flash: CameraFlash.on),
        ready,
      ],
      verify: (_) {
        verify(() => session.setFlash(CameraFlash.auto)).called(1);
        verify(() => session.setFlash(CameraFlash.on)).called(1);
        verify(() => session.setFlash(CameraFlash.off)).called(1);
      },
    );

    blocTest<CameraCubit, CameraState>(
      'without a flash unit shows a notice and changes nothing',
      setUp: () =>
          when(() => service.hasFlash()).thenAnswer((_) async => false),
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        cubit.cycleFlash();
      },
      skip: 1,
      expect: () => [
        ready.copyWith(
          flashAvailable: false,
          notice: const CameraNotice(CameraNoticeKind.flashUnavailable, 1),
        ),
      ],
      verify: (_) => verifyNever(() => session.setFlash(any())),
    );
  });

  group('focus', () {
    blocTest<CameraCubit, CameraState>(
      'a tap focuses at the mapped point and places the ring where tapped',
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        // 3:4 preview in 400 × 800: 100 px cropped each side, so x = 100/600.
        cubit.tapToFocus(const Offset(0, 400), const Size(400, 800));
      },
      skip: 1,
      expect: () => [
        ready.copyWith(focusMarker: const FocusMarker(Offset(0, 400), 1)),
      ],
      verify: (_) =>
          verify(() => session.focusAt(const Offset(100 / 600, 0.5))).called(1),
    );

    blocTest<CameraCubit, CameraState>(
      'unsupported focus shows a notice and no ring',
      setUp: () => when(() => session.focusPointSupported).thenReturn(false),
      build: () => CameraCubit(service),
      act: (cubit) async {
        await cubit.start();
        cubit.tapToFocus(const Offset(200, 400), const Size(400, 800));
      },
      skip: 1,
      expect: () => [
        ready.copyWith(
          focusSupported: false,
          notice: const CameraNotice(CameraNoticeKind.focusUnsupported, 1),
        ),
      ],
      verify: (_) => verifyNever(() => session.focusAt(any())),
    );
  });

  group('takePicture', () {
    test('returns the open camera\'s photo', () async {
      when(() => session.takePicture()).thenAnswer((_) async => '/tmp/a.jpg');
      final cubit = CameraCubit(service);
      await cubit.start();

      expect(await cubit.takePicture(), '/tmp/a.jpg');
      await cubit.close();
    });

    test('fails while no camera is open', () async {
      final cubit = CameraCubit(service);

      await expectLater(
        cubit.takePicture(),
        throwsA(isA<CameraCaptureException>()),
      );
      verifyNever(() => session.takePicture());
      await cubit.close();
    });
  });
}
