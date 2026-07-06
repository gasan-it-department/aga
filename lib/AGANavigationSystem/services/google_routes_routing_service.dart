import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/navigation_config.dart';
import '../models/navigation_coordinate.dart';
import '../models/navigation_route.dart';
import '../utils/polyline_decoder.dart';
import 'routing_service.dart';

/// Google Routes API routing provider.
///
/// Keep API keys outside normal app source for production builds. Prefer a
/// server or Edge Function proxy when this provider is used outside testing.
class GoogleRoutesRoutingService implements RoutingService {
  final NavigationConfig config;
  final String apiKey;
  final http.Client _client;

  GoogleRoutesRoutingService({
    required this.config,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
  }) async {
    final body = {
      'origin': {
        'location': {
          'latLng': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      },
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': false,
    };

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(
              'https://routes.googleapis.com/directions/v2:computeRoutes',
            ),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask':
                  'routes.duration,routes.staticDuration,routes.distanceMeters,routes.polyline.encodedPolyline',
            },
            body: jsonEncode(body),
          )
          .timeout(config.routingTimeout);
    } catch (error) {
      throw Exception('Google Routes request failed: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Google Routes failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid Google Routes response.');
    }
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw Exception('No Google route found.');
    }

    final route = Map<String, dynamic>.from(routes.first as Map);
    final polyline = route['polyline'];
    final encoded = polyline is Map
        ? polyline['encodedPolyline']?.toString() ?? ''
        : '';
    final geometry = PolylineDecoder.decode(encoded, precision: 5);
    if (geometry.length < 2) {
      throw Exception('Invalid Google route geometry.');
    }

    final duration = _parseGoogleDuration(
      route['duration']?.toString() ?? route['staticDuration']?.toString(),
    );

    return NavigationRoute(
      totalDistanceMeters: (route['distanceMeters'] as num?)?.toDouble() ?? 0,
      originalDuration: duration,
      geometry: geometry,
      steps: const [],
    );
  }

  Duration _parseGoogleDuration(String? value) {
    if (value == null || value.isEmpty) return Duration.zero;
    final secondsText = value.endsWith('s')
        ? value.substring(0, value.length - 1)
        : value;
    final seconds = double.tryParse(secondsText)?.round() ?? 0;
    return Duration(seconds: seconds);
  }
}
