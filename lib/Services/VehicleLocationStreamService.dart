import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehicleLocationStreamService {
  static final VehicleLocationStreamService _instance = VehicleLocationStreamService._internal();
  factory VehicleLocationStreamService() => _instance;
  VehicleLocationStreamService._internal();

  /// Starts the tracking by sending a command to the ALREADY RUNNING background service
  Future<void> startTracking(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tracking_vehicle_id', vehicleId);

    // Send event to the background isolate to trigger Geolocator
    FlutterBackgroundService().invoke('start_location_tracking', {
      'vehicle_id': vehicleId,
    });
  }

  /// Stops the tracking and reverts the notification
  Future<void> stopTracking() async {
    // Send event to the background isolate to cancel the Geolocator stream
    FlutterBackgroundService().invoke('stop_location_tracking');
  }
}
