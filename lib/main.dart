import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/native/attendance_launcher.dart';
import 'features/camera/data/plugin_camera_service.dart';
import 'features/uploads/data/capture_files.dart';
import 'features/uploads/data/upload_database.dart';
import 'features/uploads/data/upload_queue_repository.dart';

Future<void> main() async {
  // Draw behind the system bars from Android 10 (API 29); Android 15+ enforces it.
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final uploadQueue = UploadQueueRepository(
    await openUploadDatabase(),
    await CaptureFiles.appDocuments(),
  );
  // Before the camera can capture (plan U3).
  await uploadQueue.reconcile();

  runApp(
    SnapendanceApp(
      attendanceLauncher: const AttendanceLauncher(),
      cameraService: const PluginCameraService(),
      uploadQueue: uploadQueue,
    ),
  );
}
