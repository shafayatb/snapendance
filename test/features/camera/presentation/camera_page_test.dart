import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapendance/features/camera/presentation/camera_cubit.dart';
import 'package:snapendance/features/camera/presentation/camera_page.dart';
import 'package:snapendance/features/camera/presentation/camera_state.dart';

class MockCameraCubit extends MockCubit<CameraState> implements CameraCubit {}

void main() {
  late MockCameraCubit cubit;

  setUpAll(() {
    registerFallbackValue(Offset.zero);
    registerFallbackValue(Size.zero);
  });

  setUp(() {
    cubit = MockCameraCubit();
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.openAppSettings()).thenAnswer((_) async {});
    when(() => cubit.preview).thenReturn(null);
  });

  /// Home with the camera pushed on top, so "Back to home" has somewhere to go.
  Future<void> showCamera(
    WidgetTester tester,
    CameraStatus status, {
    CameraState? state,
  }) async {
    when(() => cubit.state).thenReturn(state ?? CameraState(status: status));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<CameraCubit>.value(
                  value: cubit,
                  child: const CameraView(),
                ),
              ),
            ),
            child: const Text('Home'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
  }

  testWidgets('denied permission explains why and asks again', (tester) async {
    await showCamera(tester, CameraStatus.permissionDenied);

    expect(find.text('Camera access needed'), findsOneWidget);
    await tester.tap(find.text('Allow camera access'));
    verify(() => cubit.retry()).called(1);
    verifyNever(() => cubit.openAppSettings());
  });

  testWidgets('permanently denied permission sends the user to app settings', (
    tester,
  ) async {
    await showCamera(tester, CameraStatus.permissionPermanentlyDenied);

    expect(find.text('Camera access needed'), findsOneWidget);
    expect(find.textContaining('allow it in App settings'), findsOneWidget);
    await tester.tap(find.text('Open app settings'));
    verify(() => cubit.openAppSettings()).called(1);
    verifyNever(() => cubit.retry());
  });

  testWidgets('an unavailable camera offers Try again', (tester) async {
    await showCamera(tester, CameraStatus.unavailable);

    expect(find.text('Camera unavailable'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => cubit.retry()).called(1);
  });

  testWidgets('Back to home leaves a blocked camera', (tester) async {
    await showCamera(tester, CameraStatus.unavailable);

    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();

    expect(find.text('Camera unavailable'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  group('zoom', () {
    const ready = CameraState(
      status: CameraStatus.ready,
      minZoom: 1,
      maxZoom: 8,
      presets: [1, 2, 5],
    );

    Future<void> showReady(WidgetTester tester, {double zoom = 1}) =>
        showCamera(
          tester,
          CameraStatus.ready,
          state: ready.copyWith(zoom: zoom),
        );

    testWidgets('the slider is labeled with the camera\'s real range', (
      tester,
    ) async {
      await showReady(tester);

      expect(find.byType(Slider), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect((slider.min, slider.max, slider.value), (1.0, 8.0, 1.0));
      expect(find.text('8×'), findsOneWidget);
    });

    testWidgets('a preset button sets that zoom', (tester) async {
      await showReady(tester);

      await tester.tap(find.bySemanticsLabel('Zoom 2×'));
      verify(() => cubit.setZoom(2)).called(1);
    });

    testWidgets('only the preset matching the zoom is selected', (
      tester,
    ) async {
      await showReady(tester, zoom: 2);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Zoom 2×')),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Zoom 1×')),
        isSemantics(isSelected: false, isButton: true),
      );
    });

    testWidgets('no preset is selected between presets', (tester) async {
      await showReady(tester, zoom: 3.4);
      for (final label in ['Zoom 1×', 'Zoom 2×', 'Zoom 5×']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(isSelected: false, isButton: true),
        );
      }
    });

    testWidgets('dragging the slider sets the zoom', (tester) async {
      await showReady(tester);

      // Vertical slider: dragging up zooms in.
      await tester.drag(find.byType(Slider), const Offset(0, -100));
      final zoom = verify(() => cubit.setZoom(captureAny())).captured.last;
      expect(zoom, greaterThan(1));
    });

    // The Cubit test "pinch scales the zoom it started from" covers the arithmetic.
    testWidgets('spreading two fingers zooms in, without focusing', (
      tester,
    ) async {
      await showReady(tester);
      final center = tester.getCenter(find.byType(CameraView));

      final first = await tester.startGesture(center - const Offset(0, 50));
      final second = await tester.startGesture(center + const Offset(0, 50));
      for (var step = 0; step < 5; step++) {
        await first.moveBy(const Offset(0, -20));
        await second.moveBy(const Offset(0, 20));
      }
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pump(const Duration(seconds: 1));

      verify(() => cubit.pinchStarted()).called(1);
      verifyNever(() => cubit.tapToFocus(any(), any()));
      final scales = verify(
        () => cubit.pinchUpdated(captureAny()),
      ).captured.cast<double>();
      expect(scales.last, greaterThan(1.5));
      for (var i = 1; i < scales.length; i++) {
        expect(scales[i], greaterThanOrEqualTo(scales[i - 1]));
      }
    });

    testWidgets('the readout shows while pinching and fades after release', (
      tester,
    ) async {
      await showReady(tester);
      final center = tester.getCenter(find.byType(CameraView));
      double readoutOpacity() =>
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
      expect(readoutOpacity(), 0);

      final first = await tester.startGesture(center - const Offset(0, 50));
      final second = await tester.startGesture(center + const Offset(0, 50));
      await first.moveBy(const Offset(0, -50));
      await second.moveBy(const Offset(0, 50));
      await tester.pump();
      expect(readoutOpacity(), 1);

      await first.up();
      await second.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(readoutOpacity(), 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(readoutOpacity(), 0);
    });

    testWidgets('a one-finger drag on the preview does not zoom', (
      tester,
    ) async {
      await showReady(tester);

      await tester.dragFrom(
        tester.getCenter(find.byType(CameraView)),
        const Offset(0, 120),
      );
      await tester.pump();

      verifyNever(() => cubit.pinchStarted());
      verifyNever(() => cubit.pinchUpdated(any()));
    });
  });

  group('focus', () {
    const ready = CameraState(
      status: CameraStatus.ready,
      minZoom: 1,
      maxZoom: 8,
      presets: [1, 2, 5],
      focusSupported: true,
    );

    testWidgets('a tap on the preview asks to focus there', (tester) async {
      await showCamera(tester, CameraStatus.ready, state: ready);
      final view = tester.getRect(find.byType(CameraView));

      await tester.tapAt(view.topLeft + const Offset(120, 300));
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => cubit.tapToFocus(const Offset(120, 300), view.size),
      ).called(1);
    });

    testWidgets('the ring is centered where the tap landed', (tester) async {
      await showCamera(
        tester,
        CameraStatus.ready,
        state: ready.copyWith(
          focusMarker: const FocusMarker(Offset(120, 300), 1),
        ),
      );

      expect(find.text('FOCUS'), findsOneWidget);
      final ring = tester.getRect(find.byKey(const ValueKey('focus-ring')));
      expect(ring.size, const Size(80, 80));
      expect(ring.center, const Offset(120, 300));

      // Scales in, holds 1.5 s, fades out in 200 ms.
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('FOCUS'), findsOneWidget);
      await tester.pumpAndSettle();
      final opacity = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('FOCUS'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(opacity.opacity.value, 0);
    });

    testWidgets('unsupported focus shows a hint', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          ready.copyWith(
            notice: const CameraNotice(CameraNoticeKind.focusUnsupported, 1),
          ),
        ),
        initialState: ready,
      );
      await showCamera(tester, CameraStatus.ready, state: ready);
      await tester.pump();

      expect(
        find.text('Tap to focus isn’t supported on this camera'),
        findsOneWidget,
      );
    });
  });
}
