import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Services/WeatherForecastWidgetService.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/WeatherForecasting/WeatherForecastScreen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AgaAppWeatherForecast {
  final String _apiKey = "e72fc3b10cdd458502df474d0bb3c8eb";

  Future<Map<String, dynamic>?> getCurrentWeather(
    double latitude,
    double longitude,
  ) async {
    final String url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      Utility().printLog("Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final int temp = (data['main']['temp'] as num).round();
        final int feelsLike = (data['main']['feels_like'] as num).round();
        final int humidity = (data['main']['humidity'] as num).round();
        final double windSpeed =
            (data['wind']?['speed'] as num?)?.toDouble() ?? 0;
        final String condition = data['weather'][0]['main'];
        final String description = data['weather'][0]['description'];
        final int conditionId = data['weather'][0]['id'];
        final String cityName = data['name'] ?? "Unknown Location";

        return {
          'temp': temp,
          'feelsLike': feelsLike,
          'humidity': humidity,
          'windSpeed': windSpeed,
          'condition': condition,
          'description': description,
          'conditionId': conditionId,
          'cityName': cityName,
        };
      } else {
        Utility().printLog(
          "Weather fetch failed. Status Code: ${response.statusCode}",
        );
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

  Future<List<Map<String, dynamic>>> getForecast(
    double latitude,
    double longitude,
  ) async {
    final String url =
        'https://api.openweathermap.org/data/2.5/forecast?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        Utility().printLog(
          "Weather forecast fetch failed. Status Code: ${response.statusCode}",
        );
        return [];
      }

      final data = jsonDecode(response.body);
      final List<dynamic> items = data['list'] ?? [];
      return items.map<Map<String, dynamic>>((item) {
        final weather = (item['weather'] as List).first;
        return {
          'dateTime': DateTime.fromMillisecondsSinceEpoch(
            (item['dt'] as num).toInt() * 1000,
          ),
          'temp': (item['main']['temp'] as num).toDouble(),
          'feelsLike': (item['main']['feels_like'] as num).toDouble(),
          'humidity': (item['main']['humidity'] as num).toDouble(),
          'windSpeed': (item['wind']?['speed'] as num?)?.toDouble() ?? 0,
          'condition': weather['main']?.toString() ?? 'Weather',
          'description': weather['description']?.toString() ?? '',
          'conditionId': (weather['id'] as num?)?.toInt() ?? 800,
        };
      }).toList();
    } on TimeoutException {
      Utility().printLog("Weather Forecast API Exception: Request timed out.");
      return [];
    } catch (e) {
      Utility().printLog("Weather Forecast API Exception: $e");
      return [];
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
  int? _conditionId;

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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) setState(() => _weatherCondition = "Fetching...");

      final weatherService = AgaAppWeatherForecast();
      final weatherData = await weatherService.getCurrentWeather(
        position.latitude,
        position.longitude,
      );

      if (weatherData != null && mounted) {
        setState(() {
          _currentTemp = "${weatherData['temp']}°C";
          _weatherCondition = weatherData['condition'];
          _conditionId = weatherData['conditionId'];
          _weatherIcon = _getOpenWeatherIcon(_conditionId!);
          _currentLocation = "Near at ${weatherData['cityName']}";
        });
        await WeatherForecastWidgetService.update(
          temp: weatherData['temp'] as int,
          feelsLike: weatherData['feelsLike'] as int,
          humidity: weatherData['humidity'] as int,
          windSpeed: weatherData['windSpeed'] as double,
          condition: weatherData['condition'].toString(),
          location: "Near at ${weatherData['cityName']}",
          forecast: weatherData['description'].toString(),
        );
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

  String _weatherBackgroundAsset() {
    final code = _conditionId;
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour >= 18;

    if (code == null) {
      return isNight
          ? 'assets/weather_backgrounds/night.png'
          : 'assets/weather_backgrounds/weather_cloudy.png';
    }
    if (code >= 200 && code < 300) {
      return 'assets/weather_backgrounds/weather_thunder_storm.png';
    }
    if (code >= 300 && code < 600) {
      return 'assets/weather_backgrounds/weather_rainy.png';
    }
    if (code == 800) {
      return isNight
          ? 'assets/weather_backgrounds/night.png'
          : 'assets/weather_backgrounds/weather_sunny.png';
    }
    if (isNight) return 'assets/weather_backgrounds/night.png';
    return 'assets/weather_backgrounds/weather_cloudy.png';
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.userName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : "Citizen";

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_weatherBackgroundAsset()),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.46),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Magandang araw, $firstName!",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _currentLocation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.thermostat,
                                color: Colors.white,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  "$_currentTemp • $_weatherCondition",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(_weatherIcon, color: Colors.white, size: 40),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            WeatherForecastScreen(userName: widget.userName),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Forecast",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
