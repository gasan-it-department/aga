/// A GPS coordinate used by the AGA navigation system.
class NavigationCoordinate {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracyMeters;
  final double? speedMetersPerSecond;
  final double? speedAccuracyMetersPerSecond;
  final double? bearingDegrees;
  final DateTime timestamp;

  const NavigationCoordinate({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    this.altitude,
    this.speedMetersPerSecond,
    this.speedAccuracyMetersPerSecond,
    this.bearingDegrees,
  });

  bool get hasValidLatLng =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  NavigationCoordinate copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracyMeters,
    double? speedMetersPerSecond,
    double? speedAccuracyMetersPerSecond,
    double? bearingDegrees,
    DateTime? timestamp,
  }) {
    return NavigationCoordinate(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      speedMetersPerSecond: speedMetersPerSecond ?? this.speedMetersPerSecond,
      speedAccuracyMetersPerSecond:
          speedAccuracyMetersPerSecond ?? this.speedAccuracyMetersPerSecond,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
