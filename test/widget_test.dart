import 'package:flutter_test/flutter_test.dart';
import 'package:galileo_flutter_benchmark/models/moving_point.dart';
import 'package:galileo_flutter_benchmark/services/fps_tracker.dart';

void main() {
  group('MovingPoint benchmark tests', () {
    test('createTokyoPoints initializes 10 unique points', () {
      final points = MovingPoint.createTokyoPoints();
      expect(points.length, equals(10));

      final ids = points.map((p) => p.id).toSet();
      expect(ids.length, equals(10));
    });

    test('createTokyoPoints supports arbitrary benchmark sizes', () {
      final points = MovingPoint.createTokyoPoints(count: 1000);
      expect(points.length, equals(1000));
      expect(points.map((p) => p.id).toSet().length, equals(1000));
    });

    test('points update position over time', () {
      final points = MovingPoint.createTokyoPoints();
      final initialLat = points.first.currentLat;
      final initialLng = points.first.currentLng;

      // Advance by 1.0 second
      for (final p in points) {
        p.update(1.0, 1.0);
      }

      expect(points.first.currentLat, isNot(equals(initialLat)));
      expect(points.first.currentLng, isNot(equals(initialLng)));
    });
  });

  group('BenchmarkMetrics tests', () {
    test('records startup time correctly', () {
      final metrics = BenchmarkMetrics();
      expect(metrics.startupTimeMs, isNull);

      metrics.setStartupTime(142);
      expect(metrics.startupTimeMs, equals(142));
    });
  });
}
