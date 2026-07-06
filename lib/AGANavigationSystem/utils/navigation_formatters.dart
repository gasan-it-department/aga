import '../models/eta_result.dart';
import '../models/navigation_state.dart';
import '../models/speed_sample.dart';

/// Display formatting helpers for navigation UI.
class NavigationFormatters {
  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
  }

  static String speedMetersPerSecond(double? speed) {
    if (speed == null) return '-- m/s';
    return '${speed.toStringAsFixed(1)} m/s';
  }

  static String speedKph(double? speedMetersPerSecond) {
    if (speedMetersPerSecond == null) return '-- km/h';
    return '${(speedMetersPerSecond * 3.6).toStringAsFixed(0)} km/h';
  }

  static String duration(Duration? duration) {
    if (duration == null) return '--';
    if (duration.inMinutes < 1) return '<1 min';
    if (duration.inHours < 1) return '${duration.inMinutes} min';
    final mins = duration.inMinutes.remainder(60);
    return '${duration.inHours}h ${mins}m';
  }

  static String arrivalTime(DateTime? time) {
    if (time == null) return '--';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static String progress(double progress) {
    return '${(progress.clamp(0, 1) * 100).toStringAsFixed(0)}%';
  }

  static String accuracy(double? meters) {
    if (meters == null) return '--';
    return '±${meters.toStringAsFixed(0)} m';
  }

  static String confidence(double confidence) {
    return '${(confidence.clamp(0, 1) * 100).toStringAsFixed(0)}%';
  }

  static String etaSource(EtaSource source) => source.name;
  static String speedSource(SpeedSource source) => source.name;
  static String status(NavigationStatus status) => status.name;
}
