import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';
import 'package:gasan_port_tracker/Activities/Maritime/ViewShippingLinesDetails.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:gasan_port_tracker/Services/BackgroundService.dart';
import 'package:gasan_port_tracker/Services/WebPushNotificationService.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gasan_port_tracker/Activities/AccountStatus/AccountStatusScreen.dart';
import 'package:gasan_port_tracker/Activities/AnnouncementDetails.dart';
import 'package:gasan_port_tracker/Activities/AnnouncementsList.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/EmergencyScreen.dart';
import 'package:gasan_port_tracker/Activities/Tourism/MarinduqueTravelGuide.dart';
import 'package:gasan_port_tracker/Activities/MainNavigation.dart';
import 'package:gasan_port_tracker/Activities/CommunityIssueReport.dart';
import 'package:gasan_port_tracker/Activities/MarketplaceShops.dart';
import 'package:gasan_port_tracker/Activities/NotificationCenter.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/FacebookFollowDialog.dart';
import 'package:gasan_port_tracker/Dialogs/HomePopupDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/InAppUpdate/AgaInAppUpdater.dart';
import 'package:gasan_port_tracker/Map/GeoCoding.dart';
import 'package:gasan_port_tracker/Utility/BuildStatus.dart';
import 'package:gasan_port_tracker/Utility/SupabaseExternalAuthBridge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Authentication/SupabaseAuthentication.dart';
import '../../Map/BorderWelcome.dart';
import '../../Utility/Utility.dart';
import '../LoginSignup.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();

  bool _hasUnreadNotifications = false;
  int _currentNotificationCount = 0;
  int _municipalZipCode = 0;

  String _userName = "Citizen";
  String _userEmail = "";
  String _userId = "";
  String? _userStatus;
  String? _avatarUrl;
  String? _currentMunicipalName;
  bool _morionPopupScheduled = false;
  bool _morionPopupShown = false;
  bool _travelGuideShown = false;

  SharedPreferences? _preferences;

  final Color gasanEmerald = const Color(0xFF10B981);
  final Color gasanAzure = const Color(0xFF3B82F6);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0F2042);
  bool _announcementsLoading = true;
  List<Map<String, dynamic>> _announcements = [];

  final PageController _promoPageController = PageController();
  int _currentPromoPage = 0;
  Timer? _promoTimer;
  final List<String> _promoBanners = [
    "https://ugbbhwztwibcghxzehni.supabase.co/storage/v1/object/public/content_management/Home%20Banners/ChatGPT%20Image%20Jul%201,%202026,%2009_51_19%20AM.png",
    "https://ugbbhwztwibcghxzehni.supabase.co/storage/v1/object/public/content_management/Home%20Banners/ChatGPT%20Image%20Jul%201,%202026,%2010_01_43%20AM.png",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _preferences = await SharedPreferences.getInstance();
      _requestNotificationPermission();
      _loadInitialData().whenComplete(_scheduleMorionPopup);
    });
    _promoTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_promoPageController.hasClients) {
        _currentPromoPage = (_currentPromoPage + 1) % _promoBanners.length;
        _promoPageController.animateToPage(
          _currentPromoPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _promoPageController.dispose();
    super.dispose();
  }

  void _scheduleMorionPopup() {
    return; // Temporarily disabled popup banner
    if (_morionPopupScheduled || _morionPopupShown || _userId.isEmpty) return;
    _morionPopupScheduled = true;

    Future<void>.delayed(const Duration(seconds: 2), () {
      _morionPopupScheduled = false;
      if (!mounted || _morionPopupShown || _userId.isEmpty) return;

      final route = ModalRoute.of(context);
      if (route?.isCurrent != true) {
        _scheduleMorionPopup();
        return;
      }

      _morionPopupShown = true;
      HomePopupDialog.show(context);
    });
  }

  Future<void> _handleRefresh() async {
    await Future.wait([_checkUnreadNotifications(), _loadAnnouncements()]);
  }

  Future<void> _loadAnnouncements() async {
    if (mounted) setState(() => _announcementsLoading = true);
    try {
      final response = await SupabaseExternalAuthBridge().getAnnouncements(
        page: 1,
        perPage: 3,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }
      final decoded = jsonDecode(response.body);
      final rows = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (!mounted) return;
      setState(() {
        _announcements = rows is List
            ? rows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : <Map<String, dynamic>>[];
      });
    } catch (error) {
      debugPrint('Announcements load error: $error');
      if (mounted) setState(() => _announcements = []);
    } finally {
      if (mounted) setState(() => _announcementsLoading = false);
    }
  }

  Future<void> _openNotificationCenter() async {
    setState(() => _hasUnreadNotifications = false);
    await _preferences?.setInt(
      'saved_notification_count',
      _currentNotificationCount,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationCenter()),
      ).then((_) => _checkUnreadNotifications());
    }
  }

  // --- CORE LOGIC ---
  Future<void> _requestNotificationPermission() async {
    if (kIsWeb) {
      Utility().printLog(
        "Running on Web: Skipping mobile notification permissions.",
      );
      return;
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    bool permissionGranted = false;

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      final bool? granted = await androidImplementation
          ?.requestNotificationsPermission();
      permissionGranted = granted ?? false;
    } else if (Platform.isIOS) {
      final bool? granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
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
      _classicDialog.setMessage(
        "To use the app, please allow all necessary permission.",
      );
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
      final userId = supabase.auth.currentUser?.id;
      final responses = await Future.wait<dynamic>([
        Future<dynamic>(() async {
          return await supabase
              .from('global_notification')
              .select('notification_id');
        }),
        if (userId != null)
          Future<dynamic>(() async {
            return await supabase
                .from('user_data')
                .select('limited_notifications')
                .eq('user_id', userId)
                .maybeSingle();
          }),
      ]);

      final globalNotifications = List<dynamic>.from(responses.first as List);
      final readIds = _preferences?.getStringList('read_notifications') ?? [];
      final deletedIds =
          _preferences?.getStringList('deleted_notifications') ?? [];
      final hasUnreadGlobal = globalNotifications.any((notification) {
        final id = notification['notification_id']?.toString() ?? '';
        return id.isNotEmpty &&
            !readIds.contains(id) &&
            !deletedIds.contains(id);
      });

      bool hasUnreadPersonal = false;
      if (userId != null && responses.length > 1) {
        final userData = responses[1];
        if (userData is Map) {
          final personalNotifications = userData['limited_notifications'];
          if (personalNotifications is List) {
            hasUnreadPersonal = personalNotifications.any((notification) {
              if (notification is! Map) return false;
              final id = notification['id']?.toString() ?? '';
              return id.isNotEmpty && !readIds.contains(id);
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _currentNotificationCount = globalNotifications.length;
          _hasUnreadNotifications = hasUnreadGlobal || hasUnreadPersonal;
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
    bool showTravelGuide = false;
    String? detectedOutsideLocation;
    if (_preferences?.getBool("isBorderChangeAuto") == null) {
      _preferences?.setBool("isBorderChangeAuto", true);
    }

    try {
      if (_preferences?.getBool("isBorderChangeAuto") == true) {
        Utility().printLog("Border Change is automatic.");
        final locationDetails = await GeoCoding.getCurrentMunicipalityDetails();
        Utility().printLog("Location details: $locationDetails");

        if (locationDetails != null) {
          if (GeoCoding.isWithinMarinduque(locationDetails)) {
            currentMunicipality = locationDetails.municipality;
            currentZipCode = locationDetails.zipCode;
          } else {
            showTravelGuide = true;
            detectedOutsideLocation =
                [locationDetails.municipality, locationDetails.province]
                    .whereType<String>()
                    .where((value) => value.trim().isNotEmpty)
                    .join(', ');
            currentMunicipality = '';
            currentZipCode = 0;
            await _preferences?.setString('current_municipality', '');
            await _preferences?.setInt('current_zip_code', 0);
          }

          final savedMunicipality = _preferences?.getString(
            'current_municipality',
          );

          if (currentZipCode != null) {
            await _preferences?.setInt('current_zip_code', currentZipCode);
          }

          if (!showTravelGuide && savedMunicipality != currentMunicipality) {
            isNewMunicipality = true;
            await _preferences?.setString(
              'current_municipality',
              currentMunicipality,
            );
          }
        } else {
          currentMunicipality = _preferences?.getString('current_municipality');
          currentZipCode = _preferences?.getInt('current_zip_code');
        }
      } else {
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
      debugPrint(
        "Home zip resolved -> $_municipalZipCode municipality=$_currentMunicipalName",
      );
    } catch (e) {
      Utility().printLog("Location fetch error: $e");
    }

    // --- 2. LOAD ACCOUNT DATA ---
    try {
      final userData = await supabase
          .from('user_data')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (userData == null) {
        _classicDialog.setTitle("Invalid Account Data");
        _classicDialog.setMessage(
          "Your data from the database does not exist. Please re-login to refresh your account.",
        );
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

      final dynamic accessColumn = userData["user_access"];

      if (accessColumn != null) {
        List<dynamic> userAccessList = [];

        if (accessColumn is List) {
          userAccessList = accessColumn;
        } else if (accessColumn is Map) {
          if (accessColumn['access'] is List) {
            userAccessList = accessColumn['access'];
            _preferences!.setStringList(
              "user_access",
              List<String>.from(userAccessList),
            );
          }
          if (accessColumn["assigned_port"] != null) {
            _preferences!.setString(
              "assigned_port",
              accessColumn["assigned_port"].toString(),
            );
          }
          if (accessColumn["assigned_port_id"] != null) {
            _preferences!.setString(
              "assigned_port_id",
              accessColumn["assigned_port_id"].toString(),
            );
          }
          if (accessColumn["municipality_zip_code"] != null) {
            _preferences!.setString(
              "municipality_zip_code",
              accessColumn["municipality_zip_code"].toString(),
            );
          }
        }
      }

      _userStatus = userData["user_status"];

      if (mounted) {
        setState(() {
          _userName = userData['user_name'] ?? "Citizen";
          _userEmail = userData['user_account'] ?? "";
          _avatarUrl = userData['avatar_url'];
          _userId = userData["user_id"] ?? "";
        });

        if (_preferences != null) {
          _preferences!.setString("user_id", _userId);
          _preferences!.setString("user_name", _userName);
          _preferences!.setString("user_account", _userEmail);
          _preferences!.setString("avatar_url", _avatarUrl ?? "");
        }
        // Hand the current session to the isolated notification service.
        final session = supabase.auth.currentSession;
        _logAuthTokens(session);
        _authenticateExternalApi();
        if (!kIsWeb && session != null) {
          await NotificationBackgroundService().setAuthenticatedUser(session);
        }
        if (!mounted) return;
        WebPushNotificationService.instance.initializeForUser(_userId);
        AgaInAppUpdater().checkForUpdates(context, _userEmail);
      }

      // --- 3. FETCH DEPENDENT DATA CONCURRENTLY ---
      await Future.wait([_checkUnreadNotifications(), _loadAnnouncements()]);

      if (mounted) _loadingDialog.dismiss();

      if (showTravelGuide && !_travelGuideShown && mounted) {
        _travelGuideShown = true;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MarinduqueTravelGuide(currentLocation: detectedOutsideLocation),
          ),
        );
      } else if (isNewMunicipality && currentMunicipality != null && mounted) {
        await BorderWelcome.show(
          context,
          municipalityName: currentMunicipality,
        );
      }

      _evaluateFacebookDialog();

      if (_userStatus != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AccountStatusScreen(status: _userStatus!),
          ),
        );
      }
      _updateLastAppUsageDate();
    } catch (error, stackTrace) {
      if (mounted) _loadingDialog.dismiss();
      _showError(
        "Error: ${error.toString()}\n\n"
        "Stacktrace: ${stackTrace.toString()}",
      );
    }
  }

  void _logAuthTokens(Session? session) {
    final user = session?.user ?? supabase.auth.currentUser;
    Utility().printLog(
      'Supabase access token: ${session?.accessToken ?? '<none>'}',
    );
    Utility().printLog(
      'Google provider token: ${session?.providerToken ?? '<none>'}',
    );
    Utility().printLog(
      'Google provider refresh token: ${session?.providerRefreshToken ?? '<none>'}',
    );

    for (final identity in user?.identities ?? []) {
      final data = identity.identityData;
      final providerId =
          data?['provider_id']?.toString() ??
          data?['sub']?.toString() ??
          identity.id;
      Utility().printLog(
        'Auth identity provider=${identity.provider} provider_id=$providerId',
      );
    }
  }

  Future<void> _authenticateExternalApi() async {
    try {
      final bridge = SupabaseExternalAuthBridge();
      await bridge.authenticate();
      await bridge.getCommunityReportSubmissionContext();
    } catch (error) {
      Utility().printLog('External auth bridge failed: $error');
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
    final String currentDate = Utility().getCurrentReadableDate(
      "MMMM dd yyyy hh:mm a",
    );
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
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginSignup()),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final double maxScreenWidth = Utility().getMaxScreenSize();

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxScreenWidth),
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: primaryDark,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildHeader(),

                SliverToBoxAdapter(
                  child: RepaintBoundary(child: _buildQuickServicesSection()),
                ),

                SliverToBoxAdapter(
                  child: RepaintBoundary(child: _buildPromoCard()),
                ),

                SliverToBoxAdapter(
                  child: RepaintBoundary(child: _buildAnnouncementsSection()),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    String greeting = "Good Morning,";
    if (hour >= 12 && hour < 18) {
      greeting = "Good Afternoon,";
    } else if (hour >= 18 || hour < 5) {
      greeting = "Good Evening,";
    }

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      expandedHeight: 140,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                'assets/home_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.bottomRight,
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (BuildStatus().isDebugMode())
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bug_report_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "DEBUG MODE ACTIVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 8,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F2042),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Welcome to AGA!',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            onPressed: _openNotificationCenter,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF0F2042),
                  size: 26,
                ),
                if (_hasUnreadNotifications)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_currentNotificationCount > 0 ? _currentNotificationCount : 3}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickServicesSection() {
    final List<_QuickServiceItem> allItems = [
      _QuickServiceItem(
        title: 'Community\nReport',
        icon: Icons.report_problem_rounded,
        bgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CommunityIssueReport()),
        ),
      ),
      _QuickServiceItem(
        title: 'Market\nplace',
        icon: Icons.storefront_rounded,
        bgColor: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF10B981),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MarketplaceShops()),
        ),
      ),
      _QuickServiceItem(
        title: 'Tourism',
        icon: Icons.travel_explore_rounded,
        bgColor: const Color(0xFFFFF7ED),
        iconColor: const Color(0xFFD97706),
        onTap: () => MainNavigation.selectedTab.value = 1,
      ),
      _QuickServiceItem(
        title: 'Emergency',
        icon: Icons.emergency_share_rounded,
        bgColor: const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFDC2626),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyScreen()),
        ),
      ),
      _QuickServiceItem(
        title: 'Events',
        icon: Icons.event_available_rounded,
        bgColor: const Color(0xFFF1F5F9),
        iconColor: const Color(0xFF94A3B8),
        isComingSoon: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Events service is coming soon!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF0F2042),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
      _QuickServiceItem(
        title: 'Request\nAmbulance',
        icon: Icons.airport_shuttle_rounded,
        bgColor: const Color(0xFFF1F5F9),
        iconColor: const Color(0xFF94A3B8),
        isComingSoon: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Ambulance requesting service is coming soon!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF0F2042),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
      // Show Maritime (active) in debug/developer mode, otherwise Transportation (coming soon)
      if (kDebugMode || SupabaseUtility.isDeveloperMode)
        _QuickServiceItem(
          title: 'Maritime',
          icon: Icons.directions_boat_rounded,
          bgColor: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF1E40AF),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ViewShippingLinesDetails()),
          ),
        )
      else
        _QuickServiceItem(
          title: 'Transportation',
          icon: Icons.directions_boat_rounded,
          bgColor: const Color(0xFFF1F5F9),
          iconColor: const Color(0xFF94A3B8),
          isComingSoon: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Transportation service is coming soon!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFF0F2042),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        ),
    ];

    final items = allItems;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Panel',
            style: TextStyle(
              color: Color(0xFF0F2042),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No service found.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length; i += 4) ...[
                    if (i > 0) const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (index) {
                        final itemIndex = i + index;
                        if (itemIndex < items.length) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _buildQuickServiceCard(items[itemIndex]),
                            ),
                          );
                        } else {
                          return const Expanded(child: SizedBox());
                        }
                      }),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickServiceCard(_QuickServiceItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 26),
              ),
              if (item.isComingSoon)
                Positioned(
                  top: -5,
                  right: -7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Text(
                      'SOON',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 6.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F2042),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bannerHeight =
              ((constraints.maxWidth / (1693 / 929))
                      .clamp(150.0, 250.0)
                      .toDouble() -
                  10) *
              0.90;

          return SizedBox(
            height: bannerHeight,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.white),
                    ),
                    PageView.builder(
                      controller: _promoPageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPromoPage = index;
                        });
                      },
                      itemCount: _promoBanners.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          _promoBanners[index],
                          width: double.infinity,
                          height: bannerHeight,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF1E3A8A),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_promoBanners.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPromoPage == index ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPromoPage == index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Latest Announcements',
                style: TextStyle(
                  color: Color(0xFF0F2042),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnnouncementsList()),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_announcementsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          else if (_announcements.isEmpty)
            _emptyAnnouncementCard()
          else
            Column(
              children: _announcements
                  .take(3)
                  .map(
                    (announcement) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _announcementCard(announcement),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _announcementCard(Map<String, dynamic> announcement) {
    final announcementId = announcement['id']?.toString() ?? '';
    final type = announcement['type'];
    final typeLabel = type is Map
        ? type['label']?.toString() ?? 'Announcement'
        : 'Announcement';
    final coverImageUrl = announcement['cover_image_url']?.toString();

    return InkWell(
      onTap: announcementId.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnnouncementDetails(
                  announcementId: announcementId,
                  initialAnnouncement: announcement,
                ),
              ),
            ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 58,
                height: 58,
                child: coverImageUrl != null && coverImageUrl.isNotEmpty
                    ? Image.network(
                        coverImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _announcementIcon(),
                      )
                    : _announcementIcon(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    announcement['title']?.toString() ?? 'Announcement',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F2042),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    announcement['excerpt']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    announcement['created_at']?.toString() ?? '',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _announcementIcon() {
    return Container(
      color: const Color(0xFFEFF6FF),
      child: const Icon(
        Icons.campaign_rounded,
        color: Color(0xFF2563EB),
        size: 26,
      ),
    );
  }

  Widget _emptyAnnouncementCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'No announcements yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuickServiceItem {
  final String title;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isComingSoon;
  const _QuickServiceItem({
    required this.title,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
    this.isComingSoon = false,
  });
}

class GovernmentBuildingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2F0FD)
      ..style = PaintingStyle.fill;

    final pathHills = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.72,
        size.width * 0.5,
        size.height * 0.83,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.88,
        size.width,
        size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(pathHills, paint);

    paint.color = const Color(0xFFEEF6FC);
    final pathHills2 = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.81,
        size.width * 0.65,
        size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.85,
        size.width,
        size.height * 0.89,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(pathHills2, paint);

    final double buildingWidth = size.width * 0.55;
    final double buildingHeight = size.height * 0.38;
    final double left = size.width - buildingWidth - 10;
    final double bottom = size.height;
    final double top = bottom - buildingHeight;

    paint.color = const Color(0xFFB0C4DE);
    canvas.drawRect(
      Rect.fromLTWH(left - 8, bottom - 4, buildingWidth + 16, 4),
      paint,
    );
    paint.color = const Color(0xFFC0D6E4);
    canvas.drawRect(
      Rect.fromLTWH(left - 4, bottom - 8, buildingWidth + 8, 4),
      paint,
    );
    paint.color = const Color(0xFFD4E6F1);
    canvas.drawRect(Rect.fromLTWH(left, bottom - 12, buildingWidth, 4), paint);

    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(
        left + 10,
        top + 30,
        buildingWidth - 20,
        buildingHeight - 42,
      ),
      paint,
    );

    final double centerWidth = buildingWidth * 0.42;
    final double centerLeft = left + (buildingWidth - centerWidth) / 2;
    canvas.drawRect(
      Rect.fromLTWH(centerLeft, top + 15, centerWidth, buildingHeight - 27),
      paint,
    );

    final strokePaint = Paint()
      ..color = const Color(0xFF9FB2C6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(
      Rect.fromLTWH(
        left + 10,
        top + 30,
        buildingWidth - 20,
        buildingHeight - 42,
      ),
      strokePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(centerLeft, top + 15, centerWidth, buildingHeight - 27),
      strokePaint,
    );

    final pathPediment = Path()
      ..moveTo(centerLeft - 3, top + 15)
      ..lineTo(centerLeft + centerWidth / 2, top - 8)
      ..lineTo(centerLeft + centerWidth + 3, top + 15)
      ..close();
    paint.color = Colors.white;
    canvas.drawPath(pathPediment, paint);
    canvas.drawPath(pathPediment, strokePaint);

    canvas.drawCircle(
      Offset(centerLeft + centerWidth / 2, top + 6),
      3,
      strokePaint,
    );

    final double pillarSpacing = centerWidth / 6;
    for (int i = 1; i <= 5; i++) {
      double px = centerLeft + i * pillarSpacing;
      canvas.drawLine(
        Offset(px, top + 15),
        Offset(px, bottom - 12),
        strokePaint,
      );
    }

    final double wingWidth = (buildingWidth - centerWidth) / 2 - 10;
    final double leftWingStart = left + 10;
    final double wingPillarSpacing = wingWidth / 5;
    for (int i = 1; i <= 4; i++) {
      double px = leftWingStart + i * wingPillarSpacing;
      canvas.drawLine(
        Offset(px, top + 30),
        Offset(px, bottom - 12),
        strokePaint,
      );
    }
    final double rightWingStart = centerLeft + centerWidth;
    for (int i = 1; i <= 4; i++) {
      double px = rightWingStart + i * wingPillarSpacing;
      canvas.drawLine(
        Offset(px, top + 30),
        Offset(px, bottom - 12),
        strokePaint,
      );
    }

    final double domeRadius = centerWidth * 0.22;
    final Offset domeCenter = Offset(
      centerLeft + centerWidth / 2,
      top - domeRadius * 0.4,
    );
    paint.color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: domeCenter, radius: domeRadius),
      3.14159,
      3.14159,
      true,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: domeCenter, radius: domeRadius),
      3.14159,
      3.14159,
      true,
      strokePaint,
    );

    final double flagPoleTop = domeCenter.dy - domeRadius - 20;
    canvas.drawLine(
      Offset(domeCenter.dx, domeCenter.dy - domeRadius),
      Offset(domeCenter.dx, flagPoleTop),
      strokePaint,
    );

    final flagPath = Path()
      ..moveTo(domeCenter.dx, flagPoleTop)
      ..lineTo(domeCenter.dx + 12, flagPoleTop + 3)
      ..lineTo(domeCenter.dx + 12, flagPoleTop + 8)
      ..lineTo(domeCenter.dx, flagPoleTop + 5)
      ..close();
    paint.color = const Color(0xFFEF4444);
    canvas.drawPath(flagPath, paint);
    strokePaint.color = const Color(0xFF2563EB);
    canvas.drawLine(
      Offset(domeCenter.dx, flagPoleTop),
      Offset(domeCenter.dx + 12, flagPoleTop + 3),
      strokePaint,
    );
    strokePaint.color = const Color(0xFF9FB2C6);

    final treePaint1 = Paint()
      ..color = const Color(0xFF66BB6A).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final treePaint2 = Paint()
      ..color = const Color(0xFF388E3C).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final treePaint3 = Paint()
      ..color = const Color(0xFF9CCC65).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(left + 2, bottom - 10), 14, treePaint2);
    canvas.drawCircle(Offset(left + 15, bottom - 12), 18, treePaint1);
    canvas.drawCircle(Offset(left - 10, bottom - 8), 10, treePaint3);

    canvas.drawCircle(
      Offset(left + buildingWidth - 2, bottom - 10),
      14,
      treePaint2,
    );
    canvas.drawCircle(
      Offset(left + buildingWidth - 15, bottom - 12),
      18,
      treePaint1,
    );
    canvas.drawCircle(
      Offset(left + buildingWidth + 10, bottom - 8),
      10,
      treePaint3,
    );

    canvas.drawCircle(Offset(centerLeft - 6, bottom - 8), 8, treePaint1);
    canvas.drawCircle(
      Offset(centerLeft + centerWidth + 6, bottom - 8),
      8,
      treePaint1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OfficialSealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 1, borderPaint);

    borderPaint.color = const Color(0xFFF59E0B);
    borderPaint.strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 4, borderPaint);

    final shieldPath = Path()
      ..moveTo(center.dx, center.dy - radius * 0.5)
      ..quadraticBezierTo(
        center.dx - radius * 0.4,
        center.dy - radius * 0.4,
        center.dx - radius * 0.4,
        center.dy + radius * 0.1,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.2,
        center.dy + radius * 0.55,
        center.dx,
        center.dy + radius * 0.65,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.2,
        center.dy + radius * 0.55,
        center.dx + radius * 0.4,
        center.dy + radius * 0.1,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.4,
        center.dy - radius * 0.4,
        center.dx,
        center.dy - radius * 0.5,
      )
      ..close();

    fillPaint.color = const Color(0xFF1D4ED8);
    canvas.drawPath(shieldPath, fillPaint);

    canvas.save();
    canvas.clipPath(shieldPath);
    final redRect = Rect.fromLTWH(
      center.dx,
      center.dy - radius,
      radius,
      radius * 2,
    );
    fillPaint.color = const Color(0xFFEF4444);
    canvas.drawRect(redRect, fillPaint);
    canvas.restore();

    borderPaint.color = const Color(0xFFF59E0B);
    borderPaint.strokeWidth = 1.5;
    canvas.drawPath(shieldPath, borderPaint);

    final sunPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.18, sunPaint);

    canvas.drawCircle(
      Offset(center.dx, center.dy - radius * 0.32),
      2,
      sunPaint,
    );
    canvas.drawCircle(
      Offset(center.dx - radius * 0.22, center.dy + radius * 0.25),
      2,
      sunPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.22, center.dy + radius * 0.25),
      2,
      sunPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
