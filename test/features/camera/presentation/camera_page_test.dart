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

  setUp(() {
    cubit = MockCameraCubit();
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.openAppSettings()).thenAnswer((_) async {});
  });

  /// Home with the camera pushed on top, so "Back to home" has somewhere to go.
  Future<void> showCamera(WidgetTester tester, CameraStatus status) async {
    when(() => cubit.state).thenReturn(CameraState(status: status));
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
}
