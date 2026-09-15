import 'package:flutter/material.dart';

import '../models/moving_point.dart';

/// Minimal dot marker for large point-count benchmark runs.
class PointDotMarker extends StatelessWidget {
  final MovingPoint point;

  const PointDotMarker({super.key, required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: point.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
    );
  }
}
