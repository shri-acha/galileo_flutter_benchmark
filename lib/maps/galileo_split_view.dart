import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:galileo_flutter/galileo_flutter.dart';
import '../models/moving_point.dart';
import '../services/fps_tracker.dart';
import '../widgets/benchmark_header.dart';
import '../widgets/point_tooltip_marker.dart';

/// Galileo Flutter map half of the benchmark split view.
class GalileoSplitView extends StatefulWidget {
  final List<MovingPoint> points;
  final BenchmarkMetrics metrics;

  const GalileoSplitView({
    super.key,
    required this.points,
    required this.metrics,
  });

  @override
  State<GalileoSplitView> createState() => _GalileoSplitViewState();
}

class _GalileoSplitViewState extends State<GalileoSplitView> {
  static const _kInitialSize = MapSize(width: 800, height: 600);
  final _kMapConfig = MapInitConfig(
    backgroundColor: const Color(0xFF0F172A).toGalileo(),
    enableMultisampling: true,
    latlon: const GeoLocation(latitude: 35.6812, longitude: 139.7671),
    mapSize: _kInitialSize,
    zoomLevel: 13,
  );

  GalileoMapController? _controller;
  Future<(GalileoMapController?, String?)>? _controllerFuture;
  MapViewport? _viewport;
  Stopwatch? _startupStopwatch;
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
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _initMap();
  }

  void _initMap() {
    _startupStopwatch = Stopwatch()..start();
    _startupMeasured = false;

    _controllerFuture = GalileoMapController.create(
      size: _kInitialSize,
      config: _kMapConfig,
      layers: [LayerConfig.osm()],
    ).then((result) {
      final (ctrl, err) = result;
      if (mounted && ctrl != null && err == null) {
        setState(() {
          _controller = ctrl;
        });

        void checkReady(GalileoMapState state) {
          if (state == GalileoMapState.ready && !_startupMeasured) {
            _startupMeasured = true;
            _startupStopwatch?.stop();
            final elapsed = _startupStopwatch?.elapsedMilliseconds ?? 0;
            if (mounted) {
              setState(() {
                widget.metrics.setStartupTime(elapsed);
              });
            }
          }
        }

        checkReady(ctrl.currentState);
        ctrl.stateStream.listen(checkReady);
      }
      return result;
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            // Galileo Map Widget
            Positioned.fill(
              child: FutureBuilder<(GalileoMapController?, String?)>(
                future: _controllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      color: const Color(0xFF0F172A),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF38BDF8)),
                            SizedBox(height: 12),
                            Text(
                              'Initializing Galileo (Rust/WebGPU)...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError || snapshot.data?.$2 != null) {
                    return Container(
                      color: const Color(0xFF0F172A),
                      child: Center(
                        child: Text(
                          'Galileo error: ${snapshot.error ?? snapshot.data?.$2}',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }

                  final controller = _controller ?? snapshot.data?.$1;
                  if (controller == null) {
                    return Container(color: const Color(0xFF0F172A));
                  }

                  return GalileoMapWidget.fromController(
                    key: ObjectKey(controller),
                    controller: controller,
                    config: _kMapConfig,
                    layers: const [],
                    enableKeyboard: false,
                    autoDispose: false,
                    onViewportChanged: (vp) {
                      if (!mounted) return;
                      setState(() {
                        _viewport = vp;
                      });
                      controller.layerController.updateViewport(
                        vp,
                        MapSize(
                          width: currentSize.width.toInt(),
                          height: currentSize.height.toInt(),
                        ),
                      );
                    },
                    child: _buildMovingPointsOverlay(currentSize),
                  );
                },
              ),
            ),

            // Minimal Top Telemetry Header
            Positioned(
              top: 12,
              left: 12,
              child: BenchmarkHeader(
                title: 'Galileo Flutter',
                subtitle: 'Rust FFI • WebGPU',
                accentColor: const Color(0xFF38BDF8),
                metrics: widget.metrics,
                activePointsCount: widget.points.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMovingPointsOverlay(Size mapSize) {
    final vp = _viewport ?? _controller?.layerController.viewportBounds;
    if (vp == null || mapSize.width <= 0 || mapSize.height <= 0) {
      return const SizedBox.shrink();
    }

    try {
      final geoPoints = widget.points
          .map((p) => GeoLocation(latitude: p.currentLat, longitude: p.currentLng))
          .toList(growable: false);

      final screenPositions = GeoLocation.pointsToScreen(
        points: geoPoints,
        height: mapSize.height,
        width: mapSize.width,
        vp: vp,
      );

      return Stack(
        children: [
          for (int i = 0; i < widget.points.length && i < screenPositions.length; i++)
            Positioned(
              left: screenPositions[i].x - 24,
              top: screenPositions[i].y - 36,
              width: 48,
              height: 48,
              child: PointTooltipMarker(
                point: widget.points[i],
              ),
            ),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
