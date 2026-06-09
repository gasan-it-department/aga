import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// A data class to hold comprehensive location information.
class GeoLocation {
  final String municipality;
  final String? province;
  final int? zipCode;
  final String? country;
  final double latitude;
  final double longitude;

  GeoLocation({
    required this.municipality,
    this.province,
    this.zipCode,
    this.country,
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() {
    return 'LocationDetails(municipality: $municipality, zipCode: $zipCode, province: $province, country: $country, lat: $latitude, lon: $longitude)';
  }
}

class GeoCoding {

  static int _getZipCode(String? municipality, String? postalCode) {
    int? parsed = int.tryParse(postalCode ?? "");
    if (parsed != null && parsed != 0) return parsed;

    if (municipality != null) {
      String key = municipality.trim();
      return Utility.marinduqueZipCodes[key] ?? 0;
    }

    return 0;
  }

  static Future<GeoLocation?> getCurrentMunicipalityDetails() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (kIsWeb) {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=14&addressdetails=1'
        );

        final response = await http.get(url, headers: {
          'User-Agent': 'AgaApp/1.0 (Contact: your_email@example.com)'
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'];

          if (address != null) {
            String? municipality = address['municipality'] ??
                address['city'] ??
                address['town'] ??
                address['village'];

            // Use the zip helper
            int zipCode = _getZipCode(municipality, address['postcode']);
            String? province = address['state'] ?? address['county'] ?? address['region'];
            String? country = address['country'];

            if (municipality != null) {
              return GeoLocation(
                municipality: municipality,
                province: province,
                zipCode: zipCode,
                country: country,
                latitude: position.latitude,
                longitude: position.longitude,
              );
            }
          }
        }
      } else {
        // MOBILE IMPLEMENTATION
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;

          String? municipality = place.locality ?? place.subLocality;

          // Use the zip helper to avoid getting 0
          int zipCode = _getZipCode(municipality, place.postalCode);

          String? province = place.subAdministrativeArea ?? place.administrativeArea;
          String? country = place.country;

          if (municipality != null) {
            return GeoLocation(
              municipality: municipality,
              province: province,
              zipCode: zipCode,
              country: country,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error detecting municipality details: $e");
    }

    return null;
  }
}
