import 'dart:io';

class BenchmarkLogger {
  static const header =
      'timestamp,engine,point_count,startup_ms,cpu_percent,gpu_percent,gpu_mem_mb,rss_mb,avg_fps,jank_frames';

  final File file = File('logs/benchmark_results.csv');

  Future<void> init() async {
    await Directory('logs').create(recursive: true);
    if (!await file.exists()) {
      await file.writeAsString('$header\n');
    }
  }

  Future<void> append({
    required String engine,
    required int pointCount,
    required int startupMs,
    required double cpuPercent,
    required double gpuPercent,
    required double gpuMemMb,
    required double rssMb,
    required double avgFps,
    required int jankFrames,
  }) async {
    final row = [
      DateTime.now().toIso8601String(),
      engine,
      pointCount,
      startupMs,
      cpuPercent.toStringAsFixed(2),
      gpuPercent.toStringAsFixed(2),
      gpuMemMb.toStringAsFixed(2),
      rssMb.toStringAsFixed(2),
      avgFps.toStringAsFixed(2),
      jankFrames,
    ].join(',');
    await file.writeAsString('$row\n', mode: FileMode.append);
  }
}
