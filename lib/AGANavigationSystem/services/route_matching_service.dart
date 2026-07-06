import 'dart:math' as math;

import '../models/navigation_coordinate.dart';
import '../models/navigation_route.dart';
import '../models/route_match_result.dart';
import '../utils/geo_math.dart';

/// Matches the user's GPS coordinate to the nearest route segment.
class RouteMatchingService {
  int? _lastSegmentIndex;
  double _lastTraveledMeters = 0;

  RouteMatchResult match({
    required NavigationRoute route,
    required NavigationCoordinate coordinate,
    bool forceFullSearch = false,
  }) {
    if (route.geometry.length < 2 ||
        route.cumulativeDistancesMeters.length < 2) {
      throw Exception('Route geometry is too short.');
    }

    final segmentCount = route.geometry.length - 1;
    final indexes = _searchIndexes(segmentCount, forceFullSearch);
    _Projection? best;

    for (final index in indexes) {
      final projection = _project(
        coordinate,
        route.geometry[index],
        route.geometry[index + 1],
        index,
      );
      if (best == null ||
          projection.distanceFromRouteMeters < best.distanceFromRouteMeters) {
        best = projection;
      }
    }

    if (best == null) {
      throw Exception('Unable to match route.');
    }

    final segmentStart = route.cumulativeDistancesMeters[best.segmentIndex];
    final segmentLength = GeoMath.distanceMeters(
      route.geometry[best.segmentIndex],
      route.geometry[best.segmentIndex + 1],
    );
    var traveled = segmentStart + segmentLength * best.u;
    if (!forceFullSearch && traveled < _lastTraveledMeters) {
      traveled = _lastTraveledMeters;
    }
    traveled = traveled.clamp(0.0, route.totalDistanceMeters).toDouble();
    _lastTraveledMeters = traveled;
    _lastSegmentIndex = best.segmentIndex;

    final remaining = math.max(0.0, route.totalDistanceMeters - traveled);
    return RouteMatchResult(
      matchedCoordinate: best.coordinate,
      segmentIndex: best.segmentIndex,
      distanceFromRouteMeters: best.distanceFromRouteMeters,
      traveledDistanceMeters: traveled,
      remainingDistanceMeters: remaining,
      progress: route.totalDistanceMeters <= 0
          ? 0
          : (traveled / route.totalDistanceMeters).clamp(0.0, 1.0),
    );
  }

  void reset() {
    _lastSegmentIndex = null;
    _lastTraveledMeters = 0;
  }

  Iterable<int> _searchIndexes(int segmentCount, bool forceFullSearch) {
    final last = _lastSegmentIndex;
    if (forceFullSearch || last == null) {
      return List.generate(segmentCount, (i) => i);
    }
    final start = math.max(0, last - 20);
    final end = math.min(segmentCount - 1, last + 80);
    return [for (var i = start; i <= end; i++) i];
  }

  _Projection _project(
    NavigationCoordinate p,
    NavigationCoordinate a,
    NavigationCoordinate b,
    int segmentIndex,
  ) {
    final pp = GeoMath.toLocalMeters(p, a);
    final bb = GeoMath.toLocalMeters(b, a);
    final squared = bb.x * bb.x + bb.y * bb.y;
    final u = squared == 0
        ? 0.0
        : GeoMath.clamp01((pp.x * bb.x + pp.y * bb.y) / squared);
    final qx = u * bb.x;
    final qy = u * bb.y;
    final matched = GeoMath.fromLocalMeters(
      x: qx,
      y: qy,
      origin: a,
      timestamp: p.timestamp,
    );
    final distance = math.sqrt(math.pow(pp.x - qx, 2) + math.pow(pp.y - qy, 2));
    return _Projection(segmentIndex, u, matched, distance);
  }
}

class _Projection {
  final int segmentIndex;
  final double u;
  final NavigationCoordinate coordinate;
  final double distanceFromRouteMeters;

  const _Projection(
    this.segmentIndex,
    this.u,
    this.coordinate,
    this.distanceFromRouteMeters,
  );
}
