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
        scaffoldBackgroundColor: const Color(0xFF09090B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF18181B),
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
      backgroundColor: const Color(0xFF09090B),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF18181B),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFF27272A),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Minimal title
              const Text(
                'BENCHMARK: 10 MOVING POINTS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Galileo vs Flutter Map',
                style: TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 12,
                ),
              ),

              const Spacer(),

              // Startup comparison banner
              if (gStartup != null || fStartup != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Startup: ',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Galileo ${gStartup != null && gStartup > 0 ? '$gStartup ms' : '...'}',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Text(
                        '  |  ',
                        style: TextStyle(color: Color(0xFF52525B), fontSize: 11),
                      ),
                      Text(
                        'FlutterMap ${fStartup != null && fStartup > 0 ? '$fStartup ms' : '...'}',
                        style: const TextStyle(
                          color: Color(0xFFA78BFA),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(width: 12),

              // Speed selector
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(4),
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

              const SizedBox(width: 8),

              // Play / Pause Toggle
              InkWell(
                onTap: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Reload Button
              InkWell(
                onTap: _reloadBenchmark,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Row(
        key: ValueKey(_benchmarkKeyIndex),
        children: [
          // Left: Galileo Flutter
          Expanded(
            child: ClipRect(
              child: GalileoSplitView(
                points: _points,
                metrics: _galileoMetrics,
              ),
            ),
          ),

          // Clean 1px divider
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: Color(0xFF27272A),
          ),

          // Right: Flutter Map
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
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3F3F46) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
