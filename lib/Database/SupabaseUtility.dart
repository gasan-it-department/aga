import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasan_port_tracker/Utility/BuildStatus.dart';

class SupabaseUtility {
  // Maritime features are temporarily disabled across all app modes.
  static const bool maritimeEnabled = false;
  static const String developerModeKey = 'developer_mode_enabled';
  static const String developerAccessCode = 'GASAN-AGA-2026';

  // Cached synchronously so getSchema() (used during sync Supabase.initialize)
  // can read it without awaiting. Loaded once at app startup.
  static bool _developerMode = false;

  static bool get isDeveloperMode => _developerMode;

  Future<void> loadDeveloperMode() async {
    final prefs = await SharedPreferences.getInstance();
    _developerMode = prefs.getBool(developerModeKey) ?? false;
  }

  Future<void> setDeveloperMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(developerModeKey, enabled);
    _developerMode = enabled;
  }

  // GASAN SUPABASE DATABASE PASSWORD = 4fb426c5ca2635b67891faff075780b1a2d80de3ac5a3c754993d49d90f58c09
  String getSupabaseAnonKey() {
    return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVnYmJod3p0d2liY2doeHplaG5pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MzYwNzIsImV4cCI6MjA4NzAxMjA3Mn0.xzHHTJgmW3leDoAD4gyfvmkVYxZpky1H3ZY87zryoe8";
  }

  String getSupabaseProjectURL() {
    return "https://ugbbhwztwibcghxzehni.supabase.co";
  }

  String getGoogleOauthClientId() {
    return "815692412145-1797k9dnea57qrbl80qs0q9okfs4s4oe.apps.googleusercontent.com";
  }

  String getGoogleAndroidClientId() {
    return "815692412145-1fsro429pbdevqlqqpb97dho5tnos8k8.apps.googleusercontent.com";
  }

  String getGoogleIOSClientId() {
    return "815692412145-psq4eedm9kpedeofspgqs4qiloari1j2.apps.googleusercontent.com";
  }

  String getSchema() {
    if (BuildStatus().isDebugMode()) {
      return "test";
    }
    if (_developerMode) {
      return "test";
    }
    return "app_main_schema";
  }
}
