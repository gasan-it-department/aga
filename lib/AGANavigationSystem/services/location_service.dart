import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../config/navigation_config.dart';
import '../models/navigation_coordinate.dart';
import '../utils/geo_math.dart';

/// High-accuracy location provider with validation.
class LocationService {
  final NavigationConfig config;
  StreamSubscription<Position>? _subscription;
  final _controller = StreamController<NavigationCoordinate>.broadcast();
  NavigationCoordinate? _lastAccepted;

  LocationService({required this.config});

  Stream<NavigationCoordinate> get stream => _controller.stream;

  Future<NavigationCoordinate> getCurrentLocation() async {
    await _ensurePermission();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    final coordinate = _fromPosition(position);
    if (!_isValid(coordinate)) {
      throw Exception('No valid location fix.');
    }
    _lastAccepted = coordinate;
    return coordinate;
  }

  Future<void> start() async {
    await _ensurePermission();
    await stop();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
          final coordinate = _fromPosition(position);
          if (_isValid(coordinate)) {
            _lastAccepted = coordinate;
            _controller.add(coordinate);
          }
        }, onError: _controller.addError);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  Future<void> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied.');
    }
  }

  NavigationCoordinate _fromPosition(Position position) {
    return NavigationCoordinate(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracyMeters: position.accuracy,
      speedMetersPerSecond: position.speed.isFinite && position.speed >= 0
          ? position.speed
          : null,
      speedAccuracyMetersPerSecond:
          position.speedAccuracy.isFinite && position.speedAccuracy >= 0
          ? position.speedAccuracy
          : null,
      bearingDegrees: position.heading.isFinite ? position.heading : null,
      timestamp: position.timestamp,
    );
  }

  bool _isValid(NavigationCoordinate coordinate) {
    if (!coordinate.hasValidLatLng) return false;
    if (coordinate.accuracyMeters > config.maximumLocationAccuracyMeters) {
      return false;
    }
    if (DateTime.now().difference(coordinate.timestamp).abs() >
        config.staleLocationThreshold) {
      return false;
    }
    final previous = _lastAccepted;
    if (previous == null) return true;
    if (!coordinate.timestamp.isAfter(previous.timestamp)) return false;
    final seconds =
        coordinate.timestamp.difference(previous.timestamp).inMilliseconds /
        1000.0;
    if (seconds <= 0) return false;
    final jumpSpeed = GeoMath.distanceMeters(previous, coordinate) / seconds;
    return jumpSpeed <= config.maximumReasonableSpeedMetersPerSecond;
  }
}
