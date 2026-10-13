import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'camera_service.dart';

/// [CameraService] backed by the `camera` plugin (CameraX on Android) and `permission_handler`.
class PluginCameraService implements CameraService {
  const PluginCameraService();

  // Must match the channel name and method in MainActivity.kt.
  static const _deviceChannel = MethodChannel(
    'com.shafayatb.snapendance/device',
  );

  @override
  Future<CameraPermission> permission() async =>
      _map(await ph.Permission.camera.status);

  @override
  Future<CameraPermission> requestPermission() async =>
      _map(await ph.Permission.camera.request());

  CameraPermission _map(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited) return CameraPermission.granted;
    // Android reports a permanent denial only as the answer to a request.
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermission.permanentlyDenied;
    }
    return CameraPermission.denied;
  }

  @override
  Future<void> openAppSettings() => ph.openAppSettings();

  @override
  Future<bool> hasFlash() async {
    try {
      return await _deviceChannel.invokeMethod<bool>('hasCameraFlash') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<CameraSession> open() async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (error) {
      throw CameraUnavailableException(error.description ?? error.code);
    }
    final back = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (back.isEmpty) throw const CameraUnavailableException('No back camera');

    final controller = CameraController(
      back.first,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      return _PluginCameraSession(controller, minZoom, maxZoom);
    } on CameraException catch (error) {
      await controller.dispose();
      throw CameraUnavailableException(error.description ?? error.code);
    } catch (error) {
      // The plugin also fails with plain errors (a null check, seen on the A04s when two opens
      // overlapped); the screen offers Try again instead of waiting forever.
      await controller.dispose();
      throw CameraUnavailableException('$error');
    }
  }
}

class _PluginCameraSession implements CameraSession {
  _PluginCameraSession(this._controller, this.minZoom, this.maxZoom);

  final CameraController _controller;

  @override
  final double minZoom;

  @override
  final double maxZoom;

  @override
  bool get focusPointSupported => _controller.value.focusPointSupported;

  // The plugin reports the sensor's landscape ratio; the app is portrait-only (plan C2).
  @override
  double get previewAspectRatio => 1 / _controller.value.aspectRatio;

  @override
  Widget buildPreview() => CameraPreview(_controller);

  @override
  Future<void> setZoom(double zoom) => _controller.setZoomLevel(zoom);

  @override
  Future<void> setFlash(CameraFlash flash) =>
      _controller.setFlashMode(switch (flash) {
        CameraFlash.off => FlashMode.off,
        CameraFlash.auto => FlashMode.auto,
        CameraFlash.on => FlashMode.always,
      });

  @override
  Future<void> focusAt(Offset point) async {
    await _controller.setFocusPoint(point);
    if (_controller.value.exposurePointSupported) {
      await _controller.setExposurePoint(point);
    }
  }

  @override
  Future<String> takePicture() async {
    try {
      return (await _controller.takePicture()).path;
    } on CameraException catch (error) {
      throw CameraCaptureException(error.description ?? error.code);
    }
  }

  @override
  Future<void> close() => _controller.dispose();
}
