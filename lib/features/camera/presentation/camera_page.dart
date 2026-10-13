import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/camera_service.dart';
import 'camera_cubit.dart';
import 'camera_state.dart';

/// Dark camera colors (design C1-C11). The camera is always dark; the rest of the app is light.
abstract final class CameraColors {
  static const background = Color(0xFF0D1015);
  static const scrim = Color(0x61000000);
  static const onCamera = Color(0xFFFFFFFF);
  static const onCameraVariant = Color(0x99FFFFFF);
}

/// `CameraPreviewScreen`: provides [CameraCubit] and starts the camera.
class CameraPage extends StatelessWidget {
  const CameraPage({super.key, required this.cameraService});

  final CameraService cameraService;

  static Route<void> route(CameraService cameraService) => MaterialPageRoute(
    builder: (_) => CameraPage(cameraService: cameraService),
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CameraCubit(cameraService)..start(),
      child: const CameraView(),
    );
  }
}

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final cubit = context.read<CameraCubit>();
    // Released only when the app is no longer visible: the permission dialog makes it
    // `inactive` without hiding it (plan C8).
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        cubit.appPaused();
      case AppLifecycleState.resumed:
        cubit.appResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: CameraColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: CameraColors.background,
        body: BlocBuilder<CameraCubit, CameraState>(
          buildWhen: (previous, current) => previous.status != current.status,
          builder: (context, state) => switch (state.status) {
            CameraStatus.ready => const _LiveCamera(),
            // The blocked states (C8, C9) are drawn in a later step.
            CameraStatus.initializing ||
            CameraStatus.permissionDenied ||
            CameraStatus.permissionPermanentlyDenied ||
            CameraStatus.unavailable => const _Initializing(),
          },
        ),
      ),
    );
  }
}

class _Initializing extends StatelessWidget {
  const _Initializing();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              color: CameraColors.onCameraVariant,
              strokeWidth: 2.5,
            ),
          ),
        ),
        _TopBar(),
      ],
    );
  }
}

/// Preview (C1).
class _LiveCamera extends StatelessWidget {
  const _LiveCamera();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [_CoverPreview(), _TopBar()],
    );
  }
}

/// The preview scaled to cover the screen, cropped rather than stretched (plan C3).
class _CoverPreview extends StatelessWidget {
  const _CoverPreview();

  @override
  Widget build(BuildContext context) {
    final preview = context.read<CameraCubit>().preview;
    if (preview == null) return const SizedBox.expand();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: 1000,
          height: 1000 / preview.previewAspectRatio,
          child: preview.buildPreview(),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99000000), Color(0x00000000)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            child: Row(
              children: [
                _RoundButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close camera',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 26,
      color: CameraColors.onCamera,
      style: IconButton.styleFrom(
        backgroundColor: CameraColors.scrim,
        fixedSize: const Size.square(48),
      ),
    );
  }
}
