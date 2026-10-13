import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapendance/features/camera/domain/focus_mapping.dart';

void main() {
  // A 3:4 portrait preview shown in a 400 × 800 view: cover scaling makes it 600 × 800, so
  // 100 px are cropped on each side.
  const view = Size(400, 800);
  const aspect = 3 / 4;

  test('the view centre maps to the preview centre', () {
    expect(
      mapTapToPreviewPoint(const Offset(200, 400), view, aspect),
      const Offset(0.5, 0.5),
    );
  });

  test('a tap at the left edge maps past the cropped strip', () {
    final point = mapTapToPreviewPoint(const Offset(0, 400), view, aspect);
    expect(point.dx, closeTo(100 / 600, 1e-9));
    expect(point.dy, 0.5);
  });

  test('a tap at the right edge maps before the cropped strip', () {
    final point = mapTapToPreviewPoint(const Offset(400, 0), view, aspect);
    expect(point.dx, closeTo(500 / 600, 1e-9));
    expect(point.dy, 0);
  });

  test(
    'a preview wider than the view crop is vertical when the view is wider',
    () {
      // 9:16 preview in a 400 × 600 view: 400 × 711.1, cropped 55.6 px top and bottom.
      final point = mapTapToPreviewPoint(
        const Offset(200, 0),
        const Size(400, 600),
        9 / 16,
      );
      expect(point.dx, 0.5);
      expect(
        point.dy,
        closeTo((400 * 16 / 9 - 600) / 2 / (400 * 16 / 9), 1e-9),
      );
    },
  );

  test('points outside the view are clamped to its edge', () {
    final point = mapTapToPreviewPoint(const Offset(-50, 900), view, aspect);
    expect(point.dx, closeTo(100 / 600, 1e-9));
    expect(point.dy, 1);
  });
}
