import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MarinduqueBoundaries {

  static Future<List<Polygon>> loadBoundaries() async {
    try {
      final String response = await rootBundle.loadString('assets/MARINDUQUE.geojson');
      final data = json.decode(response);
      List<Polygon> polygons = [];

      if (data['features'] != null) {
        for (var feature in data['features']) {
          final geometry = feature['geometry'];
          final properties = feature['properties'];
          final String type = geometry['type'];

          final String name = properties['NAME_2'] ??
              properties['name'] ??
              properties['ADM2_EN'] ??
              properties['mun_name'] ??
              'Unknown';

          if (type == 'Polygon') {
            polygons.add(_createPolygon(geometry['coordinates'][0], name));
          } else if (type == 'MultiPolygon') {
            for (var polyCoordinates in geometry['coordinates']) {
              polygons.add(_createPolygon(polyCoordinates[0], name));
            }
          }
        }
      }
      return polygons;
    } catch (e) {
      debugPrint("GeoJSON Error: $e");
      return [];
    }
  }

  static Polygon _createPolygon(List<dynamic> coordinates, String name) {
    final List<LatLng> points = coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
    final Color baseColor = _getMunicipalityColor(name);

    return Polygon(
      points: points,
      color: baseColor.withValues(alpha: 0.45),
      borderColor: baseColor,
      borderStrokeWidth: 2.0,
    );
  }

  static Color _getMunicipalityColor(String name) {
    switch (name.toUpperCase()) {
      case 'BOAC': return Colors.blue;
      case 'GASAN': return Colors.teal;
      case 'MOGPOG': return Colors.blueGrey;
      case 'SANTA CRUZ': return Colors.purple;
      case 'TORRIJOS': return Colors.red;
      case 'BUENAVISTA': return Colors.green;
      default: return Colors.blueGrey;
    }
  }
}
