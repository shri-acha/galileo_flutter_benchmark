import 'package:flutter/material.dart';
import '../services/fps_tracker.dart';

/// Minimal telemetry header bar displaying engine details, startup time, and runtime metrics.
class BenchmarkHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final BenchmarkMetrics metrics;
  final int activePointsCount;

  const BenchmarkHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.metrics,
    required this.activePointsCount,
  });

  @override
  Widget build(BuildContext context) {
    final startupTime = metrics.startupTimeMs;
    final fps = metrics.currentFps;
    final fpsColor = fps >= 55
        ? const Color(0xFF10B981)
        : (fps >= 30 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Engine identity
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFA1A1AA),
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),
          Container(width: 1, height: 26, color: const Color(0xFF27272A)),
          const SizedBox(width: 14),

          // Startup time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'STARTUP',
                style: TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                startupTime != null ? '$startupTime ms' : 'Measuring...',
                style: TextStyle(
                  color: startupTime != null ? accentColor : Colors.amber,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),
          Container(width: 1, height: 26, color: const Color(0xFF27272A)),
          const SizedBox(width: 14),

          // Runtime FPS & Latency
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'RUNTIME',
                style: TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fps > 0 ? '${fps.toStringAsFixed(1)} FPS' : '-- FPS',
                    style: TextStyle(
                      color: fpsColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (metrics.avgBuildTimeMs > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${metrics.avgBuildTimeMs.toStringAsFixed(1)}ms)',
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(width: 14),
          Container(width: 1, height: 26, color: const Color(0xFF27272A)),
          const SizedBox(width: 14),

          // Point count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF27272A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$activePointsCount pts',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
