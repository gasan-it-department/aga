import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:gasan_port_tracker/Activities/MainNavigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:gasan_port_tracker/Services/OrderNotificationService.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gasan_port_tracker/Activities/AccountStatus/AccountStatusScreen.dart';
import 'package:gasan_port_tracker/Activities/Home/Cards/EmergencyCard.dart';
import 'package:gasan_port_tracker/Activities/Home/Drawer/HomeDrawer.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/EmergencyScreen.dart';
import 'package:gasan_port_tracker/Activities/NotificationCenter.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/FacebookFollowDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/InAppUpdate/AgaInAppUpdater.dart';
import 'package:gasan_port_tracker/Map/GeoCoding.dart';
import 'package:gasan_port_tracker/Utility/BuildStatus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ArtificialIntelligence/GoogleGeminiAI.dart';
import '../../Authentication/SupabaseAuthentication.dart';
import '../../Map/BorderWelcome.dart';
import '../Tourism/TouristSpotMap.dart';
import '../../Utility/Utility.dart';
import '../../WeatherForecasting/AgaAppWeatherForecast.dart';
import '../LoginSignup.dart';
import 'Cards/LiveTouristCard.dart';
import 'Cards/EventBannersCarousel.dart';
import 'Cards/DynamicDiningRow.dart';
import 'Cards/DictElguCard.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();

  // CACHED INSTANCES
  late final EmergencyCard _emergencyCard;
  late final LiveTourismCard _tourismCard;
  late final HomeDrawer _homeDrawer;

  // LIVE TOURISM DATA
  List<Map<String, dynamic>> _liveTourismSpots = [];

  bool _isMaritime = false;
  bool _isMDRRAdmin = false;
  bool _isTourismAdmin = false;
  bool _isCaptain = false;
  bool _isMDRRPersonnel = false;

  bool _isDataLoading = false;
  bool _hasUnreadNotifications = false;
  int _currentNotificationCount = 0;
  int _municipalZipCode = 0;

  String _userName = "Citizen";
  String _userEmail = "";
  String _userId = "";
  String? _userStatus;
  String? _avatarUrl;
  String? _assignedPort;
  String? _currentMunicipalName;

  SharedPreferences? _preferences;

  final Color gasanEmerald = const Color(0xFF10B981);
  final Color gasanAzure = const Color(0xFF3B82F6);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);

  @override
  void initState() {
    super.initState();
    _emergencyCard = EmergencyCard();
    _tourismCard = LiveTourismCard();
    _homeDrawer = HomeDrawer();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _preferences = await SharedPreferences.getInstance();
      _requestNotificationPermission();
      _loadInitialData();
    });
  }

  Future<void> _fetchTourismSpots(int municipalityZipCode) async {
    try {
      var query = supabase.from('tourist_spots').select();

      if (municipalityZipCode != 0) {
        query = query.eq('spot_municipality', municipalityZipCode);
      }

      final response = await query
          .limit(5)
          .order('spot_date_added', ascending: false);

      debugPrint("DEBUG: Fetched ${response.length} tourism spots for zip code: $municipalityZipCode.");

      if (mounted) {
        setState(() {
          _liveTourismSpots = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint("Tourism Fetch Error: $e");
    }
  }

  Future<void> _handleRefresh() async {
    final savedZipCode = _preferences?.getInt('current_zip_code') ?? 0;
    await Future.wait([
      _fetchTourismSpots(savedZipCode),
      _checkUnreadNotifications(),
    ]);
  }

  void _openAskAga() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AgaAppAssistant()),
    );
  }

  Future<void> _openNotificationCenter() async {
    setState(() => _hasUnreadNotifications = false);
    await _preferences?.setInt('saved_notification_count', _currentNotificationCount);

    if (mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationCenter())
      ).then((_) => _checkUnreadNotifications());
    }
  }

  // --- CORE LOGIC ---
  Future<void> _requestNotificationPermission() async {
    if (kIsWeb) {
      Utility().printLog("Running on Web: Skipping mobile notification permissions.");
      return;
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    bool permissionGranted = false;

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      permissionGranted = granted ?? false;

    } else if (Platform.isIOS) {
      final bool? granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      permissionGranted = granted ?? false;
    }

    if (permissionGranted) {
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        Utility().printLog("Starting Background Service safely...");
        await service.startService();
      }
    } else {
      _classicDialog.setTitle("Permission denied");
      _classicDialog.setMessage("To use the app, please allow all necessary permission.");
      _classicDialog.setCancelable(false);
      _classicDialog.setPositiveMessage("Exit App");
      if (mounted) {
        _classicDialog.showOnButtonDialog(context, () {
          _classicDialog.dismissDialog();
          Navigator.of(context).pop();
        });
      }
    }
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final List<dynamic> response = await supabase
          .from('global_notification')
          .select('notification_id');

      int fetchedCount = response.length;
      int savedCount = _preferences?.getInt('saved_notification_count') ?? 0;

      if (mounted) {
        setState(() {
          _currentNotificationCount = fetchedCount;
          _hasUnreadNotifications = fetchedCount > savedCount;
        });
      }
    } catch (e) {
      Utility().printLog("Error checking unread notifications: $e");
    }
  }

  Future<void> _loadInitialData() async {
    _loadingDialog.showLoadingDialog(context);
    final user = supabase.auth.currentUser;
    if (user == null) {
      _loadingDialog.dismiss();
      return;
    }

    // --- 1. GET CURRENT LOCATION FIRST ---
    String? currentMunicipality;
    int? currentZipCode;
    bool isNewMunicipality = false;
    if(_preferences?.getBool("isBorderChangeAuto") == null) _preferences?.setBool("isBorderChangeAuto", true);

    try {
      if(_preferences?.getBool("isBorderChangeAuto") == true){
        Utility().printLog("Border Change is automatic.");
        final locationDetails = await GeoCoding.getCurrentMunicipalityDetails();
        Utility().printLog("Location details: $locationDetails");

        if (locationDetails != null) {
          currentMunicipality = locationDetails.municipality;
          currentZipCode = locationDetails.zipCode;

          final savedMunicipality = _preferences?.getString('current_municipality');

          if (currentZipCode != null) {
            await _preferences?.setInt('current_zip_code', currentZipCode);
          }

          if (savedMunicipality != currentMunicipality) {
            isNewMunicipality = true;
            await _preferences?.setString('current_municipality', currentMunicipality);
          }

        } else {
          currentMunicipality = _preferences?.getString('current_municipality');
          currentZipCode = _preferences?.getInt('current_zip_code');
        }
      }else{
        currentMunicipality = _preferences?.getString('current_municipality');
        currentZipCode = _preferences?.getInt('current_zip_code');

        Utility().printLog("Border change is not automatic.");
        Utility().printLog("Using zip code: $currentZipCode");
        Utility().printLog("Using municipality: $currentMunicipality");
      }

      if (mounted) {
        setState(() {
          _currentMunicipalName = currentMunicipality;
          _municipalZipCode = currentZipCode ?? 0;
        });
      } else {
        _currentMunicipalName = currentMunicipality;
        _municipalZipCode = currentZipCode ?? 0;
      }
      debugPrint("Home zip resolved -> $_municipalZipCode municipality=$_currentMunicipalName");
    } catch (e) {
      Utility().printLog("Location fetch error: $e");
    }

    // --- 2. LOAD ACCOUNT DATA ---
    try {
      final userData = await supabase.from('user_data').select().eq('user_id', user.id).maybeSingle();
      if (userData == null) {
        _classicDialog.setTitle("Invalid Account Data");
        _classicDialog.setMessage("Your data from the database does not exist. Please re-login to refresh your account.");
        _classicDialog.setPositiveMessage("Logout");
        _classicDialog.setCancelable(false);
        if (mounted) {
          _classicDialog.showOnButtonDialog(context, () {
            _classicDialog.dismissDialog();
            _handleLogout();
          });
        }
        return;
      }

      bool tempMaritime = false;
      bool tempCaptain = false;
      bool tempMDRRAdmin = false;
      bool tempTourismAdmin = false;
      bool tempMDRRPersonnel = false;
      String? tempAssignedPort;

      final dynamic accessColumn = userData["user_access"];

      if (accessColumn != null) {
        List<dynamic> userAccessList = [];

        if (accessColumn is List) {
          userAccessList = accessColumn;
        } else if (accessColumn is Map) {
          if (accessColumn['access'] is List) {
            userAccessList = accessColumn['access'];
            _preferences!.setStringList("user_access", List<String>.from(userAccessList));
          }
          if (accessColumn["assigned_port"] != null) {
            tempAssignedPort = accessColumn["assigned_port"].toString();
            _preferences!.setString("assigned_port", tempAssignedPort);
          }
          if (accessColumn["assigned_port_id"] != null) {
            _preferences!.setString("assigned_port_id", accessColumn["assigned_port_id"].toString());
          }
          if (accessColumn["municipality_zip_code"] != null) {
            _preferences!.setString("municipality_zip_code", accessColumn["municipality_zip_code"].toString());
          }
        }

        if (userAccessList.isNotEmpty) {
          tempMaritime = userAccessList.any((role) => role.toString().toLowerCase() == "maritime");
          tempCaptain = userAccessList.any((role) => role.toString().toLowerCase() == "captain");
          tempMDRRAdmin = userAccessList.any((role) => role.toString().toLowerCase() == "mdrrmo");
          tempTourismAdmin = userAccessList.any((role) => role.toString().toLowerCase() == "tourism");
          tempMDRRPersonnel = userAccessList.any((role) => role.toString().toLowerCase() == "mdrrmo_personnel");
        }
      }

      _userStatus = userData["user_status"];

      if (mounted) {
        setState(() {
          _userName = userData['user_name'] ?? "Citizen";
          _userEmail = userData['user_account'] ?? "";
          _avatarUrl = userData['avatar_url'];
          _userId = userData["user_id"] ?? "";
          _isMaritime = tempMaritime;
          _isCaptain = tempCaptain;
          _isMDRRPersonnel = tempMDRRPersonnel;
          _isMDRRAdmin = tempMDRRAdmin;
          _isTourismAdmin = tempTourismAdmin;
          _assignedPort = tempAssignedPort;
        });

        if (_preferences != null) {
          _preferences!.setString("user_id", _userId);
          _preferences!.setString("user_name", _userName);
          _preferences!.setString("user_account", _userEmail);
          _preferences!.setString("avatar_url", _avatarUrl ?? "");
        }
        // Nudge the background service to (re)subscribe seller/user order
        // realtime channels now that user_id is known. The background isolate
        // has no auth session so RLS blocks its order subscriptions — we also
        // run them here in the foreground where the session is active.
        try {
          final svc = FlutterBackgroundService();
          svc.invoke('refresh_seller_channel');
          svc.invoke('refresh_user_orders_channel');
        } catch (_) {}
        // Foreground order realtime listener (this is the one that actually
        // delivers buyer/seller order notifications, since it uses the
        // authenticated client).
        OrderNotificationService.instance.start(_userId);
        AgaInAppUpdater().checkForUpdates(context, _userEmail);
      }

      // --- 3. FETCH DEPENDENT DATA CONCURRENTLY ---
      await Future.wait([
        _fetchTourismSpots(currentZipCode ?? 0),
        _checkUnreadNotifications(),
      ]);

      if (mounted) _loadingDialog.dismiss();

      if (isNewMunicipality && currentMunicipality != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BorderWelcome(
              municipalityName: currentMunicipality!,
              onProceed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }

      _evaluateFacebookDialog();

      if (_userStatus != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AccountStatusScreen(status: _userStatus!)));
      }
      _updateLastAppUsageDate();
    } catch (error, stackTrace) {
      if (mounted) _loadingDialog.dismiss();
      _showError("Error: ${error.toString()}\n\n"
          "Stacktrace: ${stackTrace.toString()}");
    }
  }

  void _evaluateFacebookDialog() {
    if (_preferences == null) return;
    int launchCount = _preferences!.getInt('fb_dialog_launch_count') ?? 0;
    int lastShownEpoch = _preferences!.getInt('fb_dialog_last_shown') ?? 0;
    launchCount++;
    _preferences!.setInt('fb_dialog_launch_count', launchCount);

    final now = DateTime.now().millisecondsSinceEpoch;
    final sevenDaysInMillis = 7 * 24 * 60 * 60 * 1000;
    if (launchCount >= 5 && (now - lastShownEpoch) > sevenDaysInMillis) {
      if (Random().nextInt(100) < 15) {
        _preferences!.setInt('fb_dialog_last_shown', now);
        if (mounted) {
          FacebookFollowDialog.show(
            context,
            url: "https://facebook.com/people/AGA-App/61583655513664/",
            pageName: "AGA",
          );
        }
      }
    }
  }

  Future<void> _updateLastAppUsageDate() async {
    final String currentDate = Utility().getCurrentReadableDate("MMMM dd yyyy hh:mm a");
    await supabase
        .from('user_data')
        .update({'user_app_last_use': currentDate})
        .eq('user_id', _userId);
  }

  void _handleLogout() async {
    try {
      _loadingDialog.showLoadingDialog(context);
      await SupabaseAuthentication().signOut();
      _loadingDialog.dismiss();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginSignup()));
    } catch (error) {
      _loadingDialog.dismiss();
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    Utility().printLog("Error: $message");
    _classicDialog.setTitle("Something went wrong!");
    _classicDialog.setMessage(message);
    _classicDialog.setCancelable(false);
    _classicDialog.setPositiveMessage("Close");
    if (mounted) {
      _classicDialog.showOnButtonDialog(context, () {
        _classicDialog.dismissDialog();
      });
    }
  }

  // --- UI WIDGETS ---

  Widget _buildNoTourismSpotsPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.travel_explore_rounded, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Tourist Spots Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "There are currently no listed spots for your area.\nPlease check back later!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxScreenWidth = Utility().getMaxScreenSize();

    return Scaffold(
      backgroundColor: bgColor,
      onDrawerChanged: (isOpen) {
        MainNavigation.drawerOpen.value = isOpen;
      },
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        centerTitle: true,
        title: const Text("AGA", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 5, right: 10),
            child: IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 28),
                  if (_hasUnreadNotifications)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                      ),
                    ),
                ],
              ),
              onPressed: _openNotificationCenter,
            ),
          )
        ],
      ),

      drawer: _homeDrawer.buildDrawer(primaryDark, context, _userName, _userEmail, _isMaritime, _isCaptain, _isMDRRAdmin, _isTourismAdmin, _isMDRRPersonnel, _assignedPort, _avatarUrl),

      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxScreenWidth),
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: primaryDark,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                if (BuildStatus().isDebugMode())
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      color: Colors.orange.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bug_report_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text("DEBUG MODE ACTIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: WeatherHeaderWidget(userName: _userName),
                    )
                ),

                SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: _emergencyCard.buildEmergencyCard(context),
                    )
                ),

                SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: EventBannersCarousel(zipCode: _municipalZipCode),
                    )
                ),

                SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: DynamicDiningRow(municipalZipCode: _municipalZipCode),
                    )
                ),

                const SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: DictElguCard(),
                    )
                ),

                SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: _liveTourismSpots.isEmpty
                          ? _buildNoTourismSpotsPlaceholder()
                      // FIXED NULL SAFETY HERE: _currentMunicipalName ?? "Marinduque"
                          : _tourismCard.buildTourismCard(primaryDark, context, _liveTourismSpots, _currentMunicipalName ?? "Marinduque", _municipalZipCode),
                    )
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
