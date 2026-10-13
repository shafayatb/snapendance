import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapendance/app/home/home_screen.dart';
import 'package:snapendance/app/native/attendance_launcher.dart';

// Written out here rather than imported, so a renamed channel in the app fails
// this test instead of moving with it. Must match MainActivity.kt.
const _navigationChannel = MethodChannel(
  'com.shafayatb.snapendance/navigation',
);

void main() {
  late List<MethodCall> receivedCalls;

  setUp(() {
    receivedCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navigationChannel, (call) async {
          receivedCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navigationChannel, null);
  });

  testWidgets('tapping the Attendance button asks Android to open attendance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(attendanceLauncher: AttendanceLauncher())),
    );

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
}
