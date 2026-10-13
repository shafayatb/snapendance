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

/// A still could not be taken.
class CameraCaptureException implements Exception {
  const CameraCaptureException(this.message);

  final String message;

  @override
  String toString() => 'CameraCaptureException: $message';
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

/// What the page needs to draw an open camera's preview.
abstract interface class CameraPreviewSource {
  /// The preview's width ÷ height as shown in portrait.
  double get previewAspectRatio;

  Widget buildPreview();
}

/// An open camera. Closed with [close]; no method may be called after that.
abstract interface class CameraSession implements CameraPreviewSource {
  double get minZoom;
  double get maxZoom;
  bool get focusPointSupported;

  Future<void> setZoom(double zoom);

  Future<void> setFlash(CameraFlash flash);

  /// Focuses (and meters exposure, where supported) at [point], normalized on the full preview.
  Future<void> focusAt(Offset point);

  /// Takes a still with the current flash mode and returns its temporary file path. Throws
  /// [CameraCaptureException].
  Future<String> takePicture();

  Future<void> close();
}
