import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/native/attendance_launcher.dart';
import 'app/startup.dart';
import 'features/camera/data/plugin_camera_service.dart';
import 'features/uploads/data/capture_files.dart';
import 'features/uploads/data/connectivity_service.dart';
import 'features/uploads/data/upload_database.dart';
import 'features/uploads/data/upload_queue_repository.dart';
import 'features/uploads/data/upload_scheduler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    AppStartup(
      start: () => startApp(
        openUploadQueue: () async => UploadQueueRepository(
          await openUploadDatabase(),
          await CaptureFiles.appDocuments(),
        ),
        initializeScheduler: WorkmanagerUploadScheduler.initialize,
        buildApp: (uploadQueue) => SnapendanceApp(
          attendanceLauncher: const AttendanceLauncher(),
          cameraService: const PluginCameraService(),
          uploadQueue: uploadQueue,
          uploadScheduler: const WorkmanagerUploadScheduler(),
          connectivity: const PluginConnectivityService(),
        ),
      ),
    ),
  );
}
