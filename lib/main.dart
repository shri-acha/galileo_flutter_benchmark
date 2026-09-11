import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:galileo_flutter/galileo_flutter.dart';
import 'maps/flutter_map_split_view.dart';
import 'maps/galileo_split_view.dart';
import 'models/moving_point.dart';
import 'services/fps_tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception is AssertionError &&
        details.exception.toString().contains('KeyDownEvent is dispatched')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  try {
    await initGalileo();
  } catch (e) {
    debugPrint('initGalileo initialization notice: $e');
  }

  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galileo Flutter vs Flutter Map Benchmark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF0F172A),
        ),
      ),
      home: const SplitBenchmarkScreen(),
    );
  }
}

class SplitBenchmarkScreen extends StatefulWidget {
  const SplitBenchmarkScreen({super.key});

  @override
  State<SplitBenchmarkScreen> createState() => _SplitBenchmarkScreenState();
}

class _SplitBenchmarkScreenState extends State<SplitBenchmarkScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration? _lastElapsed;

  List<MovingPoint> _points = MovingPoint.createTokyoPoints();
  bool _isPlaying = true;
  double _speedMultiplier = 1.0;

  final BenchmarkMetrics _galileoMetrics = BenchmarkMetrics();
  final BenchmarkMetrics _flutterMapMetrics = BenchmarkMetrics();

  int _benchmarkKeyIndex = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying) {
      _lastElapsed = elapsed;
      return;
    }

    if (_lastElapsed != null) {
      final delta = (elapsed - _lastElapsed!).inMicroseconds / 1000000.0;
      if (delta > 0 && delta < 0.2) {
        for (final point in _points) {
          point.update(delta, _speedMultiplier);
        }
        setState(() {});
      }
    }
    _lastElapsed = elapsed;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _reloadBenchmark() {
    setState(() {
      _benchmarkKeyIndex++;
      _points = MovingPoint.createTokyoPoints();
      _galileoMetrics.reset();
      _flutterMapMetrics.reset();
      _galileoMetrics.setStartupTime(0);
      _flutterMapMetrics.setStartupTime(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gStartup = _galileoMetrics.startupTimeMs;
    final fStartup = _flutterMapMetrics.startupTimeMs;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Logo & Title
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: Color(0xFF38BDF8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'MAP BENCHMARK: 10 MOVING POINTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Galileo Flutter (Rust/WebGPU) vs Flutter Map (Dart/Canvas)',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Startup Comparison Banner in top app bar
              if (gStartup != null || fStartup != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      const Text(
                        'Startup Time: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Galileo: ${gStartup != null && gStartup > 0 ? '$gStartup ms' : '...'}',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Text(
                        '  vs  ',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      Text(
                        'FlutterMap: ${fStartup != null && fStartup > 0 ? '$fStartup ms' : '...'}',
                        style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(width: 16),

              // Speed selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildSpeedButton('0.5x', 0.5),
                    _buildSpeedButton('1x', 1.0),
                    _buildSpeedButton('2x', 2.0),
                    _buildSpeedButton('4x', 4.0),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Play / Pause Toggle
              IconButton.filled(
                onPressed: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                  });
                },
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _isPlaying
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                tooltip: _isPlaying ? 'Pause Movement' : 'Resume Movement',
              ),

              const SizedBox(width: 8),

              // Re-run / Reload Benchmark
              IconButton.filled(
                onPressed: _reloadBenchmark,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFF38BDF8),
                ),
                tooltip: 'Re-run Benchmark (Remount & Re-measure Startup)',
              ),
            ],
          ),
        ),
      ),
      body: Row(
        key: ValueKey(_benchmarkKeyIndex),
        children: [
          // Left: Galileo Flutter Split View
          Expanded(
            child: ClipRect(
              child: GalileoSplitView(
                points: _points,
                metrics: _galileoMetrics,
              ),
            ),
          ),

          // Central Divider Bar
          Container(
            width: 5,
            color: const Color(0xFF0F172A),
            child: Center(
              child: Container(
                width: 2,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Right: Flutter Map Split View
          Expanded(
            child: ClipRect(
              child: FlutterMapSplitView(
                points: _points,
                metrics: _flutterMapMetrics,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(String label, double speed) {
    final isSelected = _speedMultiplier == speed;
    return InkWell(
      onTap: () {
        setState(() {
          _speedMultiplier = speed;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
