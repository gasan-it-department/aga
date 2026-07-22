import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/EmergencyScreen.dart';
import 'package:gasan_port_tracker/Activities/MainNavigation.dart';
import 'package:gasan_port_tracker/Activities/LoginSignup.dart';
import 'package:gasan_port_tracker/Authentication/SupabaseAuthentication.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/ImageDirectory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'Services/AndroidBatteryOptimizationService.dart';
import 'Services/BackgroundService.dart';
import 'Utility/Utility.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseUtility().loadDeveloperMode();

  await Supabase.initialize(
    url: SupabaseUtility().getSupabaseProjectURL(),
    anonKey: SupabaseUtility().getSupabaseAnonKey(),
    postgrestOptions: PostgrestClientOptions(
      schema: SupabaseUtility().getSchema(),
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF059669)),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      builder: (context, child) {
        if (SupabaseUtility.isDeveloperMode) {
          return Banner(
            message: 'DEVELOPER',
            location: BannerLocation.topEnd,
            color: const Color(0xFFDC2626),
            child: child ?? const SizedBox.shrink(),
          );
        }
        return child ?? const SizedBox.shrink();
      },
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;
  final Color primaryGreen = const Color(0xFF059669);
  final Color darkGreen = const Color(0xFF064E3B);
  final Color bgColor = const Color(0xFFFDFDFD);

  @override
  void initState() {
    super.initState();
    _setupAuthListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    _logAuthProviderId(supabase.auth.currentUser);
    _initLogic();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    List<Permission> permissionsToRequest = [
      Permission.location,
      Permission.locationAlways,
      Permission.notification,
    ];

    await permissionsToRequest.request();
    await AndroidBatteryOptimizationService.requestExemptionIfNeeded();
  }

  void _initLogic() async {
    if (await Utility().hasInternetConnection()) {
      await Future.delayed(const Duration(seconds: 2));

      if (SupabaseAuthentication().isUserAuthenticated()) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginSignup()),
          );
        }
      }
    } else {
      if (mounted) {
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.neutral,
          "You're currently offline",
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EmergencyScreen()),
        );
      }
    }

    if (!kIsWeb) {
      Utility().printLog("Background service is starting...");
      PermissionStatus status = await Permission.notification.status;

      if (!status.isGranted) {
        status = await Permission.notification.request();
      }

      if (status.isDenied || status.isPermanentlyDenied) {
        Utility().printLog( 
          "Notification permission denied by user. Background notifications may be limited.",
        );
      }

      final bgService = NotificationBackgroundService();
      await bgService.initialize();
    }
  }

  void _setupAuthListener() async {
    if (kIsWeb) {
      supabase.auth.onAuthStateChange.listen((data) async {
        if (data.session != null) {
          _logAuthProviderId(data.session!.user);
          if (await _userDataExist(data.session!.user.id) == false) {
            await _createUserData(data.session!.user);
          }
        }
      });
    }
  }

  void _logAuthProviderId(User? user) {
    if (user == null) {
      Utility().printLog("Auth provider_id: <no authenticated user>");
      return;
    }

    String? providerId;
    for (final identity in user.identities ?? []) {
      final data = identity.identityData;
      providerId =
          data?['provider_id']?.toString() ??
          data?['sub']?.toString() ??
          identity.id;
      if (providerId != null && providerId.isNotEmpty) break;
    }

    Utility().printLog(
      "Auth provider_id: ${providerId ?? '<none>'} user_id=${user.id}",
    );
  }

  Future<void> _createUserData(User? user) async {
    final String? email = user?.email;
    final String? fullName = user?.userMetadata?['full_name'];
    final String? avatarUrl = user?.userMetadata?['avatar_url'];
    final String? userId = user?.id;

    final userData = {
      'user_name': fullName,
      'user_account': email,
      'user_id': userId,
      'avatar_url': avatarUrl,
      'user_access': null,
    };

    await supabase.from("user_data").insert(userData);
  }

  Future<bool> _userDataExist(String userId) async {
    try {
      final List<dynamic> result = await supabase
          .from('user_data')
          .select('user_id')
          .eq('user_id', userId)
          .limit(1);
      return result.isNotEmpty;
    } catch (error) {
      Utility().printLog("Database Error: ${error.toString()}");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    ImageDirectory().getOfficialRoundedLogoPath(),
                    width: 80,
                    height: 80,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                "AGA",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: darkGreen,
                  letterSpacing: 2.0,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Municipality of Gasan",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: primaryGreen,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
