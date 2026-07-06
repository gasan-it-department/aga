import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidBatteryOptimizationService {
  static const _channel = MethodChannel('aga/battery_optimization');

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isSupported) return true;

    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } on PlatformException catch (error) {
      debugPrint('Battery optimization status check failed: ${error.message}');
      return true;
    }
  }

  static Future<void> requestExemptionIfNeeded() async {
    if (!_isSupported) return;

    final alreadyExempt = await isIgnoringBatteryOptimizations();
    if (alreadyExempt) return;

    try {
      await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    } on PlatformException catch (error) {
      debugPrint(
        'Battery optimization exemption request failed: ${error.message}',
      );
    }
  }
}
