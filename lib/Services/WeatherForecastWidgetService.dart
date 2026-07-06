import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherForecastWidgetService {
  static const MethodChannel _channel = MethodChannel(
    'aga/weather_forecast_widget',
  );

  static Future<void> update({
    required int temp,
    required int feelsLike,
    required int humidity,
    required double windSpeed,
    required String condition,
    required String location,
    String forecast = 'Forecast updates when AGA opens.',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('weather_widget_temp', temp);
    await prefs.setInt('weather_widget_feels_like', feelsLike);
    await prefs.setInt('weather_widget_humidity', humidity);
    await prefs.setDouble('weather_widget_wind_speed', windSpeed);
    await prefs.setString('weather_widget_condition', condition);
    await prefs.setString('weather_widget_location', location);
    await prefs.setString('weather_widget_forecast', forecast);

    if (kIsWeb || !Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('updateWeatherForecastWidget', {
        'temp': temp,
        'feels_like': feelsLike,
        'humidity': humidity,
        'wind_speed': windSpeed,
        'condition': condition,
        'location': location,
        'forecast': forecast,
      });
    } catch (error) {
      debugPrint('Weather forecast widget update failed: $error');
    }
  }
}
