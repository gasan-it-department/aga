import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/navigation_config.dart';
import '../models/eta_result.dart';
import '../models/navigation_coordinate.dart';
import '../models/navigation_state.dart';
import '../services/eta_service.dart';
import '../services/location_service.dart';
import '../services/osrm_routing_service.dart';
import '../services/route_matching_service.dart';
import '../services/routing_service.dart';
import '../services/speed_service.dart';
import '../utils/geo_math.dart';

/// Coordinates permissions, routing, GPS updates, ETA, rerouting, and arrival.
class NavigationController extends ChangeNotifier {
  final NavigationConfig config;
  final RoutingService routingService;
  final LocationService locationService;
  late final SpeedService _speedService;
  late final RouteMatchingService _matchingService;
  late final EtaService _etaService;

  NavigationState _state = const NavigationState();
  StreamSubscription<NavigationCoordinate>? _locationSub;
  bool _disposed = false;
  bool _routeRequestInFlight = false;
  int _routeRequestToken = 0;
  int _offRouteSamples = 0;
  int _arrivalSamples = 0;
  DateTime? _lastRerouteAt;

  NavigationController({
    required this.config,
    RoutingService? routingService,
    LocationService? locationService,
  }) : routingService = routingService ?? OsrmRoutingService(config: config),
       locationService = locationService ?? LocationService(config: config) {
    _speedService = SpeedService(config: config);
    _matchingService = RouteMatchingService();
    _etaService = EtaService(config: config);
  }

  /// Current immutable navigation state.
  NavigationState get state => _state;

  /// Starts navigation from the current GPS coordinate to [destination].
  Future<void> startNavigation({
    required NavigationCoordinate destination,
  }) async {
    if (_disposed) return;
    try {
      _setState(
        _state.copyWith(
          status: NavigationStatus.requestingPermission,
          destination: destination,
          clearError: true,
        ),
      );
      _setState(_state.copyWith(status: NavigationStatus.locating));
      final origin = await locationService.getCurrentLocation();
      if (_disposed) return;
      if (GeoMath.distanceMeters(origin, destination) <=
          math.max(config.arrivalRadiusMeters, origin.accuracyMeters)) {
        _setState(
          _state.copyWith(
            status: NavigationStatus.arrived,
            currentCoordinate: origin,
            etaResult: const EtaResult(
              rawEta: Duration.zero,
              displayedEta: Duration.zero,
              confidence: 1,
              source: EtaSource.route,
            ),
            estimatedArrivalTime: DateTime.now(),
          ),
        );
        return;
      }
      await _replaceRoute(
        origin,
        destination,
        status: NavigationStatus.calculatingRoute,
      );
      await locationService.start();
      await _locationSub?.cancel();
      _locationSub = locationService.stream.listen(
        _handleLocation,
        onError: (error) => _fail('Location error: $error'),
      );
    } catch (error) {
      _fail(error.toString());
    }
  }

  /// Stops active navigation and location updates.
  Future<void> stopNavigation() async {
    await _locationSub?.cancel();
    _locationSub = null;
    await locationService.stop();
    _speedService.reset();
    _matchingService.reset();
    _setState(const NavigationState());
  }

  /// Manually requests a route from the latest valid coordinate.
  Future<void> reroute() async {
    final current = _state.currentCoordinate;
    final destination = _state.destination;
    if (current == null || destination == null || _routeRequestInFlight) return;
    await _replaceRoute(
      current,
      destination,
      status: NavigationStatus.rerouting,
    );
  }

  /// Stops subscriptions and closes internal resources.
  Future<void> disposeNavigation() async {
    _disposed = true;
    await _locationSub?.cancel();
    await locationService.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_locationSub?.cancel());
    unawaited(locationService.dispose());
    super.dispose();
  }

  Future<void> _replaceRoute(
    NavigationCoordinate origin,
    NavigationCoordinate destination, {
    required NavigationStatus status,
  }) async {
    if (_routeRequestInFlight) return;
    _routeRequestInFlight = true;
    final token = ++_routeRequestToken;
    _setState(
      _state.copyWith(
        status: status,
        isRerouting: status == NavigationStatus.rerouting,
      ),
    );
    try {
      final route = await routingService.getRoute(
        origin: origin,
        destination: destination,
      );
      if (_disposed || token != _routeRequestToken) return;
      _matchingService.reset();
      _etaService.resetAfterReroute();
      _offRouteSamples = 0;
      _arrivalSamples = 0;
      _lastRerouteAt = DateTime.now();
      _setState(
        _state.copyWith(
          status: NavigationStatus.navigating,
          currentCoordinate: origin,
          destination: destination,
          currentRoute: route,
          totalRouteDistanceMeters: route.totalDistanceMeters,
          remainingRouteDistanceMeters: route.totalDistanceMeters,
          traveledRouteDistanceMeters: 0,
          progress: 0,
          isRerouting: false,
          clearError: true,
        ),
      );
      _etaService.start();
    } catch (error) {
      _fail('Route failed: $error');
    } finally {
      _routeRequestInFlight = false;
    }
  }

  Future<void> _handleLocation(NavigationCoordinate coordinate) async {
    if (_disposed) return;
    final route = _state.currentRoute;
    final destination = _state.destination;
    if (route == null || destination == null) return;

    final speed = _speedService.addLocation(coordinate);
    final forceFull =
        _state.isOffRoute || _state.currentRouteSegmentIndex == null;
    final match = _matchingService.match(
      route: route,
      coordinate: coordinate,
      forceFullSearch: forceFull,
    );
    final threshold = math.max(
      config.offRouteThresholdMeters,
      coordinate.accuracyMeters * config.offRouteAccuracyMultiplier,
    );
    final offRoute = match.distanceFromRouteMeters > threshold;
    _offRouteSamples = offRoute ? _offRouteSamples + 1 : 0;

    final eta = _etaService.calculate(
      route: route,
      match: match,
      speed: speed,
      gpsAccuracyMeters: coordinate.accuracyMeters,
      distanceFromRouteMeters: match.distanceFromRouteMeters,
      forceAccept: _state.status == NavigationStatus.rerouting,
    );
    final arrivalTime = eta.displayedEta == null
        ? null
        : DateTime.now().add(eta.displayedEta!);

    final arrived = _arrived(match, coordinate, destination);
    _setState(
      _state.copyWith(
        status: arrived
            ? NavigationStatus.arrived
            : speed.smoothedSpeedMetersPerSecond <
                  config.minimumEtaSpeedMetersPerSecond
            ? NavigationStatus.stopped
            : NavigationStatus.navigating,
        currentCoordinate: coordinate,
        matchedRouteCoordinate: match.matchedCoordinate,
        currentRouteSegmentIndex: match.segmentIndex,
        rawSpeedMetersPerSecond: speed.rawSpeedMetersPerSecond,
        smoothedSpeedMetersPerSecond: speed.smoothedSpeedMetersPerSecond,
        speedSource: speed.source,
        speedConfidence: speed.confidence,
        gpsAccuracyMeters: coordinate.accuracyMeters,
        remainingRouteDistanceMeters: match.remainingDistanceMeters,
        traveledRouteDistanceMeters: match.traveledDistanceMeters,
        totalRouteDistanceMeters: route.totalDistanceMeters,
        progress: match.progress,
        distanceFromRouteMeters: match.distanceFromRouteMeters,
        etaResult: arrived
            ? const EtaResult(
                rawEta: Duration.zero,
                displayedEta: Duration.zero,
                confidence: 1,
                source: EtaSource.route,
              )
            : eta,
        estimatedArrivalTime: arrived ? DateTime.now() : arrivalTime,
        isOffRoute: offRoute,
        isRerouting: false,
        clearError: true,
      ),
    );

    if (arrived) {
      if (config.stopTrackingAfterArrival) await locationService.stop();
      return;
    }

    if (_offRouteSamples >= config.offRouteRequiredSamples && _canReroute()) {
      await reroute();
    }
  }

  bool _arrived(
    dynamic match,
    NavigationCoordinate coordinate,
    NavigationCoordinate destination,
  ) {
    final radius = math.max(
      config.arrivalRadiusMeters,
      coordinate.accuracyMeters,
    );
    final direct = GeoMath.distanceMeters(coordinate, destination);
    final valid = match.remainingDistanceMeters <= radius || direct <= radius;
    _arrivalSamples = valid ? _arrivalSamples + 1 : 0;
    return _arrivalSamples >= config.arrivalRequiredSamples;
  }

  bool _canReroute() {
    final last = _lastRerouteAt;
    return last == null ||
        DateTime.now().difference(last) >= config.minimumRerouteInterval;
  }

  void _fail(String message) {
    if (_disposed) return;
    _setState(
      _state.copyWith(status: NavigationStatus.error, errorMessage: message),
    );
  }

  void _setState(NavigationState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }
}
