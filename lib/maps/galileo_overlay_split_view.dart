import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:galileo_flutter/galileo_flutter.dart';
import '../models/moving_point.dart';
import '../services/fps_tracker.dart';
import '../widgets/benchmark_header.dart';
import '../widgets/point_tooltip_marker.dart';

/// Galileo Flutter map view rendering moving points using [OverlayWidget] and [MapOverlayLayer].
class GalileoOverlaySplitView extends StatefulWidget {
  final List<MovingPoint> points;
  final BenchmarkMetrics metrics;

  const GalileoOverlaySplitView({
    super.key,
    required this.points,
    required this.metrics,
  });

  @override
  State<GalileoOverlaySplitView> createState() => _GalileoOverlaySplitViewState();
}

class _GalileoOverlaySplitViewState extends State<GalileoOverlaySplitView> {
  static const _kInitialSize = MapSize(width: 800, height: 400);
  final _kMapConfig = MapInitConfig(
    backgroundColor: const Color(0xFF0F172A).toGalileo(),
    enableMultisampling: true,
    latlon: const GeoLocation(latitude: 35.6812, longitude: 139.7671),
    mapSize: _kInitialSize,
    zoomLevel: 13,
  );

  GalileoMapController? _controller;
  Future<(GalileoMapController?, String?)>? _controllerFuture;
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
                            CircularProgressIndicator(color: Color(0xFF06B6D4)),
                            SizedBox(height: 12),
                            Text(
                              'Initializing Galileo (OverlayWidget)...',
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

                  // Build OverlayWidget list for the 10 moving points
                  final overlays = [
                    for (final point in widget.points)
                      OverlayWidget.geo(
                        key: ValueKey(point.id),
                        loc: GeoLocation(
                          latitude: point.currentLat,
                          longitude: point.currentLng,
                        ),
                        width: 48,
                        height: 48,
                        child: PointTooltipMarker(point: point),
                      ),
                  ];

                  return GalileoMapWidget.fromController(
                    key: ObjectKey(controller),
                    controller: controller,
                    config: _kMapConfig,
                    layers: const [],
                    enableKeyboard: false,
                    autoDispose: false,
                    onViewportChanged: (vp) {
                      if (!mounted) return;
                      controller.layerController.updateViewport(
                        vp,
                        MapSize(
                          width: currentSize.width.toInt(),
                          height: currentSize.height.toInt(),
                        ),
                      );
                    },
                    child: MapOverlayLayer(
                      controller: controller.layerController,
                      overlays: overlays,
                    ),
                  );
                },
              ),
            ),

            // Minimal Top Telemetry Header
            Positioned(
              top: 12,
              left: 12,
              child: BenchmarkHeader(
                title: 'Galileo (OverlayWidget)',
                subtitle: 'Flow • OverlayWidget.geo',
                accentColor: const Color(0xFF06B6D4), // Teal
                metrics: widget.metrics,
                activePointsCount: widget.points.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
