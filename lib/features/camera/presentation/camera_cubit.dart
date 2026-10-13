import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/camera_service.dart';
import '../domain/focus_mapping.dart';
import '../domain/zoom_presets.dart';
import 'camera_state.dart';

/// Camera preview state: permission, the open camera's lifecycle, zoom, flash, and focus.
///
/// The camera is opened by [start], released by [appPaused] and [close], and reopened by
/// [appResumed]. Each open has a generation number, so a camera that finishes opening after the
/// app left is closed instead of shown.
class CameraCubit extends Cubit<CameraState> {
  CameraCubit(this._service) : super(const CameraState());

  final CameraService _service;
  CameraSession? _session;
  int _generation = 0;
  int _noticeSerial = 0;
  int _focusSerial = 0;
  double _pinchBase = 1;

  /// Opens the camera, asking for permission first if Android still allows it.
  Future<void> start() => _open(askForPermission: true);

  /// The blocked state's button: asks again or retries a camera that failed to open.
  Future<void> retry() => _open(askForPermission: true);

  Future<void> openAppSettings() => _service.openAppSettings();

  /// The app went to the background: other apps (and the native attendance screen) may need
  /// the camera.
  Future<void> appPaused() async {
    _generation++;
    await _releaseSession();
    if (!isClosed) emit(const CameraState());
  }

  /// Back from the background or app settings. Permission is checked, not requested, so a
  /// refusal does not bring the dialog straight back.
  Future<void> appResumed() async {
    if (_session != null) return;
    await _open(askForPermission: false);
  }

  Future<void> _open({required bool askForPermission}) async {
    final generation = ++_generation;
    await _releaseSession();
    var permission = await _service.permission();
    if (permission == CameraPermission.denied && askForPermission) {
      permission = await _service.requestPermission();
    }
    if (generation != _generation || isClosed) return;
    switch (permission) {
      case CameraPermission.denied:
        emit(const CameraState(status: CameraStatus.permissionDenied));
        return;
      case CameraPermission.permanentlyDenied:
        emit(
          const CameraState(status: CameraStatus.permissionPermanentlyDenied),
        );
        return;
      case CameraPermission.granted:
        break;
    }

    final CameraSession session;
    final bool hasFlash;
    try {
      session = await _service.open();
      hasFlash = await _service.hasFlash();
    } on CameraUnavailableException {
      if (generation == _generation && !isClosed) {
        emit(const CameraState(status: CameraStatus.unavailable));
      }
      return;
    }
    // The app left, or another open started, while this one was in progress.
    if (generation != _generation || isClosed) {
      await session.close();
      return;
    }
    _session = session;
    emit(
      CameraState(
        status: CameraStatus.ready,
        zoom: clampZoom(1, minZoom: session.minZoom, maxZoom: session.maxZoom),
        minZoom: session.minZoom,
        maxZoom: session.maxZoom,
        presets: zoomPresets(
          minZoom: session.minZoom,
          maxZoom: session.maxZoom,
        ),
        flashAvailable: hasFlash,
        focusSupported: session.focusPointSupported,
      ),
    );
  }

  Future<void> _releaseSession() async {
    final session = _session;
    _session = null;
    await session?.close();
  }

  /// Sets the zoom from the slider or a preset button.
  void setZoom(double zoom) {
    final session = _session;
    if (session == null || state.status != CameraStatus.ready) return;
    final clamped = clampZoom(
      zoom,
      minZoom: state.minZoom,
      maxZoom: state.maxZoom,
    );
    emit(state.copyWith(zoom: clamped));
    // The newest value wins; a failed call leaves the preview at its last zoom.
    session.setZoom(clamped).ignore();
  }

  void pinchStarted() => _pinchBase = state.zoom;

  /// [scale] is the pinch's total scale since [pinchStarted].
  void pinchUpdated(double scale) => setZoom(_pinchBase * scale);

  void cycleFlash() {
    final session = _session;
    if (session == null || state.status != CameraStatus.ready) return;
    if (!state.flashAvailable) {
      emit(
        state.copyWith(
          notice: CameraNotice(
            CameraNoticeKind.flashUnavailable,
            ++_noticeSerial,
          ),
        ),
      );
      return;
    }
    final next = switch (state.flash) {
      CameraFlash.off => CameraFlash.auto,
      CameraFlash.auto => CameraFlash.on,
      CameraFlash.on => CameraFlash.off,
    };
    emit(state.copyWith(flash: next));
    session.setFlash(next).ignore();
  }

  /// A tap at [tap] in a camera view of [view] size.
  void tapToFocus(Offset tap, Size view) {
    final session = _session;
    if (session == null || state.status != CameraStatus.ready) return;
    if (!state.focusSupported) {
      emit(
        state.copyWith(
          notice: CameraNotice(
            CameraNoticeKind.focusUnsupported,
            ++_noticeSerial,
          ),
        ),
      );
      return;
    }
    emit(state.copyWith(focusMarker: FocusMarker(tap, ++_focusSerial)));
    session
        .focusAt(mapTapToPreviewPoint(tap, view, session.previewAspectRatio))
        .ignore();
  }

  @override
  Future<void> close() async {
    _generation++;
    await _releaseSession();
    return super.close();
  }
}
