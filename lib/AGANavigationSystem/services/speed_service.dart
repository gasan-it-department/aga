import 'dart:collection';
import 'dart:math' as math;

import '../config/navigation_config.dart';
import '../models/navigation_coordinate.dart';
import '../models/speed_sample.dart';
import '../utils/geo_math.dart';

/// Calculates and smooths GPS speed.
class SpeedService {
  final NavigationConfig config;
  final Queue<SpeedSample> _samples = Queue<SpeedSample>();
  NavigationCoordinate? _previous;
  double? _smoothed;

  SpeedService({required this.config});

  List<SpeedSample> get samples => List.unmodifiable(_samples);

  SpeedSample addLocation(NavigationCoordinate coordinate) {
    final osSpeed = coordinate.speedMetersPerSecond;
    double raw = 0;
    var source = SpeedSource.unavailable;
    var confidence = 0.0;

    if (osSpeed != null &&
        osSpeed >= 0 &&
        osSpeed <= config.maximumReasonableSpeedMetersPerSecond &&
        (coordinate.speedAccuracyMetersPerSecond == null ||
            coordinate.speedAccuracyMetersPerSecond! <= 5)) {
      raw = osSpeed;
      source = SpeedSource.operatingSystem;
      confidence = 0.9;
    } else {
      final previous = _previous;
      if (previous != null &&
          coordinate.timestamp.isAfter(previous.timestamp)) {
        final seconds =
            coordinate.timestamp.difference(previous.timestamp).inMilliseconds /
            1000.0;
        final distance = GeoMath.distanceMeters(previous, coordinate);
        final uncertainty = previous.accuracyMeters + coordinate.accuracyMeters;
        if (seconds > 0 &&
            distance > math.max(3, uncertainty * 0.5) &&
            previous.accuracyMeters <= config.maximumLocationAccuracyMeters &&
            coordinate.accuracyMeters <= config.maximumLocationAccuracyMeters) {
          final calculated = distance / seconds;
          if (calculated <= config.maximumReasonableSpeedMetersPerSecond) {
            raw = calculated;
            source = SpeedSource.calculated;
            confidence = 0.65;
          }
        }
      }
    }

    _smoothed = _smoothed == null
        ? raw
        : config.speedSmoothingAlpha * raw +
              (1 - config.speedSmoothingAlpha) * _smoothed!;

    final sample = SpeedSample(
      rawSpeedMetersPerSecond: raw,
      smoothedSpeedMetersPerSecond: _smoothed ?? 0,
      confidence: confidence,
      source: source,
      coordinate: coordinate,
      timestamp: coordinate.timestamp,
    );
    _previous = coordinate;
    _samples.add(sample);
    while (_samples.length > 20) {
      _samples.removeFirst();
    }
    return sample;
  }

  void reset() {
    _samples.clear();
    _previous = null;
    _smoothed = null;
  }
}
