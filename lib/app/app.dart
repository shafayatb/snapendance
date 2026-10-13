import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/camera/data/camera_service.dart';
import '../features/uploads/data/upload_queue_repository.dart';
import '../features/uploads/data/upload_scheduler.dart';
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
    required this.uploadScheduler,
  });

  final AttendanceLauncher attendanceLauncher;
  final CameraService cameraService;
  final UploadQueueRepository uploadQueue;
  final UploadScheduler uploadScheduler;

  @override
  Widget build(BuildContext context) {
    // Above the navigator, so Home and every route share the stored counts.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: uploadQueue),
        RepositoryProvider.value(value: uploadScheduler),
      ],
      child: BlocProvider(
        create: (_) => BatchCubit(uploadQueue, uploadScheduler)..appResumed(),
        child: _ResumeUploads(
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
      ),
    );
  }
}

/// Tells [BatchCubit] when the app returns to the foreground (plan U8).
class _ResumeUploads extends StatefulWidget {
  const _ResumeUploads({required this.child});

  final Widget child;

  @override
  State<_ResumeUploads> createState() => _ResumeUploadsState();
}

class _ResumeUploadsState extends State<_ResumeUploads> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => context.read<BatchCubit>().appResumed(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
