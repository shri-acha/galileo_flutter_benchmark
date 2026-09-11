import 'package:flutter/material.dart';
import '../models/moving_point.dart';

/// A minimal marker displaying a moving point with a clean Tooltip and label.
class PointTooltipMarker extends StatelessWidget {
  final MovingPoint point;
  final bool showLabel;

  const PointTooltipMarker({
    super.key,
    required this.point,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final tooltipText =
        '${point.name}\nLat: ${point.currentLat.toStringAsFixed(5)}\nLng: ${point.currentLng.toStringAsFixed(5)}';

    return Tooltip(
      message: tooltipText,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontFamily: 'monospace',
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: point.color.withValues(alpha: 0.5)),
              ),
              child: Text(
                'P#${point.id}',
                style: TextStyle(
                  color: point.color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          const SizedBox(height: 2),
          // Clean flat dot with white ring
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: point.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}
