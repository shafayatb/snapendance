import 'dart:math' as math;
import 'dart:ui';

/// Maps a tap in the camera view to a normalized point (0-1) on the full preview.
///
/// The preview is scaled to cover the view, so part of it is cropped on two sides. The focus
/// API expects a point on the whole, uncropped preview in display orientation (CameraX's
/// display-oriented metering point factory), so the crop is added back here. [previewAspectRatio]
/// is the preview's width ÷ height as displayed (portrait).
Offset mapTapToPreviewPoint(Offset tap, Size view, double previewAspectRatio) {
  final viewAspect = view.width / view.height;
  // Cover: the preview fills the view in its tighter dimension and overflows the other.
  final Size shown = viewAspect > previewAspectRatio
      ? Size(view.width, view.width / previewAspectRatio)
      : Size(view.height * previewAspectRatio, view.height);
  final cropX = (shown.width - view.width) / 2;
  final cropY = (shown.height - view.height) / 2;
  final x = tap.dx.clamp(0, view.width) + cropX;
  final y = tap.dy.clamp(0, view.height) + cropY;
  return Offset(
    math.min(math.max(x / shown.width, 0), 1),
    math.min(math.max(y / shown.height, 0), 1),
  );
}
