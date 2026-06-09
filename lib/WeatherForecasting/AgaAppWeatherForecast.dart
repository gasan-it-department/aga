import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class AgaAppWeatherForecast {
  final String _apiKey = "e72fc3b10cdd458502df474d0bb3c8eb";

  Future<Map<String, dynamic>?> getCurrentWeather(double latitude, double longitude) async {
    final String url = 'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      Utility().printLog("Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final int temp = (data['main']['temp'] as num).round();
        final String condition = data['weather'][0]['main'];
        final int conditionId = data['weather'][0]['id'];

        final String cityName = data['name'] ?? "Unknown Location";

        return {
          'temp': temp,
          'condition': condition,
          'conditionId': conditionId,
          'cityName': cityName,
        };
      } else {
        Utility().printLog("Weather fetch failed. Status Code: ${response.statusCode}");
        return null;
      }
    } on TimeoutException {
      Utility().printLog("Weather API Exception: Request timed out.");
      return null;
    } catch (e) {
      Utility().printLog("Weather API Exception: $e");
      return null;
    }
  }
}

class WeatherHeaderWidget extends StatefulWidget {
  final String userName;
  const WeatherHeaderWidget({super.key, required this.userName});
  @override
  State<WeatherHeaderWidget> createState() => _WeatherHeaderWidgetState();
}

class _WeatherHeaderWidgetState extends State<WeatherHeaderWidget> {
  String _currentTemp = "--°C";
  String _weatherCondition = "Locating...";
  IconData _weatherIcon = Icons.cloud_outlined;
  String _currentLocation = "Locating...";

  @override
  void initState() {
    super.initState();
    _fetchLiveWeather();
  }

  Future<void> _fetchLiveWeather() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _weatherCondition = "GPS Off";
            _currentLocation = "Location disabled";
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _weatherCondition = "Denied";
              _currentLocation = "Permission denied";
            });
          }
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) setState(() => _weatherCondition = "Fetching...");

      final weatherService = AgaAppWeatherForecast();
      final weatherData = await weatherService.getCurrentWeather(
          position.latitude,
          position.longitude
      );

      if (weatherData != null && mounted) {
        setState(() {
          _currentTemp = "${weatherData['temp']}°C";
          _weatherCondition = weatherData['condition'];
          _weatherIcon = _getOpenWeatherIcon(weatherData['conditionId']);
          _currentLocation = "Near at ${weatherData['cityName']}";
        });
      } else if (mounted) {
        setState(() => _weatherCondition = "Unavailable");
      }
    } catch (e) {
      if (mounted) setState(() => _weatherCondition = "Error");
      Utility().printLog("Location/Weather Error: $e");
    }
  }

  IconData _getOpenWeatherIcon(int code) {
    if (code >= 200 && code < 300) return Icons.thunderstorm_rounded;
    if (code >= 300 && code < 600) return Icons.water_drop_rounded;
    if (code >= 600 && code < 700) return Icons.ac_unit_rounded;
    if (code >= 700 && code < 800) return Icons.foggy;
    if (code == 800) return Icons.wb_sunny_rounded;
    if (code > 800 && code < 900) return Icons.cloud_rounded;
    return Icons.cloud_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userName.split(' ').isNotEmpty ? widget.userName.split(' ')[0] : "Citizen";

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0A2E5C), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              // FIXED: Changed .withOpacity to .withValues
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6)
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIXED: Changed .withOpacity to .withValues
                  Text("Magandang araw, $firstName!", style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    _currentLocation,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.thermostat, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text("$_currentTemp • $_weatherCondition", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.all(12),
              // FIXED: Changed .withOpacity to .withValues
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(_weatherIcon, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}
