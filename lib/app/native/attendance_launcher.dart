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
  ///
  /// Throws [AttendanceLaunchException] if Android reports an error or has no
  /// handler for the request.
  Future<void> open() async {
    try {
      await _channel.invokeMethod<void>('openAttendance');
    } on PlatformException catch (error) {
      throw AttendanceLaunchException(error);
    } on MissingPluginException catch (error) {
      throw AttendanceLaunchException(error);
    }
  }
}

/// The native attendance screen could not be opened.
class AttendanceLaunchException implements Exception {
  const AttendanceLaunchException(this.cause);

  /// The channel error behind this failure, kept for debugging.
  final Exception cause;

  @override
  String toString() => 'AttendanceLaunchException: $cause';
}
