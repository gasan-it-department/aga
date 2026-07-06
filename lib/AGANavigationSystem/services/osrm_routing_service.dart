import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/navigation_config.dart';
import '../models/navigation_coordinate.dart';
import '../models/navigation_route.dart';
import '../models/navigation_step.dart';
import '../utils/polyline_decoder.dart';
import 'routing_service.dart';

/// OSRM-based routing provider.
class OsrmRoutingService implements RoutingService {
  final NavigationConfig config;
  final http.Client _client;

  OsrmRoutingService({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
  }) async {
    final base = config.osrmBaseUrl.replaceAll(RegExp(r'/$'), '');
    final coords =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';
    final uri = Uri.parse('$base/route/v1/driving/$coords').replace(
      queryParameters: {
        'overview': 'full',
        'steps': 'true',
        'geometries': 'polyline6',
        'alternatives': 'false',
      },
    );

    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(config.routingTimeout);
    } catch (error) {
      throw Exception('Routing request failed: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Routing server failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid routing response.');
    }
    if (decoded['code'] != 'Ok') {
      throw Exception('No route found: ${decoded['code'] ?? 'unknown'}');
    }
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw Exception('No route found.');
    }
    final route = Map<String, dynamic>.from(routes.first as Map);
    final geometryText = route['geometry']?.toString() ?? '';
    final geometry = PolylineDecoder.decode(geometryText, precision: 6);
    if (geometry.length < 2) throw Exception('Invalid route geometry.');

    final steps = <NavigationStep>[];
    final legs = route['legs'];
    if (legs is List) {
      for (final leg in legs.whereType<Map>()) {
        final rawSteps = leg['steps'];
        if (rawSteps is! List) continue;
        for (final rawStep in rawSteps.whereType<Map>()) {
          final maneuver = rawStep['maneuver'];
          final maneuverMap = maneuver is Map ? maneuver : const {};
          final instruction = _instructionFrom(rawStep, maneuverMap);
          steps.add(
            NavigationStep(
              distanceMeters: (rawStep['distance'] as num?)?.toDouble() ?? 0.0,
              duration: Duration(
                seconds: ((rawStep['duration'] as num?)?.round() ?? 0),
              ),
              instruction: instruction,
              maneuverType: maneuverMap['type']?.toString() ?? '',
              geometry: PolylineDecoder.decode(
                rawStep['geometry']?.toString() ?? '',
                precision: 6,
              ),
            ),
          );
        }
      }
    }

    return NavigationRoute(
      totalDistanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      originalDuration: Duration(
        seconds: ((route['duration'] as num?)?.round() ?? 0),
      ),
      geometry: geometry,
      steps: steps,
    );
  }

  String _instructionFrom(Map rawStep, Map maneuver) {
    final name = rawStep['name']?.toString() ?? '';
    final type = maneuver['type']?.toString() ?? 'continue';
    final modifier = maneuver['modifier']?.toString();
    final parts = <String>[
      type.replaceAll('_', ' '),
      if (modifier != null) modifier,
      if (name.isNotEmpty) 'onto $name',
    ];
    return parts.join(' ');
  }
}
