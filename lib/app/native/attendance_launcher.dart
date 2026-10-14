import 'package:flutter/services.dart';

class AttendanceLauncher {
  const AttendanceLauncher();

  static const _channel = MethodChannel('com.shafayatb.snapendance/navigation');

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

class AttendanceLaunchException implements Exception {
  const AttendanceLaunchException(this.cause);

  final Exception cause;

  @override
  String toString() => 'AttendanceLaunchException: $cause';
}
