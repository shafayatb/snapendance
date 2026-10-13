import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/native/attendance_launcher.dart';
import 'features/camera/data/plugin_camera_service.dart';

void main() {
  // Draw behind the system bars from Android 10 (API 29); Android 15+ enforces it.
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(
    const SnapendanceApp(
      attendanceLauncher: AttendanceLauncher(),
      cameraService: PluginCameraService(),
    ),
  );
}
