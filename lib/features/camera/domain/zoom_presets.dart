/// Zoom ratios offered as buttons (design C1, C4).
///
/// The camera's minimum is offered when it is below 1.0 (an ultra-wide lens behind CameraX's
/// logical camera), labeled with its real value rather than a made-up "0.5×". The other presets
/// are offered only when the camera can reach them.
List<double> zoomPresets({required double minZoom, required double maxZoom}) {
  return [
    if (minZoom < 1) minZoom,
    for (final preset in const [1.0, 2.0, 5.0, 10.0])
      if (preset >= minZoom && preset <= maxZoom) preset,
  ];
}

/// [zoom] limited to the active camera's range.
double clampZoom(
  double zoom, {
  required double minZoom,
  required double maxZoom,
}) {
  return zoom.clamp(minZoom, maxZoom).toDouble();
}

/// "1×", "0.6×", "2.5×": one decimal, without a trailing ".0".
String formatZoom(double zoom) {
  final tenths = (zoom * 10).round();
  final text = tenths % 10 == 0
      ? '${tenths ~/ 10}'
      : (tenths / 10).toStringAsFixed(1);
  return '$text×';
}
