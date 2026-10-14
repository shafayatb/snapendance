List<double> zoomPresets({required double minZoom, required double maxZoom}) {
  return [
    if (minZoom < 1) minZoom,
    for (final preset in const [1.0, 2.0, 5.0, 10.0])
      if (preset >= minZoom && preset <= maxZoom) preset,
  ];
}

double clampZoom(
  double zoom, {
  required double minZoom,
  required double maxZoom,
}) {
  return zoom.clamp(minZoom, maxZoom).toDouble();
}

String formatZoom(double zoom) {
  final tenths = (zoom * 10).round();
  final text = tenths % 10 == 0
      ? '${tenths ~/ 10}'
      : (tenths / 10).toStringAsFixed(1);
  return '$text×';
}
