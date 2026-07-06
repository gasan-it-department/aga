import '../utils/geo_math.dart';
import 'navigation_coordinate.dart';
import 'navigation_step.dart';

/// A road route with decoded geometry and cumulative distances.
class NavigationRoute {
  final double totalDistanceMeters;
  final Duration originalDuration;
  final List<NavigationCoordinate> geometry;
  final List<NavigationStep> steps;
  final List<double> cumulativeDistancesMeters;
  final DateTime generatedAt;

  NavigationRoute({
    required this.totalDistanceMeters,
    required this.originalDuration,
    required this.geometry,
    required this.steps,
    List<double>? cumulativeDistancesMeters,
    DateTime? generatedAt,
  }) : cumulativeDistancesMeters =
           cumulativeDistancesMeters ?? _buildCumulativeDistances(geometry),
       generatedAt = generatedAt ?? DateTime.now();

  static List<double> _buildCumulativeDistances(
    List<NavigationCoordinate> geometry,
  ) {
    if (geometry.isEmpty) return const [];
    final distances = <double>[0];
    var total = 0.0;
    for (var i = 1; i < geometry.length; i++) {
      total += GeoMath.distanceMeters(geometry[i - 1], geometry[i]);
      distances.add(total);
    }
    return distances;
  }
}
