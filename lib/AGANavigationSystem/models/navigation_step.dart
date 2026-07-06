import 'navigation_coordinate.dart';

/// One maneuver/step returned by a routing provider.
class NavigationStep {
  final double distanceMeters;
  final Duration duration;
  final String instruction;
  final String maneuverType;
  final List<NavigationCoordinate> geometry;

  const NavigationStep({
    required this.distanceMeters,
    required this.duration,
    required this.instruction,
    required this.maneuverType,
    this.geometry = const [],
  });
}
