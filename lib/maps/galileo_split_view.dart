import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:galileo_flutter/galileo_flutter.dart';
import '../models/moving_point.dart';
import '../services/fps_tracker.dart';
import '../widgets/benchmark_header.dart';

/// Galileo Flutter map half of the benchmark split view.
/// Renders moving points natively using [Point] from galileo_flutter on the WebGPU engine.
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
  static const _pointLayerName = 'native-moving-points';
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

  final List<int> _nativePointIds = [];
  bool _isSyncing = false;
  bool _layerInitialized = false;

  MovingPoint? _hoveredPoint;
  Offset? _mousePosition;

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
    _layerInitialized = false;
    _nativePointIds.clear();

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
            _initNativePointLayer(ctrl);
          }
        }

        checkReady(ctrl.currentState);
        ctrl.stateStream.listen(checkReady);
      }
      return result;
    });
  }

  Future<void> _initNativePointLayer(GalileoMapController ctrl) async {
    if (_layerInitialized) return;
    _layerInitialized = true;

    try {
      await ctrl.layerController.addPointFeatureLayer(_pointLayerName);

      final ids = <int>[];
      for (final p in widget.points) {
        final nativePt = Point(
          coordinate: GeoLocation(latitude: p.currentLat, longitude: p.currentLng),
          style: PointStyle(
            fillColor: p.color.toGalileo(),
            size: 16.0,
          ),
        );
        final id = await ctrl.layerController.addPointToLayer(_pointLayerName, nativePt);
        ids.add(id);
      }

      if (mounted) {
        setState(() {
          _nativePointIds.clear();
          _nativePointIds.addAll(ids);
        });
      }
    } catch (e) {
      debugPrint('Error initializing native point layer: $e');
    }
  }

  @override
  void didUpdateWidget(GalileoSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNativePoints();
  }

  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _syncNativePoints() async {
    final ctrl = _controller;
    if (ctrl == null ||
        _isSyncing ||
        !_layerInitialized ||
        _nativePointIds.length != widget.points.length) {
      return;
    }

    // Throttle to 30Hz to prevent FFI queue congestion
    final now = DateTime.now();
    if (now.difference(_lastSyncTime).inMilliseconds < 30) {
      return;
    }
    _lastSyncTime = now;
    _isSyncing = true;

    try {
      // 1. Add all updated points first so points never disappear from the map
      final newIds = <int>[];
      for (int i = 0; i < widget.points.length; i++) {
        final p = widget.points[i];
        final newPt = Point(
          coordinate: GeoLocation(latitude: p.currentLat, longitude: p.currentLng),
          style: PointStyle(
            fillColor: p.color.toGalileo(),
            size: 16.0,
          ),
        );
        final newId = await ctrl.layerController.addPointToLayer(_pointLayerName, newPt);
        newIds.add(newId);
      }

      // 2. Swap tracked IDs and clean up previous points
      final oldIds = List<int>.from(_nativePointIds);
      _nativePointIds.clear();
      _nativePointIds.addAll(newIds);

      for (final oldId in oldIds) {
        await ctrl.layerController.removePointFromLayer(_pointLayerName, oldId);
      }
    } catch (e) {
      debugPrint('Error syncing native points: $e');
    } finally {
      _isSyncing = false;
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _controller?.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    final vp = _viewport ?? _controller?.layerController.viewportBounds;
    if (vp == null || size.width <= 0 || size.height <= 0) return;

    try {
      final geoPoints = widget.points
          .map((p) => GeoLocation(latitude: p.currentLat, longitude: p.currentLng))
          .toList(growable: false);

      final screenPositions = GeoLocation.pointsToScreen(
        points: geoPoints,
        height: size.height,
        width: size.width,
        vp: vp,
      );

      MovingPoint? closest;
      double minDistance = 24.0; // 24 pixel hit test threshold

      for (int i = 0; i < screenPositions.length && i < widget.points.length; i++) {
        final sp = screenPositions[i];
        final d = (Offset(sp.x, sp.y) - event.localPosition).distance;
        if (d < minDistance) {
          minDistance = d;
          closest = widget.points[i];
        }
      }

      if (closest != _hoveredPoint || _mousePosition != event.localPosition) {
        setState(() {
          _hoveredPoint = closest;
          _mousePosition = event.localPosition;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            // Galileo Map Widget (renders native WebGPU points directly into texture)
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

                  return MouseRegion(
                    onHover: (e) => _onPointerHover(e, currentSize),
                    onExit: (_) {
                      if (_hoveredPoint != null) {
                        setState(() {
                          _hoveredPoint = null;
                        });
                      }
                    },
                    child: GalileoMapWidget.fromController(
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
                    ),
                  );
                },
              ),
            ),

            // Hover tooltip popup for native points
            if (_hoveredPoint != null && _mousePosition != null)
              Positioned(
                left: _mousePosition!.dx + 12,
                top: _mousePosition!.dy - 30,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _hoveredPoint!.color.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_hoveredPoint!.name} (Native Point)',
                          style: TextStyle(
                            color: _hoveredPoint!.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Lat: ${_hoveredPoint!.currentLat.toStringAsFixed(5)}\nLng: ${_hoveredPoint!.currentLng.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Minimal Top Telemetry Header
            Positioned(
              top: 12,
              left: 12,
              child: BenchmarkHeader(
                title: 'Galileo Flutter',
                subtitle: 'Rust Native Points • WebGPU',
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
}
