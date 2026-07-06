import 'dart:math' as math;

import '../models/navigation_coordinate.dart';

/// Geographic calculations used by route matching and ETA.
class GeoMath {
  static const double earthRadiusMeters = 6371008.8;

  static double distanceMeters(NavigationCoordinate a, NavigationCoordinate b) {
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double directDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return distanceMeters(
      NavigationCoordinate(
        latitude: lat1,
        longitude: lon1,
        accuracyMeters: 0,
        timestamp: DateTime.now(),
      ),
      NavigationCoordinate(
        latitude: lat2,
        longitude: lon2,
        accuracyMeters: 0,
        timestamp: DateTime.now(),
      ),
    );
  }

  static ({double x, double y}) toLocalMeters(
    NavigationCoordinate point,
    NavigationCoordinate origin,
  ) {
    final latRad = _rad(origin.latitude);
    final x =
        _rad(point.longitude - origin.longitude) *
        earthRadiusMeters *
        math.cos(latRad);
    final y = _rad(point.latitude - origin.latitude) * earthRadiusMeters;
    return (x: x, y: y);
  }

  static NavigationCoordinate fromLocalMeters({
    required double x,
    required double y,
    required NavigationCoordinate origin,
    required DateTime timestamp,
  }) {
    final lat = origin.latitude + _deg(y / earthRadiusMeters);
    final lon =
        origin.longitude +
        _deg(x / (earthRadiusMeters * math.cos(_rad(origin.latitude))));
    return NavigationCoordinate(
      latitude: lat,
      longitude: lon,
      accuracyMeters: 0,
      timestamp: timestamp,
    );
  }

  static double clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  static double _rad(double degrees) => degrees * math.pi / 180.0;
  static double _deg(double radians) => radians * 180.0 / math.pi;
}
