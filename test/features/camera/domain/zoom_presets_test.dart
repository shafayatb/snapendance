import 'package:flutter_test/flutter_test.dart';
import 'package:snapendance/features/camera/domain/zoom_presets.dart';

void main() {
  group('zoomPresets', () {
    test('a camera without zoom below 1.0 offers no 0.5x', () {
      expect(zoomPresets(minZoom: 1, maxZoom: 8), [1.0, 2.0, 5.0]);
    });

    test('an ultra-wide minimum is offered with its real value', () {
      expect(zoomPresets(minZoom: 0.6, maxZoom: 10), [
        0.6,
        1.0,
        2.0,
        5.0,
        10.0,
      ]);
    });

    test('a preset above the maximum is left out', () {
      expect(zoomPresets(minZoom: 1, maxZoom: 4), [1.0, 2.0]);
    });

    test('a camera without zoom offers only 1x', () {
      expect(zoomPresets(minZoom: 1, maxZoom: 1), [1.0]);
    });
  });

  group('clampZoom', () {
    test('keeps a value inside the range', () {
      expect(clampZoom(3, minZoom: 1, maxZoom: 8), 3);
    });

    test('limits values outside the range', () {
      expect(clampZoom(0.2, minZoom: 1, maxZoom: 8), 1);
      expect(clampZoom(20, minZoom: 1, maxZoom: 8), 8);
    });
  });

  group('formatZoom', () {
    test('drops a trailing zero and keeps one decimal otherwise', () {
      expect(formatZoom(1), '1×');
      expect(formatZoom(0.6), '0.6×');
      expect(formatZoom(2.54), '2.5×');
    });
  });
}
