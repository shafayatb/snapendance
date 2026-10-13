import 'package:flutter/widgets.dart';

/// The app's access to the camera permission.
enum CameraPermission { granted, denied, permanentlyDenied }

/// Flash modes offered for still capture (plan C5).
enum CameraFlash { off, auto, on }

/// The camera could not be opened: none present, in use, or failed to start.
class CameraUnavailableException implements Exception {
  const CameraUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'CameraUnavailableException: $message';
}

/// Boundary around the camera plugin and permission APIs, so [CameraCubit] can be tested with
/// fakes.
abstract interface class CameraService {
  Future<CameraPermission> permission();

  /// Shows the system dialog when Android still allows it.
  Future<CameraPermission> requestPermission();

  Future<void> openAppSettings();

  /// Whether the device has a flash unit. The plugin cannot tell.
  Future<bool> hasFlash();

  /// Opens the first back camera. Throws [CameraUnavailableException].
  Future<CameraSession> open();
}

/// An open camera. Closed with [close]; no method may be called after that.
abstract interface class CameraSession {
  double get minZoom;
  double get maxZoom;
  bool get focusPointSupported;

  /// The preview's width ÷ height as shown in portrait.
  double get previewAspectRatio;

  Widget buildPreview();

  Future<void> setZoom(double zoom);

  Future<void> setFlash(CameraFlash flash);

  /// Focuses (and meters exposure, where supported) at [point], normalized on the full preview.
  Future<void> focusAt(Offset point);

  Future<void> close();
}
