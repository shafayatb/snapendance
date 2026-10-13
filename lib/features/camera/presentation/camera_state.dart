import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../data/camera_service.dart';

enum CameraStatus {
  initializing,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
  ready,
}

/// Where the focus ring is drawn (view pixels). [serial] restarts its animation on a new tap.
class FocusMarker extends Equatable {
  const FocusMarker(this.position, this.serial);

  final Offset position;
  final int serial;

  @override
  List<Object> get props => [position, serial];
}

enum CameraNoticeKind { flashUnavailable, focusUnsupported }

/// A one-off toast. [serial] makes a repeated notice a new state.
class CameraNotice extends Equatable {
  const CameraNotice(this.kind, this.serial);

  final CameraNoticeKind kind;
  final int serial;

  @override
  List<Object> get props => [kind, serial];
}

class CameraState extends Equatable {
  const CameraState({
    this.status = CameraStatus.initializing,
    this.zoom = 1,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.presets = const [1],
    this.flash = CameraFlash.off,
    this.flashAvailable = false,
    this.focusSupported = false,
    this.focusMarker,
    this.notice,
  });

  final CameraStatus status;

  /// The one zoom value shared by pinch, slider, and buttons (plan C4).
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final List<double> presets;
  final CameraFlash flash;
  final bool flashAvailable;
  final bool focusSupported;
  final FocusMarker? focusMarker;
  final CameraNotice? notice;

  CameraState copyWith({
    CameraStatus? status,
    double? zoom,
    double? minZoom,
    double? maxZoom,
    List<double>? presets,
    CameraFlash? flash,
    bool? flashAvailable,
    bool? focusSupported,
    FocusMarker? focusMarker,
    CameraNotice? notice,
  }) {
    return CameraState(
      status: status ?? this.status,
      zoom: zoom ?? this.zoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      presets: presets ?? this.presets,
      flash: flash ?? this.flash,
      flashAvailable: flashAvailable ?? this.flashAvailable,
      focusSupported: focusSupported ?? this.focusSupported,
      focusMarker: focusMarker ?? this.focusMarker,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
    status,
    zoom,
    minZoom,
    maxZoom,
    presets,
    flash,
    flashAvailable,
    focusSupported,
    focusMarker,
    notice,
  ];
}
