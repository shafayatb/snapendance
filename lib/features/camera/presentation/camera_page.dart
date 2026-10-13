import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/camera_service.dart';
import '../domain/zoom_presets.dart';
import 'camera_cubit.dart';
import 'camera_state.dart';

/// Dark camera colors (design C1-C11). The camera is always dark; the rest of the app is light.
abstract final class CameraColors {
  static const background = Color(0xFF0D1015);
  static const surface = Color(0xFF1E232C);
  static const scrim = Color(0x61000000);
  static const onCamera = Color(0xFFFFFFFF);
  static const onCameraVariant = Color(0x99FFFFFF);
  static const primary = Color(0xFF2F66DC);
  static const link = Color(0xFF8AB4F8);
  static const focus = Color(0xFFFFD54F);
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

  void _showNotice(BuildContext context, CameraNotice notice) {
    final message = switch (notice.kind) {
      CameraNoticeKind.flashUnavailable =>
        'Flash isn’t available on this camera',
      CameraNoticeKind.focusUnsupported =>
        'Tap to focus isn’t supported on this camera',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: CameraColors.surface,
          duration: const Duration(seconds: 2),
        ),
      );
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
        body: BlocListener<CameraCubit, CameraState>(
          listenWhen: (previous, current) =>
              current.notice != null && current.notice != previous.notice,
          listener: (context, state) => _showNotice(context, state.notice!),
          child: BlocBuilder<CameraCubit, CameraState>(
            buildWhen: (previous, current) => previous.status != current.status,
            builder: (context, state) => switch (state.status) {
              CameraStatus.initializing => const _Initializing(),
              CameraStatus.ready => const _LiveCamera(),
              CameraStatus.permissionDenied => const _BlockedState(
                icon: Icons.no_photography_rounded,
                title: 'Camera access needed',
                body:
                    'Snapendance needs the camera to capture photo batches. '
                    'Allow camera access to continue.',
                action: _BlockedAction.allow,
              ),
              CameraStatus.permissionPermanentlyDenied => const _BlockedState(
                icon: Icons.no_photography_rounded,
                title: 'Camera access needed',
                body:
                    'Snapendance needs the camera to capture photo batches. '
                    'You declined access, so allow it in App settings.',
                action: _BlockedAction.settings,
              ),
              CameraStatus.unavailable => const _BlockedState(
                icon: Icons.videocam_off_rounded,
                title: 'Camera unavailable',
                body:
                    'The camera couldn’t start. Another app may be using it. '
                    'Close other camera apps and try again.',
                action: _BlockedAction.retry,
              ),
            },
          ),
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

/// Preview (C1) with pinch zoom, tap-to-focus, the zoom slider, and the preset buttons.
class _LiveCamera extends StatefulWidget {
  const _LiveCamera();

  @override
  State<_LiveCamera> createState() => _LiveCameraState();
}

class _LiveCameraState extends State<_LiveCamera> {
  bool _pinching = false;
  // Pinch readout (C3): shown while pinching, faded 500 ms after release.
  bool _showReadout = false;
  Timer? _readoutTimer;

  @override
  void dispose() {
    _readoutTimer?.cancel();
    super.dispose();
  }

  void _pinchStarted(ScaleStartDetails details) {
    // One finger also starts a scale gesture; only a pinch changes zoom. A second finger
    // restarts the gesture, so a pinch always starts here with two pointers.
    if (details.pointerCount < 2) return;
    context.read<CameraCubit>().pinchStarted();
    _readoutTimer?.cancel();
    setState(() {
      _pinching = true;
      _showReadout = true;
    });
  }

  void _pinchUpdated(ScaleUpdateDetails details) {
    if (!_pinching || details.pointerCount < 2) return;
    context.read<CameraCubit>().pinchUpdated(details.scale);
  }

  void _pinchEnded(ScaleEndDetails details) {
    if (!_pinching) return;
    _pinching = false;
    _readoutTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showReadout = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          // A pinch wins the gesture arena over a tap, so pinching never focuses.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => context.read<CameraCubit>().tapToFocus(
              details.localPosition,
              constraints.biggest,
            ),
            onScaleStart: _pinchStarted,
            onScaleUpdate: _pinchUpdated,
            onScaleEnd: _pinchEnded,
            child: const _CoverPreview(),
          ),
          const _FocusRing(),
          const _TopBar(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 88),
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showReadout ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const _ZoomReadout(),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(child: _ZoomSlider()),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomControls(),
          ),
        ],
      ),
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

class _FocusRing extends StatelessWidget {
  const _FocusRing();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CameraCubit, CameraState, FocusMarker?>(
      selector: (state) => state.focusMarker,
      builder: (context, marker) {
        if (marker == null) return const SizedBox.shrink();
        return Positioned(
          left: marker.position.dx - 40,
          top: marker.position.dy - 40,
          // A new key restarts the animation for every tap.
          child: _AnimatedFocusRing(key: ValueKey(marker.serial)),
        );
      },
    );
  }
}

/// C2: scales 1.2 → 1.0 in 150 ms, holds 1.5 s, fades out in 200 ms.
class _AnimatedFocusRing extends StatefulWidget {
  const _AnimatedFocusRing({super.key});

  @override
  State<_AnimatedFocusRing> createState() => _AnimatedFocusRingState();
}

class _AnimatedFocusRingState extends State<_AnimatedFocusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1850),
  )..forward();

  late final Animation<double> _scale = Tween(begin: 1.2, end: 1.0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 150 / 1850, curve: Curves.easeOut),
    ),
  );

  late final Animation<double> _opacity = Tween(begin: 1.0, end: 0.0).animate(
    CurvedAnimation(parent: _controller, curve: const Interval(1650 / 1850, 1)),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: 80,
            height: 104,
            child: Column(
              children: [
                Container(
                  key: const ValueKey('focus-ring'),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: CameraColors.focus, width: 1.5),
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: CameraColors.focus,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // "FOCUS", not the design's "FOCUS LOCKED": focus is not locked (deviation C2).
                const Text(
                  'FOCUS',
                  style: TextStyle(
                    color: CameraColors.focus,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.96,
                  ),
                ),
              ],
            ),
          ),
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

class _ZoomReadout extends StatelessWidget {
  const _ZoomReadout();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CameraCubit, CameraState, double>(
      selector: (state) => state.zoom,
      builder: (context, zoom) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: CameraColors.scrim,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          formatZoom(zoom),
          style: const TextStyle(
            color: CameraColors.onCamera,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Vertical slider on the right edge (C1), labeled with the camera's real range.
class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraCubit, CameraState>(
      buildWhen: (previous, current) =>
          previous.zoom != current.zoom || previous.maxZoom != current.maxZoom,
      builder: (context, state) {
        if (state.maxZoom <= state.minZoom) return const SizedBox.shrink();
        const labelStyle = TextStyle(
          color: CameraColors.onCamera,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatZoom(state.maxZoom), style: labelStyle),
            SizedBox(
              height: 260,
              width: 48,
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: CameraColors.onCamera,
                    inactiveTrackColor: CameraColors.onCameraVariant,
                    thumbColor: CameraColors.onCamera,
                    overlayColor: const Color(0x29FFFFFF),
                  ),
                  child: Semantics(
                    label: 'Zoom',
                    child: Slider(
                      min: state.minZoom,
                      max: state.maxZoom,
                      value: state.zoom,
                      onChanged: context.read<CameraCubit>().setZoom,
                    ),
                  ),
                ),
              ),
            ),
            Text(formatZoom(state.minZoom), style: labelStyle),
          ],
        );
      },
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x99000000), Color(0x00000000)],
        ),
      ),
      child: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 32, 16, 24),
          child: Center(child: _ZoomPresets()),
        ),
      ),
    );
  }
}

/// Rounded zoom buttons (C1, C4). The selected one is white; none is selected between presets.
class _ZoomPresets extends StatelessWidget {
  const _ZoomPresets();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraCubit, CameraState>(
      buildWhen: (previous, current) =>
          previous.zoom != current.zoom || previous.presets != current.presets,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: CameraColors.scrim,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final preset in state.presets)
                _ZoomPresetButton(
                  label: formatZoom(preset),
                  selected: (state.zoom - preset).abs() < 0.05,
                  onPressed: () => context.read<CameraCubit>().setZoom(preset),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ZoomPresetButton extends StatelessWidget {
  const _ZoomPresetButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Zoom $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? CameraColors.onCamera : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? CameraColors.background : CameraColors.onCamera,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

enum _BlockedAction { allow, settings, retry }

/// C8 (permission) and C9 (camera unavailable).
class _BlockedState extends StatelessWidget {
  const _BlockedState({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final _BlockedAction action;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    final (label, actionIcon, onPressed) = switch (action) {
      _BlockedAction.allow => (
        'Allow camera access',
        Icons.arrow_forward_rounded,
        cubit.retry,
      ),
      _BlockedAction.settings => (
        'Open app settings',
        Icons.open_in_new_rounded,
        cubit.openAppSettings,
      ),
      _BlockedAction.retry => ('Try again', Icons.refresh_rounded, cubit.retry),
    };
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: CameraColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: CameraColors.onCameraVariant,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CameraColors.onCamera,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CameraColors.onCameraVariant,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onPressed,
                  icon: Icon(actionIcon),
                  label: Text(label),
                  style: FilledButton.styleFrom(
                    backgroundColor: CameraColors.primary,
                    foregroundColor: CameraColors.onCamera,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: CameraColors.link,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Back to home'),
                ),
              ],
            ),
          ),
        ),
        const _TopBar(),
      ],
    );
  }
}
