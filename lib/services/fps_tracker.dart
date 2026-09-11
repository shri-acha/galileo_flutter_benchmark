import 'package:flutter/scheduler.dart';

/// Tracks runtime performance, frame timings, and live FPS for map benchmarks.
class BenchmarkMetrics {
  int? startupTimeMs;
  double currentFps = 0.0;
  double avgBuildTimeMs = 0.0;
  double avgRasterTimeMs = 0.0;
  int frameCount = 0;
  int jankCount = 0;

  final List<double> _recentFrameDurations = [];
  final List<double> _recentBuildDurations = [];
  final List<double> _recentRasterDurations = [];

  void setStartupTime(int ms) {
    startupTimeMs = ms;
  }

  void onFrameTiming(FrameTiming timing) {
    frameCount++;
    final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
    final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
    final totalMs = timing.totalSpan.inMicroseconds / 1000.0;

    if (totalMs > 16.67) {
      jankCount++;
    }

    _recentFrameDurations.add(totalMs);
    _recentBuildDurations.add(buildMs);
    _recentRasterDurations.add(rasterMs);

    if (_recentFrameDurations.length > 60) {
      _recentFrameDurations.removeAt(0);
      _recentBuildDurations.removeAt(0);
      _recentRasterDurations.removeAt(0);
    }

    if (frameCount % 15 == 0 && _recentFrameDurations.isNotEmpty) {
      final avgTotal =
          _recentFrameDurations.reduce((a, b) => a + b) / _recentFrameDurations.length;
      avgBuildTimeMs =
          _recentBuildDurations.reduce((a, b) => a + b) / _recentBuildDurations.length;
      avgRasterTimeMs =
          _recentRasterDurations.reduce((a, b) => a + b) / _recentRasterDurations.length;

      if (avgTotal > 0) {
        currentFps = (1000.0 / avgTotal).clamp(0.0, 144.0);
      }
    }
  }

  void reset() {
    frameCount = 0;
    jankCount = 0;
    currentFps = 0.0;
    avgBuildTimeMs = 0.0;
    avgRasterTimeMs = 0.0;
    _recentFrameDurations.clear();
    _recentBuildDurations.clear();
    _recentRasterDurations.clear();
  }
}
