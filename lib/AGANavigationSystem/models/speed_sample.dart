import 'navigation_coordinate.dart';

/// Source used for a speed sample.
enum SpeedSource { operatingSystem, calculated, unavailable }

/// Smoothed speed information calculated from GPS samples.
class SpeedSample {
  final double rawSpeedMetersPerSecond;
  final double smoothedSpeedMetersPerSecond;
  final double confidence;
  final SpeedSource source;
  final NavigationCoordinate coordinate;
  final DateTime timestamp;

  const SpeedSample({
    required this.rawSpeedMetersPerSecond,
    required this.smoothedSpeedMetersPerSecond,
    required this.confidence,
    required this.source,
    required this.coordinate,
    required this.timestamp,
  });

  double get kilometersPerHour => smoothedSpeedMetersPerSecond * 3.6;
}
