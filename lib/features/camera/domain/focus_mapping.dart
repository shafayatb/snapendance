import 'dart:math' as math;
import 'dart:ui';

Offset mapTapToPreviewPoint(Offset tap, Size view, double previewAspectRatio) {
  final viewAspect = view.width / view.height;
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
