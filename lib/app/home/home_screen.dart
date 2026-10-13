import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../features/camera/data/camera_service.dart';
import '../../features/camera/presentation/camera_page.dart';
import '../../features/uploads/presentation/batch_cubit.dart';
import '../../features/uploads/presentation/batch_state.dart';
import '../native/attendance_launcher.dart';
import '../theme/app_tokens.dart';

/// The app's entry point (design frame H1): a header and one card per feature.
///
/// The Attendance card shows a static subtitle. Attendance data is stored by
/// the native Android screen and is not shared with Flutter.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.attendanceLauncher,
    required this.cameraService,
  });

  final AttendanceLauncher attendanceLauncher;
  final CameraService cameraService;

  Future<void> _openAttendance(BuildContext context) async {
    try {
      await attendanceLauncher.open();
    } on AttendanceLaunchException {
      // Home may have been replaced while Android was answering.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        // Replaces, rather than queues behind, a message from an earlier tap.
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("Couldn't open Attendance. Please try again."),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        // Opaque, so Android 8-9 (no edge-to-edge) still show the page color.
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Snapendance', style: textTheme.headlineLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      DateFormat('EEE, d MMM').format(DateTime.now()),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _FeatureCard(
                  icon: Icons.location_on_outlined,
                  title: 'Attendance',
                  subtitle: 'Office setup and check-in',
                  onTap: () => _openAttendance(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: BlocSelector<BatchCubit, BatchState, int>(
                  selector: (state) => state.pendingCount,
                  builder: (context, pending) => _FeatureCard(
                    icon: Icons.photo_camera_outlined,
                    title: 'Camera & Uploads',
                    // H2: the pending count, which Flutter owns.
                    subtitle: pending == 0
                        ? 'Capture a batch of photos'
                        : '$pending ${pending == 1 ? 'image' : 'images'} waiting',
                    statusColor: pending == 0 ? null : AppStatusColors.pending,
                    onTap: () => Navigator.of(
                      context,
                    ).push(CameraPage.route(cameraService)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.statusColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Set for a status line (H2): the subtitle gets this color and a dot.
  final Color? statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      // Clips the ripple to the rounded corners.
      clipBehavior: Clip.antiAlias,
      // The card merges its texts into one label; this makes it a button.
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: colors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // H1 sets card titles at 17 px, between titleMedium and labelLarge.
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (statusColor != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                subtitle,
                                style: textTheme.bodyMedium?.copyWith(
                                  height: 18 / 14,
                                  color: statusColor ?? colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox.square(
                    dimension: 48,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
