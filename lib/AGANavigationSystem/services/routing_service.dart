import '../models/navigation_coordinate.dart';
import '../models/navigation_route.dart';

/// Replaceable routing service abstraction.
abstract class RoutingService {
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
  });
}
