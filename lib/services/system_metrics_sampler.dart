import 'dart:io';

class SystemSample {
  final double cpuPercent;
  final double gpuPercent;
  final double gpuMemMb;
  final double rssMb;

  const SystemSample({
    required this.cpuPercent,
    required this.gpuPercent,
    required this.gpuMemMb,
    required this.rssMb,
  });
}

/// Samples Linux process CPU, system GPU busy/VRAM, and Dart RSS.
///
/// GPU readings are whole-device values, not this process only.
class SystemMetricsSampler {
  final List<File> _gpuBusyFiles = [];
  final List<File> _gpuMemFiles = [];

  int _clockTicks = 100;
  int? _lastCpuTicks;
  DateTime? _lastCpuWall;

  Future<void> reset() async {
    _clockTicks = await _readClockTicks();
    _findGpuFiles();
    _lastCpuTicks = await _readCpuTicks();
    _lastCpuWall = DateTime.now();
  }

  Future<SystemSample> sample() async {
    final now = DateTime.now();
    final cpuTicks = await _readCpuTicks();
    var cpuPercent = 0.0;

    final lastTicks = _lastCpuTicks;
    final lastWall = _lastCpuWall;
    if (lastTicks != null && lastWall != null && cpuTicks >= lastTicks) {
      final elapsedSeconds =
          now.difference(lastWall).inMicroseconds /
          Duration.microsecondsPerSecond;
      if (elapsedSeconds > 0) {
        cpuPercent =
            (cpuTicks - lastTicks) / _clockTicks / elapsedSeconds * 100.0;
      }
    }

    _lastCpuTicks = cpuTicks;
    _lastCpuWall = now;

    final gpuPercent = await _readMaxGpuPercent();
    final gpuMemMb = await _readGpuMemMb();
    final rssMb = ProcessInfo.currentRss / (1024 * 1024);

    return SystemSample(
      cpuPercent: cpuPercent,
      gpuPercent: gpuPercent,
      gpuMemMb: gpuMemMb,
      rssMb: rssMb,
    );
  }

  Future<int> _readClockTicks() async {
    try {
      final result = await Process.run('getconf', const ['CLK_TCK']);
      if (result.exitCode == 0) {
        return int.tryParse((result.stdout as String).trim()) ?? 100;
      }
    } catch (_) {}
    return 100;
  }

  void _findGpuFiles() {
    _gpuBusyFiles.clear();
    _gpuMemFiles.clear();

    try {
      final drmDir = Directory('/sys/class/drm');
      if (!drmDir.existsSync()) return;

      for (final entity in drmDir.listSync(followLinks: false)) {
        final name = entity.path.split('/').last;
        if (!RegExp(r'^card\d+$').hasMatch(name)) continue;

        final busyFile = File('${entity.path}/device/gpu_busy_percent');
        final memFile = File('${entity.path}/device/mem_info_vram_used');
        if (busyFile.existsSync()) _gpuBusyFiles.add(busyFile);
        if (memFile.existsSync()) _gpuMemFiles.add(memFile);
      }
    } catch (_) {}
  }

  Future<int> _readCpuTicks() async {
    try {
      final stat = await File('/proc/self/stat').readAsString();
      final closeParen = stat.lastIndexOf(')');
      if (closeParen == -1 || closeParen + 1 >= stat.length) return 0;

      final fields = stat.substring(closeParen + 2).split(' ');
      if (fields.length <= 12) return 0;
      final utime = int.tryParse(fields[11]) ?? 0;
      final stime = int.tryParse(fields[12]) ?? 0;
      return utime + stime;
    } catch (_) {
      return 0;
    }
  }

  Future<double> _readMaxGpuPercent() async {
    if (_gpuBusyFiles.isEmpty) return -1;

    var maxPercent = 0.0;
    for (final file in _gpuBusyFiles) {
      try {
        final value = double.tryParse((await file.readAsString()).trim()) ?? 0;
        if (value > maxPercent) maxPercent = value;
      } catch (_) {}
    }
    return maxPercent;
  }

  Future<double> _readGpuMemMb() async {
    if (_gpuMemFiles.isEmpty) return -1;

    var totalBytes = 0;
    for (final file in _gpuMemFiles) {
      try {
        totalBytes += int.tryParse((await file.readAsString()).trim()) ?? 0;
      } catch (_) {}
    }
    return totalBytes / (1024 * 1024);
  }
}
