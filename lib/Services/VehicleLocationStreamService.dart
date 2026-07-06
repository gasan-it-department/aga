import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Database/SupabaseUtility.dart';

class VehicleLocationStreamService {
  static final VehicleLocationStreamService _instance =
      VehicleLocationStreamService._internal();
  factory VehicleLocationStreamService() => _instance;
  VehicleLocationStreamService._internal();

  /// Starts the tracking by sending a command to the ALREADY RUNNING background service
  Future<void> startTracking(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tracking_vehicle_id', vehicleId);
    await prefs.setString('tracking_schema', SupabaseUtility().getSchema());

    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
      await Future.delayed(const Duration(seconds: 1));
    }

    final session = Supabase.instance.client.auth.currentSession;
    service.invoke('start_location_tracking', {
      'vehicle_id': vehicleId,
      'schema': SupabaseUtility().getSchema(),
      'refresh_token': session?.refreshToken,
    });
  }

  /// Stops the tracking and reverts the notification
  Future<void> stopTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tracking_vehicle_id');
    await prefs.remove('tracking_schema');
    FlutterBackgroundService().invoke('stop_location_tracking');
  }
}
