import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/FAQ.dart';
import 'package:gasan_port_tracker/Dialogs/Bottomsheets/ChangeBorderPreferences.dart';
import 'package:gasan_port_tracker/Dialogs/Bottomsheets/NotificationPreferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Activities/LoginSignup.dart';
import 'package:gasan_port_tracker/Activities/About.dart';
import 'package:gasan_port_tracker/Activities/support_tickets.dart';
import 'package:gasan_port_tracker/Authentication/SupabaseAuthentication.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gasan_port_tracker/Utility/Municipalities.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';
import 'package:gasan_port_tracker/Activities/Seller/SellerProfile.dart';
import 'package:gasan_port_tracker/Activities/UserDeliveryAddressList.dart';
import 'package:gasan_port_tracker/Activities/UserOrders.dart';
import 'package:gasan_port_tracker/Activities/VerifyAccount.dart';
import 'package:gasan_port_tracker/Activities/Maritime/MaritimeAdministrator.dart';
import 'package:gasan_port_tracker/Activities/Tourism/TourismAdministrator.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/MDRRMOAdministrator.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/MDRRMOPersonnelPanel.dart';
import 'package:gasan_port_tracker/Activities/MarketPlaceAdministrators.dart';
import 'package:gasan_port_tracker/Activities/GodMode/GodMode.dart';

class MyAccount extends StatefulWidget {
  const MyAccount({super.key});

  @override
  State<MyAccount> createState() => _MyAccountState();
}

class _MyAccountState extends State<MyAccount> {
  final supabase = Supabase.instance.client;
  final _loadingDialog = LoadingDialog();
  final _classicDialog = ClassicDialog();
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color accentColor = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  bool _isLoading = true;
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  String _userType = "CITIZEN";
  String? _avatarUrl;
  String _accountStatus = "un_verified";
  List<dynamic> _userRoles = [];
  bool _orderCountsLoading = true;
  int _placedOrderCount = 0;
  int _preparingOrderCount = 0;
  int _deliveryPickupOrderCount = 0;
  bool get _canUseGodMode =>
      GodMode.isOwner(supabase.auth.currentUser, account: _userEmail);

  bool _hasRole(String role) => _userRoles.any(
    (userRole) => userRole.toString().trim().toLowerCase() == role,
  );

  String _selectedTown = "All Towns";
  String _selectedBorder = "Auto-Detect";
  String _borderSubtitle = "Auto-Detect";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchOrderCounts();
    _loadCurrentPreference();
  }

  Future<void> _fetchOrderCounts() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _orderCountsLoading = false);
      return;
    }

    try {
      final rows = await supabase
          .from('orders')
          .select('order_id, order_group_id, order_status')
          .eq('order_user_id', userId)
          .inFilter('order_status', const [
            'placed',
            'preparing',
            'ready for pickup',
            'out for delivery',
          ]);

      final groupedStatuses = <String, String>{};
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final groupId = row['order_group_id']?.toString().trim();
        final orderId = row['order_id']?.toString() ?? '';
        final key = groupId != null && groupId.isNotEmpty
            ? groupId
            : orderId.replaceFirst(RegExp(r'_\d+$'), '');
        if (key.isNotEmpty) {
          groupedStatuses[key] = row['order_status']?.toString() ?? '';
        }
      }

      if (!mounted) return;
      setState(() {
        _placedOrderCount = groupedStatuses.values
            .where((status) => status == 'placed')
            .length;
        _preparingOrderCount = groupedStatuses.values
            .where((status) => status == 'preparing')
            .length;
        _deliveryPickupOrderCount = groupedStatuses.values
            .where(
              (status) =>
                  status == 'ready for pickup' || status == 'out for delivery',
            )
            .length;
        _orderCountsLoading = false;
      });
    } catch (error) {
      debugPrint('Error fetching account order counts: $error');
      if (mounted) setState(() => _orderCountsLoading = false);
    }
  }

  Future<void> _loadCurrentPreference() async {
    final prefs = await SharedPreferences.getInstance();

    String savedZip =
        prefs.getString('preferred_notification_municipality_zipcode') ??
        '0000';
    int savedBorderZip = prefs.getInt("current_zip_code") ?? 0;

    if (mounted) {
      setState(() {
        if (savedZip == '0000') {
          _selectedTown = "All Towns";
        } else {
          try {
            final match = Municipalities.list.firstWhere(
              (m) => m['zip'] == savedZip,
              orElse: () => {"name": "All Towns"},
            );
            _selectedTown = match['name']!;
          } catch (e) {
            _selectedTown = "All Towns";
          }
        }

        if (prefs.getBool("isBorderChangeAuto") == true) {
          _selectedBorder = "Auto-Detect";
          final autoMuni = prefs.getString('current_municipality') ?? '';
          final autoZip = prefs.getInt('current_zip_code') ?? 0;
          if (autoMuni.isNotEmpty && autoZip != 0) {
            _borderSubtitle = "Auto-Detect · $autoMuni ($autoZip)";
          } else {
            _borderSubtitle = "Auto-Detect";
          }
        } else {
          try {
            final match = Municipalities.list.firstWhere(
              (m) => int.parse(m['zip'].toString()) == savedBorderZip,
              orElse: () => {"name": "Auto-Detect"},
            );
            _selectedBorder = match['name']!;
            _borderSubtitle = _selectedBorder;
          } catch (e) {
            _selectedBorder = "Auto-Detect";
            _borderSubtitle = "Auto-Detect";
          }
        }
      });
    }
  }

  Future<void> _fetchUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userData = await supabase
          .from('user_data')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (userData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final dynamic accessColumn = userData["user_access"];
      List<dynamic> roles = [];

      if (accessColumn != null) {
        if (accessColumn is List) {
          roles = accessColumn;
        } else if (accessColumn is Map && accessColumn['access'] is List) {
          roles = accessColumn['access'];
        }
      }

      String displayRole = "CITIZEN";
      if (roles.isNotEmpty) {
        displayRole = roles.map((r) => r.toString().toUpperCase()).join(" • ");
      }

      if (mounted) {
        setState(() {
          _userName = userData['user_name'] ?? "Citizen";
          _userEmail = userData['user_account'] ?? user.email ?? "";
          _userType = displayRole;
          _userRoles = roles;
          _avatarUrl = userData['avatar_url'];
          _accountStatus = (userData['account_status'] ?? 'un_verified')
              .toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openLink(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Could not open browser. Please try again."),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _handleLogout() async {
    try {
      _classicDialog.setTitle("Logout?");
      _classicDialog.setMessage("Are you sure you want to logout?");
      _classicDialog.setCancelable(false);
      _classicDialog.setPositiveMessage("Logout");
      _classicDialog.setNegativeMessage("Cancel");
      _classicDialog.showTwoButtonDialog(
        context,
        (negative) {
          _classicDialog.dismissDialog();
        },
        (positive) async {
          _classicDialog.dismissDialog();
          _loadingDialog.showLoadingDialog(context);
          await SupabaseAuthentication().signOut();
          _loadingDialog.dismiss();
          if (mounted)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginSignup()),
            );
        },
      );
    } catch (error) {
      _loadingDialog.dismiss();
      _classicDialog.setTitle("An error occurred!");
      _classicDialog.setMessage(error.toString());
      _classicDialog.setCancelable(false);
      _classicDialog.setPositiveMessage("Close");
      if (mounted) {
        _classicDialog.showOnButtonDialog(context, () {
          _classicDialog.dismissDialog();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "My Account",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Utility().getMaxScreenSize(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 16),
                        _buildOrderSummary(),
                        const SizedBox(height: 24),

                        if (_canUseGodMode) ...[
                          _buildSectionHeader("OWNER ACCESS"),
                          _buildSettingsGroup([
                            _buildSettingsTile(
                              icon: Icons.admin_panel_settings_rounded,
                              label: "God Mode",
                              subtitle:
                                  "Access all system administration tools",
                              subtitleColor: const Color(0xFFF59E0B),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GodMode(),
                                  ),
                                );
                              },
                            ),
                          ]),
                          const SizedBox(height: 24),
                        ],

                        _buildSectionHeader("ACCOUNT SETTINGS"),
                        _buildSettingsGroup([
                          _buildSettingsTile(
                            icon: Icons.person_outline_rounded,
                            label: "Manage Google Account",
                            onTap: () =>
                                _openLink('https://myaccount.google.com/'),
                          ),

                          _buildDivider(),

                          // --- NEW ONLINE SHOP FEATURE ---
                          _buildSettingsTile(
                            icon: Icons.storefront_rounded,
                            label: "Online Shop",
                            subtitle: "Free online store for local businesses",
                            subtitleColor: const Color(
                              0xFF10B981,
                            ), // Green color for "Free"
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SellerProfile(),
                                ),
                              );
                            },
                          ),

                          _buildDivider(),

                          _buildSettingsTile(
                            icon: Icons.local_shipping_outlined,
                            label: "Delivery Address",
                            subtitle: "Saved address for your orders",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const UserDeliveryAddressList(),
                                ),
                              );
                            },
                          ),

                          _buildDivider(),

                          _buildSettingsTile(
                            icon: Icons.notifications_none_rounded,
                            label: "Notification Preferences",
                            subtitle: _selectedTown,
                            onTap: () {
                              NotificationPreferences.show(context, () {
                                _loadCurrentPreference();
                              });
                            },
                          ),

                          _buildDivider(),

                          _buildSettingsTile(
                            icon: Icons.map,
                            label: "Change Border",
                            subtitle: _borderSubtitle,
                            onTap: () {
                              ChangeBorderPreferences.show(context, () {
                                _loadCurrentPreference();
                              });
                            },
                          ),
                        ]),

                        if (_userRoles.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildSectionHeader("ADMINISTRATIVE TOOLS"),
                          _buildSettingsGroup([
                            if (SupabaseUtility.maritimeEnabled &&
                                _userRoles.contains("maritime")) ...[
                              _buildSettingsTile(
                                icon: Icons.directions_boat_rounded,
                                label: "Maritime Management",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MaritimeAdministrator(),
                                    ),
                                  );
                                },
                              ),
                              if (_userRoles.contains("tourism") ||
                                  _userRoles.contains("mdrrmo"))
                                _buildDivider(),
                            ],

                            if (_userRoles.contains("tourism")) ...[
                              _buildSettingsTile(
                                icon: Icons.travel_explore_rounded,
                                label: "Tourism Management",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TourismAdministrator(),
                                    ),
                                  );
                                },
                              ),
                              if (_userRoles.contains("mdrrmo"))
                                _buildDivider(),
                            ],

                            if (_userRoles.contains("mdrrmo")) ...[
                              _buildSettingsTile(
                                icon: Icons.emergency_rounded,
                                label: "MDRRMO Dashboard",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MdrrmoAdministrator(),
                                    ),
                                  );
                                },
                              ),
                              if (_userRoles.contains("mdrrmo_personnel"))
                                _buildDivider(),
                            ],

                            if (_userRoles.contains("mdrrmo_personnel")) ...[
                              _buildSettingsTile(
                                icon: Icons.health_and_safety_rounded,
                                label: "MDRRMO Personnel",
                                subtitle: "Open the personnel response panel",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MdrrmoPersonnelPanel(),
                                    ),
                                  );
                                },
                              ),
                            ],

                            if (_hasRole("marketplace_admin")) ...[
                              if (_userRoles.any(
                                (role) => [
                                  "maritime",
                                  "tourism",
                                  "mdrrmo",
                                  "mdrrmo_personnel",
                                ].contains(role.toString()),
                              ))
                                _buildDivider(),
                              _buildSettingsTile(
                                icon: Icons.storefront_rounded,
                                label: "Marketplace Management",
                                subtitle: "Review and manage local shops",
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MarketPlaceAdministrators(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ]),
                        ],

                        const SizedBox(height: 24),

                        _buildSectionHeader("SUPPORT & ABOUT"),

                        _buildSettingsGroup([
                          _buildSettingsTile(
                            icon: Icons.help_outline_rounded,
                            label: "Help Center & FAQ",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FAQ()),
                              );
                            },
                          ),

                          _buildDivider(),

                          _buildSettingsTile(
                            icon: Icons.bug_report_outlined,
                            label: "Report Bugs & Errors",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SupportTickets(),
                                ),
                              );
                            },
                          ),

                          _buildDivider(),

                          _buildSettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            label: "Terms and Privacy Policy",
                            onTap: () => _openLink(
                              'https://sites.google.com/view/terms-conditions-aga-app/home',
                            ),
                          ),

                          _buildDivider(),

                          _buildSettingsTile(
                            icon: Icons.info_outline_rounded,
                            label: "About AGA Gasan App",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const About(),
                                ),
                              );
                            },
                          ),
                        ]),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.redAccent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text(
                              "Log Out",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildOrderSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: outlineColor),
      ),
      child: Row(
        children: [
          _buildOrderSummaryItem(
            icon: Icons.receipt_long_rounded,
            label: 'Placed Order',
            count: _placedOrderCount,
            filter: 'placed',
            color: const Color(0xFF2563EB),
          ),
          _buildOrderSummaryItem(
            icon: Icons.inventory_2_outlined,
            label: 'Preparing',
            count: _preparingOrderCount,
            filter: 'preparing',
            color: const Color(0xFFF59E0B),
          ),
          _buildOrderSummaryItem(
            icon: Icons.local_shipping_outlined,
            label: 'Delivery/Pickup',
            count: _deliveryPickupOrderCount,
            filter: 'delivery_pickup',
            color: const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryItem({
    required IconData icon,
    required String label,
    required int count,
    required String filter,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserOrders(initialFilter: filter),
            ),
          );
          _fetchOrderCounts();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 21),
                  ),
                  if (!_orderCountsLoading && count > 0)
                    Positioned(
                      right: -7,
                      top: -7,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.white,
              backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: _avatarUrl == null || _avatarUrl!.isEmpty
                  ? Icon(
                      Icons.person_rounded,
                      size: 46,
                      color: primaryColor.withValues(alpha: 0.5),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Verified badge hidden alongside the verification pill.
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _userEmail,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _userType,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              // Account verification hidden for now.
              // _buildVerificationPill(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationPill() {
    final bool verified = _accountStatus == 'verified';
    final Color base = verified
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VerifyAccount()),
          );
          _fetchUserData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: base.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.gpp_maybe_rounded,
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: 5),
              Text(
                verified ? "VERIFIED" : "UNVERIFIED",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              if (!verified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String label,
    String? subtitle,
    Color? subtitleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor ?? accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: textSecondary.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 60, right: 16),
      child: Divider(height: 1, color: outlineColor, thickness: 0.5),
    );
  }
}
