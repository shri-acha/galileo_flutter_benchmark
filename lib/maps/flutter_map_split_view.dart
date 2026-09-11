import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/moving_point.dart';
import '../services/fps_tracker.dart';
import '../widgets/benchmark_header.dart';
import '../widgets/point_tooltip_marker.dart';

/// Flutter Map half of the benchmark split view.
class FlutterMapSplitView extends StatefulWidget {
  final List<MovingPoint> points;
  final BenchmarkMetrics metrics;

  const FlutterMapSplitView({
    super.key,
    required this.points,
    required this.metrics,
  });

  @override
  State<FlutterMapSplitView> createState() => _FlutterMapSplitViewState();
}

class _FlutterMapSplitViewState extends State<FlutterMapSplitView> {
  final MapController _mapController = MapController();
  late final Stopwatch _startupStopwatch;
  bool _startupMeasured = false;

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted) return;
    for (final timing in timings) {
      widget.metrics.onFrameTiming(timing);
    }
  }

  @override
  void initState() {
    super.initState();
    _startupStopwatch = Stopwatch()..start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _mapController.dispose();
    super.dispose();
  }

  void _handleMapReady() {
    if (!_startupMeasured) {
      _startupMeasured = true;
      _startupStopwatch.stop();
      if (mounted) {
        setState(() {
          widget.metrics.setStartupTime(_startupStopwatch.elapsedMilliseconds);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Flutter Map
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(35.6812, 139.7671),
              initialZoom: 13.0,
              onMapReady: _handleMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.galileo_flutter_benchmark',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  for (final point in widget.points)
                    Marker(
                      point: LatLng(point.currentLat, point.currentLng),
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: PointTooltipMarker(
                        point: point,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Top Telemetry Header
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: BenchmarkHeader(
            title: 'Flutter Map',
            subtitle: 'Dart / Canvas • Widget Tree Layers',
            accentColor: const Color(0xFF8B5CF6), // Purple
            metrics: widget.metrics,
            activePointsCount: widget.points.length,
          ),
        ),
      ],
    );
  }
}
