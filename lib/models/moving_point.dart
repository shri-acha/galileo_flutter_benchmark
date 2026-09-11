import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Represents a point moving along an orbital or wandering trajectory.
class MovingPoint {
  final int id;
  final String name;
  final Color color;
  final double centerLat;
  final double centerLng;
  final double radiusLat;
  final double radiusLng;
  final double baseSpeed;
  final double initialAngle;
  final double speedMultiplier;

  double currentLat;
  double currentLng;
  double currentAngle;

  MovingPoint({
    required this.id,
    required this.name,
    required this.color,
    required this.centerLat,
    required this.centerLng,
    required this.radiusLat,
    required this.radiusLng,
    required this.baseSpeed,
    required this.initialAngle,
    this.speedMultiplier = 1.0,
  })  : currentLat = centerLat + radiusLat * math.sin(initialAngle),
        currentLng = centerLng + radiusLng * math.cos(initialAngle),
        currentAngle = initialAngle;

  /// Updates the position based on the elapsed delta time.
  void update(double deltaSeconds, double globalSpeedMultiplier) {
    currentAngle += baseSpeed * speedMultiplier * globalSpeedMultiplier * deltaSeconds;
    if (currentAngle > 2 * math.pi) {
      currentAngle -= 2 * math.pi;
    }

    final latOffset = radiusLat * math.sin(currentAngle * (1.0 + (id % 3) * 0.2));
    final lngOffset = radiusLng * math.cos(currentAngle);

    currentLat = centerLat + latOffset;
    currentLng = centerLng + lngOffset;
  }

  /// Generates the standard set of 10 moving points centered around Tokyo.
  static List<MovingPoint> createTokyoPoints({
    double centerLat = 35.6812,
    double centerLng = 139.7671,
  }) {
    const colors = [
      Color(0xFF38BDF8),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF10B981),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFF06B6D4),
      Color(0xFFF97316),
      Color(0xFF6366F1),
      Color(0xFF84CC16),
    ];

    final points = <MovingPoint>[];
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10.0) * 2 * math.pi;
      final radiusFactor = 0.015 + (i % 4) * 0.012;
      final speedFactor = 0.8 + ((i * 3) % 5) * 0.25;

      points.add(
        MovingPoint(
          id: i + 1,
          name: 'Point #${i + 1}',
          color: colors[i % colors.length],
          centerLat: centerLat + ((i % 3) - 1) * 0.01,
          centerLng: centerLng + (((i ~/ 3) % 3) - 1) * 0.01,
          radiusLat: radiusFactor * 0.85,
          radiusLng: radiusFactor * 1.15,
          baseSpeed: 0.6,
          initialAngle: angle,
          speedMultiplier: speedFactor,
        ),
      );
    }
    return points;
  }
}
