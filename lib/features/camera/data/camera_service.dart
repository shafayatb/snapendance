import 'package:flutter/widgets.dart';

enum CameraPermission { granted, denied, permanentlyDenied }

enum CameraFlash { off, auto, on }

class CameraUnavailableException implements Exception {
  const CameraUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'CameraUnavailableException: $message';
}

class CameraCaptureException implements Exception {
  const CameraCaptureException(this.message);

  final String message;

  @override
  String toString() => 'CameraCaptureException: $message';
}

abstract interface class CameraService {
  Future<CameraPermission> permission();

  Future<CameraPermission> requestPermission();

  Future<void> openAppSettings();

  Future<bool> hasFlash();

  Future<CameraSession> open();
}

abstract interface class CameraPreviewSource {
  double get previewAspectRatio;

  Widget buildPreview();
}

abstract interface class CameraSession implements CameraPreviewSource {
  double get minZoom;
  double get maxZoom;
  bool get focusPointSupported;

  Future<void> setZoom(double zoom);

  Future<void> setFlash(CameraFlash flash);

  Future<void> focusAt(Offset point);

  Future<String> takePicture();

  Future<void> close();
}
