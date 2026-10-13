import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/camera/data/camera_service.dart';
import '../features/uploads/data/upload_queue_repository.dart';
import '../features/uploads/presentation/batch_cubit.dart';
import 'home/home_screen.dart';
import 'native/attendance_launcher.dart';
import 'theme/app_theme.dart';

class SnapendanceApp extends StatelessWidget {
  const SnapendanceApp({
    super.key,
    required this.attendanceLauncher,
    required this.cameraService,
    required this.uploadQueue,
  });

  final AttendanceLauncher attendanceLauncher;
  final CameraService cameraService;
  final UploadQueueRepository uploadQueue;

  @override
  Widget build(BuildContext context) {
    // Above the navigator, so Home and every route share the stored counts.
    return RepositoryProvider.value(
      value: uploadQueue,
      child: BlocProvider(
        create: (_) => BatchCubit(uploadQueue)..load(),
        child: MaterialApp(
          title: 'Snapendance',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          home: HomeScreen(
            attendanceLauncher: attendanceLauncher,
            cameraService: cameraService,
          ),
        ),
      ),
    );
  }
}
