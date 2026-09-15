import 'dart:async';

import 'package:flutter/material.dart';

import 'maps/flutter_map_split_view.dart';
import 'maps/galileo_overlay_split_view.dart';
import 'models/moving_point.dart';
import 'services/benchmark_logger.dart';
import 'services/fps_tracker.dart';
import 'services/system_metrics_sampler.dart';

class _Scenario {
  final int pointCount;
  final String engine;

  const _Scenario(this.pointCount, this.engine);
}

class BenchmarkRunnerScreen extends StatefulWidget {
  const BenchmarkRunnerScreen({super.key});

  @override
  State<BenchmarkRunnerScreen> createState() => _BenchmarkRunnerScreenState();
}

class _BenchmarkRunnerScreenState extends State<BenchmarkRunnerScreen> {
  static const _pointCounts = [1000, 10000, 100000];
  static const _engines = ['flutter_map', 'galileo_overlay'];
  static const _measurementDuration = Duration(seconds: 5);

  final BenchmarkLogger _logger = BenchmarkLogger();
  final SystemMetricsSampler _sampler = SystemMetricsSampler();
  final List<SystemSample> _samples = [];

  late final List<_Scenario> _scenarios = [
    for (final count in _pointCounts)
      for (final engine in _engines) _Scenario(count, engine),
  ];

  int _scenarioIndex = -1;
  int _lastPointCount = -1;
  List<MovingPoint> _points = const [];
  BenchmarkMetrics _metrics = BenchmarkMetrics();
  Timer? _sampleTimer;
  Timer? _finishTimer;
  Timer? _startupTimeoutTimer;
  bool _measuring = false;
  bool _finished = false;
  String _status = 'Starting benchmark...';

  @override
  void initState() {
    super.initState();
    _startNextScenario();
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    _finishTimer?.cancel();
    _startupTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _startNextScenario() async {
    if (_scenarioIndex >= _scenarios.length - 1) {
      if (mounted) {
        setState(() {
          _finished = true;
          _status = 'Benchmark complete. Results logged to logs/benchmark_results.csv';
        });
      }
      return;
    }

    _scenarioIndex++;
    final scenario = _scenarios[_scenarioIndex];
    if (scenario.pointCount != _lastPointCount) {
      _points = MovingPoint.createTokyoPoints(count: scenario.pointCount);
      _lastPointCount = scenario.pointCount;
    }
    _metrics = BenchmarkMetrics();
    _samples.clear();
    _measuring = false;
    _sampleTimer?.cancel();
    _finishTimer?.cancel();
    _startupTimeoutTimer?.cancel();

    if (mounted) {
      setState(() {
        _status =
            'Running ${scenario.engine} @ ${scenario.pointCount} points...';
      });
    }

    // ponytail: coarse 120s guard so one failed map init can't strand the CSV run.
    _startupTimeoutTimer = Timer(const Duration(seconds: 120), () {
      if (mounted && !_measuring) {
        _finishScenario();
      }
    });
  }

  void _onMapReady() {
    if (_measuring || _finished || _scenarioIndex < 0) return;
    _measuring = true;
    _startupTimeoutTimer?.cancel();
    _sampler.reset();

    _sampleTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      _samples.add(await _sampler.sample());
    });

    _finishTimer = Timer(_measurementDuration, _finishScenario);
  }

  Future<void> _finishScenario() async {
    _sampleTimer?.cancel();
    _startupTimeoutTimer?.cancel();
    if (!mounted) return;

    final scenario = _scenarios[_scenarioIndex];
    final cpu = _average((s) => s.cpuPercent);
    final gpu = _average((s) => s.gpuPercent);
    final gpuMem = _average((s) => s.gpuMemMb);
    final rss = _average((s) => s.rssMb);
    final startup = _metrics.startupTimeMs ?? 0;

    try {
      await _logger.init();
      await _logger.append(
        engine: scenario.engine,
        pointCount: scenario.pointCount,
        startupMs: startup,
        cpuPercent: cpu,
        gpuPercent: gpu,
        gpuMemMb: gpuMem,
        rssMb: rss,
        avgFps: _metrics.currentFps,
        jankFrames: _metrics.jankCount,
      );
    } catch (e) {
      debugPrint('Failed to write benchmark log: $e');
    }

    // Give the previous large widget tree a beat to unwind before the next run.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await _startNextScenario();
    }
  }

  double _average(double Function(SystemSample) selector) {
    if (_samples.isEmpty) return 0;
    return _samples.map(selector).reduce((a, b) => a + b) / _samples.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: Center(
          child: Text(
            _status,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final scenario = _scenarioIndex >= 0 ? _scenarios[_scenarioIndex] : null;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        title: Text(
          _status,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
      body: scenario == null
          ? const SizedBox.shrink()
          : ClipRect(
              child: KeyedSubtree(
                key: ValueKey(
                  '${scenario.engine}-${scenario.pointCount}-$_scenarioIndex',
                ),
                child: scenario.engine == 'flutter_map'
                    ? FlutterMapSplitView(
                        points: _points,
                        metrics: _metrics,
                        onReady: _onMapReady,
                      )
                    : GalileoOverlaySplitView(
                        points: _points,
                        metrics: _metrics,
                        onReady: _onMapReady,
                      ),
              ),
            ),
    );
  }
}
