import 'navigation_coordinate.dart';

/// Result of matching a GPS point onto a route polyline.
class RouteMatchResult {
  final NavigationCoordinate matchedCoordinate;
  final int segmentIndex;
  final double distanceFromRouteMeters;
  final double traveledDistanceMeters;
  final double remainingDistanceMeters;
  final double progress;

  const RouteMatchResult({
    required this.matchedCoordinate,
    required this.segmentIndex,
    required this.distanceFromRouteMeters,
    required this.traveledDistanceMeters,
    required this.remainingDistanceMeters,
    required this.progress,
  });
}
