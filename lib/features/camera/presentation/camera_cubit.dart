import 'dart:async';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/camera_service.dart';
import '../domain/focus_mapping.dart';
import '../domain/zoom_presets.dart';
import 'camera_state.dart';

class CameraCubit extends Cubit<CameraState> {
  CameraCubit(this._service) : super(const CameraState());

  final CameraService _service;
  CameraSession? _session;
  int _generation = 0;
  int _noticeSerial = 0;
  int _focusSerial = 0;
  double _pinchBase = 1;

  bool _awaitingPermissionAnswer = false;

  bool _covered = false;

  Future<void>? _opening;
  int? _openingGeneration;

  bool get isCovered => _covered;

  CameraPreviewSource? get preview => _session;

  Future<void> start() => _open(askForPermission: true);

  Future<void> retry() => _open(askForPermission: true);

  Future<void> openAppSettings() => _service.openAppSettings();

  Future<void> appPaused() => _release(keepBlockedState: false);

  Future<void> appResumed() async {
    if (_covered ||
        _session != null ||
        _awaitingPermissionAnswer ||
        _openingGeneration == _generation) {
      return;
    }
    await _open(askForPermission: false);
  }

  Future<void> screenCovered() {
    _covered = true;
    return _release(keepBlockedState: true);
  }

  Future<void> screenUncovered() {
    _covered = false;
    return appResumed();
  }

  Future<void> _release({required bool keepBlockedState}) async {
    final generation = ++_generation;
    await _releaseSession();
    if (generation != _generation || isClosed) return;
    if (keepBlockedState && state.status != CameraStatus.ready) return;
    emit(const CameraState());
  }

  Future<void> _open({required bool askForPermission}) async {
    final generation = ++_generation;
    await _releaseSession();
    final previous = _opening;
    final done = Completer<void>();
    _opening = done.future;
    _openingGeneration = generation;
    try {
      await previous;
      if (generation != _generation || isClosed) return;
      await _openCamera(generation, askForPermission: askForPermission);
    } finally {
      if (_openingGeneration == generation) _openingGeneration = null;
      if (identical(_opening, done.future)) _opening = null;
      done.complete();
    }
  }

  Future<void> _openCamera(
    int generation, {
    required bool askForPermission,
  }) async {
    var permission = await _service.permission();
    if (permission == CameraPermission.denied && askForPermission) {
      _awaitingPermissionAnswer = true;
      try {
        permission = await _service.requestPermission();
      } finally {
        _awaitingPermissionAnswer = false;
      }
    }
    if (generation != _generation || isClosed) return;
    switch (permission) {
      case CameraPermission.denied:
        if (!askForPermission &&
            state.status == CameraStatus.permissionPermanentlyDenied) {
          return;
        }
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

  void setZoom(double zoom) {
    final session = _session;
    if (session == null || state.status != CameraStatus.ready) return;
    final clamped = clampZoom(
      zoom,
      minZoom: state.minZoom,
      maxZoom: state.maxZoom,
    );
    emit(state.copyWith(zoom: clamped));
    session.setZoom(clamped).ignore();
  }

  void pinchStarted() => _pinchBase = state.zoom;

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

  Future<String> takePicture() {
    final session = _session;
    if (session == null || state.status != CameraStatus.ready) {
      return Future.error(const CameraCaptureException('Camera not ready'));
    }
    return session.takePicture();
  }

  @override
  Future<void> close() async {
    _generation++;
    await _releaseSession();
    return super.close();
  }
}
