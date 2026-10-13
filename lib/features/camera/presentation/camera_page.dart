import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/widgets/dashed_border.dart';
import '../../uploads/presentation/batch_cubit.dart';
import '../../uploads/presentation/batch_state.dart';
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
  static const pendingBadge = Color(0xFFF2B65A);
  static const shutterBusyRing = Color(0xFF8DB2FF);
  static const shutterBusyFill = Color(0xFFC9D0DA);
  static const disabledButton = Color(0x1FFFFFFF);
  static const onDisabledButton = Color(0x80FFFFFF);
  // The light "Batch queued" card (C10).
  static const bannerSurface = Color(0xFFE6EAF1);
  static const onBanner = Color(0xFF13224A);
  static const onBannerVariant = Color(0xFF4A5670);
  static const bannerSuccess = Color(0xFF17804A);
  static const bannerAction = Color(0xFF1D5BD6);
}

/// Controls are dimmed to this while a photo is being saved (C6).
const _savingOpacity = 0.38;

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
  // A message under the top bar: the C10 card or a C7-style toast.
  Widget? _topMessage;
  Timer? _topMessageTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _topMessageTimer?.cancel();
    super.dispose();
  }

  void _showTopMessage(Widget message, Duration duration) {
    _topMessageTimer?.cancel();
    setState(() => _topMessage = message);
    _topMessageTimer = Timer(duration, () {
      if (mounted) setState(() => _topMessage = null);
    });
  }

  void _showBatchNotice(BatchNotice notice) {
    switch (notice.kind) {
      case BatchNoticeKind.batchQueued:
        _showTopMessage(
          _QueuedCard(count: notice.count),
          const Duration(seconds: 4),
        );
      case BatchNoticeKind.captureFailed:
        _showTopMessage(
          const _Toast(
            icon: Icons.error_outline_rounded,
            text: 'Couldn’t save the photo. Try again.',
          ),
          const Duration(seconds: 3),
        );
      case BatchNoticeKind.emptyBatch:
        _showTopMessage(
          const _Toast(
            icon: Icons.photo_camera_rounded,
            text: 'Take a photo to start a batch',
          ),
          const Duration(seconds: 2),
        );
    }
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
        body: MultiBlocListener(
          listeners: [
            BlocListener<CameraCubit, CameraState>(
              listenWhen: (previous, current) =>
                  current.notice != null && current.notice != previous.notice,
              listener: (context, state) => _showNotice(context, state.notice!),
            ),
            BlocListener<BatchCubit, BatchState>(
              listenWhen: (previous, current) =>
                  current.notice != null && current.notice != previous.notice,
              listener: (context, state) => _showBatchNotice(state.notice!),
            ),
          ],
          child: Stack(
            fit: StackFit.expand,
            children: [
              BlocBuilder<CameraCubit, CameraState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status,
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
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 64),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _topMessage ?? const _SavingToast(),
                      ),
                    ),
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

/// "Saving photo n…" while a capture is stored (C6).
class _SavingToast extends StatelessWidget {
  const _SavingToast();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BatchCubit, BatchState>(
      buildWhen: (previous, current) =>
          previous.saving != current.saving ||
          previous.openCount != current.openCount,
      builder: (context, state) => state.saving
          ? _Toast(
              icon: Icons.hourglass_top_rounded,
              text: 'Saving photo ${state.openCount + 1}…',
            )
          : const SizedBox.shrink(),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: CameraColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: CameraColors.onCamera),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: CameraColors.onCamera,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// C10: shown for 4 s after a batch is submitted.
class _QueuedCard extends StatelessWidget {
  const _QueuedCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: CameraColors.bannerSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: CameraColors.bannerSuccess,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Batch of $count ${count == 1 ? 'photo' : 'photos'} queued',
                  style: const TextStyle(
                    color: CameraColors.onBanner,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Uploads retry automatically when online.',
                  style: TextStyle(
                    color: CameraColors.onBannerVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          const _TopBar(live: true),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 88),
                child: Center(
                  child: AnimatedOpacity(
                    key: const ValueKey('zoom-readout'),
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
            child: Center(child: _OffWhileSaving(child: _ZoomSlider())),
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
  const _TopBar({this.live = false});

  /// The camera is open: the upload and flash buttons are shown.
  final bool live;

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
                const Spacer(),
                if (live) ...[
                  const _UploadsButton(),
                  const SizedBox(width: 8),
                  const _FlashButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Upload Manager's entry, with the pending-upload badge (C1).
class _UploadsButton extends StatelessWidget {
  const _UploadsButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BatchCubit, BatchState, int>(
      selector: (state) => state.pendingCount,
      builder: (context, pending) => Semantics(
        button: true,
        label: pending == 0
            ? 'Upload Manager'
            : 'Upload Manager, $pending pending',
        excludeSemantics: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _RoundButton(
              icon: Icons.cloud_upload_outlined,
              tooltip: 'Upload Manager',
              onPressed: () {},
            ),
            if (pending > 0)
              Positioned(
                top: -2,
                right: -4,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: CameraColors.pendingBadge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pending',
                      style: const TextStyle(
                        color: CameraColors.background,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlashButton extends StatelessWidget {
  const _FlashButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraCubit, CameraState>(
      buildWhen: (previous, current) =>
          previous.flash != current.flash ||
          previous.flashAvailable != current.flashAvailable,
      builder: (context, state) {
        final (icon, label) = switch (state.flash) {
          CameraFlash.off => (Icons.flash_off_rounded, 'off'),
          CameraFlash.auto => (Icons.flash_auto_rounded, 'auto'),
          CameraFlash.on => (Icons.flash_on_rounded, 'on'),
        };
        return Opacity(
          // Disabled look, but still tappable so it can explain why (C5).
          opacity: state.flashAvailable ? 1 : 0.38,
          child: _RoundButton(
            icon: state.flashAvailable ? icon : Icons.flash_off_rounded,
            tooltip: state.flashAvailable
                ? 'Flash $label'
                : 'Flash unavailable',
            onPressed: context.read<CameraCubit>().cycleFlash,
          ),
        );
      },
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
          padding: EdgeInsets.fromLTRB(16, 32, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OffWhileSaving(child: _ZoomPresets()),
              SizedBox(height: 24),
              // The flip button's place stays empty: back cameras only (plan C6).
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _BatchThumbnail(),
                    _ShutterButton(),
                    SizedBox.square(dimension: 56),
                  ],
                ),
              ),
              SizedBox(height: 24),
              _UploadBatchButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims [child] and ignores its touches while a photo is being saved (C6).
class _OffWhileSaving extends StatelessWidget {
  const _OffWhileSaving({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BatchCubit, BatchState, bool>(
      selector: (state) => state.saving,
      builder: (context, saving) => IgnorePointer(
        ignoring: saving,
        child: AnimatedOpacity(
          opacity: saving ? _savingOpacity : 1,
          duration: const Duration(milliseconds: 150),
          child: child,
        ),
      ),
    );
  }
}

/// The newest capture with the batch's count, or a dashed placeholder when empty (C1, C7).
class _BatchThumbnail extends StatelessWidget {
  const _BatchThumbnail();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BatchCubit, BatchState>(
      buildWhen: (previous, current) =>
          previous.openCount != current.openCount ||
          previous.lastFilePath != current.lastFilePath ||
          previous.saving != current.saving,
      builder: (context, state) {
        final path = state.lastFilePath;
        if (state.openCount == 0 || path == null) {
          return const DashedBorder(
            key: ValueKey('empty-batch'),
            color: CameraColors.onCameraVariant,
            child: SizedBox.square(
              dimension: 56,
              child: Icon(
                Icons.photo_library_outlined,
                size: 22,
                color: CameraColors.onCameraVariant,
              ),
            ),
          );
        }
        final pixels = (56 * MediaQuery.devicePixelRatioOf(context)).round();
        return Semantics(
          label: '${state.openCount} in this batch',
          excludeSemantics: true,
          child: AnimatedOpacity(
            opacity: state.saving ? _savingOpacity : 1,
            duration: const Duration(milliseconds: 150),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(path),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    cacheWidth: pixels,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: CameraColors.surface,
                      child: SizedBox.square(dimension: 56),
                    ),
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    key: const ValueKey('batch-count'),
                    constraints: const BoxConstraints(minWidth: 24),
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: CameraColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CameraColors.background,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${state.openCount}',
                      style: const TextStyle(
                        color: CameraColors.onCamera,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Takes a photo into the open batch; shows the busy look while it is saved (C6).
class _ShutterButton extends StatelessWidget {
  const _ShutterButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BatchCubit, BatchState, bool>(
      selector: (state) => state.saving,
      builder: (context, saving) => Semantics(
        button: true,
        enabled: !saving,
        label: 'Take photo',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: saving
              ? null
              : () => context.read<BatchCubit>().capture(
                  context.read<CameraCubit>().takePicture,
                ),
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: saving
                    ? CameraColors.shutterBusyRing
                    : CameraColors.onCamera,
                width: 4,
              ),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: saving ? 50 : 62,
              height: saving ? 50 : 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: saving
                    ? CameraColors.shutterBusyFill
                    : CameraColors.onCamera,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// UPLOAD BATCH (n). Looks disabled when empty but still answers, so it can explain (C7).
class _UploadBatchButton extends StatelessWidget {
  const _UploadBatchButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BatchCubit, BatchState>(
      buildWhen: (previous, current) =>
          previous.openCount != current.openCount ||
          previous.saving != current.saving,
      builder: (context, state) {
        final active = state.openCount > 0 && !state.saving;
        final foreground = active
            ? CameraColors.onCamera
            : CameraColors.onDisabledButton;
        return Semantics(
          button: true,
          enabled: !state.saving,
          label: 'Upload batch (${state.openCount})',
          excludeSemantics: true,
          child: Material(
            color: active ? CameraColors.primary : CameraColors.disabledButton,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: state.saving ? null : context.read<BatchCubit>().submit,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_rounded, size: 22, color: foreground),
                    const SizedBox(width: 10),
                    Text(
                      'UPLOAD BATCH (${state.openCount})',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
