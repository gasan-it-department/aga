import 'eta_result.dart';
import 'navigation_coordinate.dart';
import 'navigation_route.dart';
import 'speed_sample.dart';

/// Lifecycle status of the navigation controller.
enum NavigationStatus {
  idle,
  requestingPermission,
  locating,
  calculatingRoute,
  navigating,
  stopped,
  rerouting,
  arrived,
  error,
}

/// Immutable public state for the navigation system.
class NavigationState {
  final NavigationStatus status;
  final NavigationCoordinate? currentCoordinate;
  final NavigationCoordinate? destination;
  final NavigationRoute? currentRoute;
  final NavigationCoordinate? matchedRouteCoordinate;
  final int? currentRouteSegmentIndex;
  final double? rawSpeedMetersPerSecond;
  final double? smoothedSpeedMetersPerSecond;
  final SpeedSource speedSource;
  final double speedConfidence;
  final double? gpsAccuracyMeters;
  final double remainingRouteDistanceMeters;
  final double traveledRouteDistanceMeters;
  final double totalRouteDistanceMeters;
  final double progress;
  final double? distanceFromRouteMeters;
  final EtaResult etaResult;
  final DateTime? estimatedArrivalTime;
  final bool isOffRoute;
  final bool isRerouting;
  final String? errorMessage;

  const NavigationState({
    this.status = NavigationStatus.idle,
    this.currentCoordinate,
    this.destination,
    this.currentRoute,
    this.matchedRouteCoordinate,
    this.currentRouteSegmentIndex,
    this.rawSpeedMetersPerSecond,
    this.smoothedSpeedMetersPerSecond,
    this.speedSource = SpeedSource.unavailable,
    this.speedConfidence = 0,
    this.gpsAccuracyMeters,
    this.remainingRouteDistanceMeters = 0,
    this.traveledRouteDistanceMeters = 0,
    this.totalRouteDistanceMeters = 0,
    this.progress = 0,
    this.distanceFromRouteMeters,
    this.etaResult = EtaResult.unavailable,
    this.estimatedArrivalTime,
    this.isOffRoute = false,
    this.isRerouting = false,
    this.errorMessage,
  });

  NavigationState copyWith({
    NavigationStatus? status,
    NavigationCoordinate? currentCoordinate,
    NavigationCoordinate? destination,
    NavigationRoute? currentRoute,
    NavigationCoordinate? matchedRouteCoordinate,
    int? currentRouteSegmentIndex,
    double? rawSpeedMetersPerSecond,
    double? smoothedSpeedMetersPerSecond,
    SpeedSource? speedSource,
    double? speedConfidence,
    double? gpsAccuracyMeters,
    double? remainingRouteDistanceMeters,
    double? traveledRouteDistanceMeters,
    double? totalRouteDistanceMeters,
    double? progress,
    double? distanceFromRouteMeters,
    EtaResult? etaResult,
    DateTime? estimatedArrivalTime,
    bool? isOffRoute,
    bool? isRerouting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NavigationState(
      status: status ?? this.status,
      currentCoordinate: currentCoordinate ?? this.currentCoordinate,
      destination: destination ?? this.destination,
      currentRoute: currentRoute ?? this.currentRoute,
      matchedRouteCoordinate:
          matchedRouteCoordinate ?? this.matchedRouteCoordinate,
      currentRouteSegmentIndex:
          currentRouteSegmentIndex ?? this.currentRouteSegmentIndex,
      rawSpeedMetersPerSecond:
          rawSpeedMetersPerSecond ?? this.rawSpeedMetersPerSecond,
      smoothedSpeedMetersPerSecond:
          smoothedSpeedMetersPerSecond ?? this.smoothedSpeedMetersPerSecond,
      speedSource: speedSource ?? this.speedSource,
      speedConfidence: speedConfidence ?? this.speedConfidence,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      remainingRouteDistanceMeters:
          remainingRouteDistanceMeters ?? this.remainingRouteDistanceMeters,
      traveledRouteDistanceMeters:
          traveledRouteDistanceMeters ?? this.traveledRouteDistanceMeters,
      totalRouteDistanceMeters:
          totalRouteDistanceMeters ?? this.totalRouteDistanceMeters,
      progress: progress ?? this.progress,
      distanceFromRouteMeters:
          distanceFromRouteMeters ?? this.distanceFromRouteMeters,
      etaResult: etaResult ?? this.etaResult,
      estimatedArrivalTime: estimatedArrivalTime ?? this.estimatedArrivalTime,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      isRerouting: isRerouting ?? this.isRerouting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
