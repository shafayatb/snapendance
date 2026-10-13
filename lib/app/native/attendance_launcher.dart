import 'package:flutter/services.dart';

/// Opens the native Android attendance screen (`AttendanceActivity`).
///
/// Navigation is the only thing Flutter and the native screen share; attendance
/// data stays on the Android side.
class AttendanceLauncher {
  const AttendanceLauncher();

  // Must match the channel name and method in MainActivity.kt.
  static const _channel = MethodChannel('com.shafayatb.snapendance/navigation');

  /// Starts the native screen on top of Flutter. Completes once Android has
  /// accepted the request to start it.
  Future<void> open() => _channel.invokeMethod<void>('openAttendance');
}
