import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/Maritime/ShippingLinesManagement.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Maritime/MaritimeActivityLogger.dart';
import 'MaritimeNotificationCenter.dart';
import 'PortsManagement.dart';
import 'VesselStatusUpdater.dart';

class MaritimeAdministrator extends StatefulWidget {
  const MaritimeAdministrator({super.key});

  @override
  State<MaritimeAdministrator> createState() => _MaritimeAdministratorState();
}

class _MaritimeAdministratorState extends State<MaritimeAdministrator> {
  // Theme Colors
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color outlineColor = const Color(0xFFE2E8F0);

  List<Map<String, dynamic>> _recentLogs = [];
  bool _isLoadingLogs = true;
  String? _assignedPort;
  String? _adminName;
  String? _avatarURL;

  int _portsCount = 0;
  int _shippingLinesCount = 0;
  int _notificationsCount = 0;
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _fetchRecentLogs();
    _fetchCounts();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _assignedPort = prefs.getString("assigned_port");
        _adminName = prefs.getString("user_name");
        _avatarURL = prefs.getString("avatar_url"); // <-- Added to load the URL
      });
    }
  }

  Future<void> _fetchCounts() async {
    if (mounted) setState(() => _isLoadingCounts = true);

    try {
      final supabase = Supabase.instance.client;

      final responses = await Future.wait([
        supabase.from('ports').select('port_id'),
        supabase.from('shipping_lines').select('shipping_line_id'),
        supabase
            .from('global_notification')
            .select('notification_id')
            .eq("notification_source", "maritime"),
      ]);

      if (mounted) {
        setState(() {
          _portsCount = (responses[0] as List).length;
          _shippingLinesCount = (responses[1] as List).length;
          _notificationsCount = (responses[2] as List).length;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard counts: $e");
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  Future<void> _fetchRecentLogs() async {
    if (mounted) setState(() => _isLoadingLogs = true);
    final logs = await MaritimeActivityLogger.fetchLogs(limit: 5);
    if (mounted) {
      setState(() {
        _recentLogs = logs;
        _isLoadingLogs = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _fetchRecentLogs(),
      _fetchCounts(),
    ]);
  }

  String _getTimeAgo(int epochMillis) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return "Just now";
    if (difference.inMinutes < 60) return "${difference.inMinutes} min${difference.inMinutes == 1 ? '' : 's'} ago";
    if (difference.inHours < 24) return "${difference.inHours} hr${difference.inHours == 1 ? '' : 's'} ago";
    if (difference.inDays < 30) return "${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago";
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return "$months month${months == 1 ? '' : 's'} ago";
    }
    final years = (difference.inDays / 365).floor();
    return "$years year${years == 1 ? '' : 's'} ago";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "MARITIME PANEL",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: outlineColor, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryDark,
          backgroundColor: Colors.white,
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Beautiful Admin Profile Header ---
                      _buildAdminInfoCard(),

                      const SizedBox(height: 32),

                      _buildSectionHeader(Icons.dashboard_customize_rounded, "MANAGEMENT MODULES"),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildGridCard(
                              title: "Ports",
                              subtitle: "Add or edit ports",
                              icon: Icons.location_city_rounded,
                              color: const Color(0xFF0D9488),
                              count: _portsCount,
                              isLoading: _isLoadingCounts,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const PortsManagement()))
                                    .then((_) => _fetchCounts());
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildGridCard(
                              title: "Shipping Lines",
                              subtitle: "Manage fleets",
                              icon: Icons.directions_boat_filled_rounded,
                              color: const Color(0xFF2563EB),
                              count: _shippingLinesCount,
                              isLoading: _isLoadingCounts,
                              onTap: () {
                                if(_portsCount <= 0){
                                  SnackbarMessenger().showSnackbar(context, SnackbarMessenger.neutral, "Add at least 2 ports");
                                  return;
                                }
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ShippingLinesManagement()))
                                    .then((_) => _fetchCounts());
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridCard(
                              title: "Update Status",
                              subtitle: "Update vessel status",
                              icon: Icons.update_sharp,
                              color: const Color(0xFFD97706),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const VesselStatusUpdater()));
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildGridCard(
                              title: "Send Notification",
                              subtitle: "Public notifications",
                              icon: Icons.campaign_rounded,
                              color: const Color(0xFF8B5CF6),
                              count: _notificationsCount,
                              isLoading: _isLoadingCounts,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const MaritimeNotificationCenter()))
                                    .then((_) => _fetchCounts());
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(Icons.history_rounded, "RECENT ACTIVITY"),
                          if (!_isLoadingLogs && _recentLogs.isNotEmpty)
                            InkWell(
                              onTap: _fetchRecentLogs,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh_rounded, size: 14, color: primaryDark),
                                    const SizedBox(width: 4),
                                    Text("Refresh", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: primaryDark)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildLogsSection(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Beautiful Admin Profile Header (Matched to MDRRMO style) ---
  Widget _buildAdminInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Matches MDRRMO lockedBgColor
              shape: BoxShape.circle,
              border: Border.all(color: outlineColor),
              // --- NEW: Load the image if the URL exists ---
              image: _avatarURL != null && _avatarURL!.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(_avatarURL!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            // --- NEW: Show the default icon only if there is no URL ---
            child: _avatarURL == null || _avatarURL!.isEmpty
                ? Icon(Icons.person_rounded, size: 30, color: textSecondary.withValues(alpha: 0.5))
                : null,
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Administrator Title
                Text(
                  "ADMINISTRATOR",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: primaryDark,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),

                // Name
                Text(
                  _adminName ?? "Port Administrator",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Account/Email
                Text(
                  "Maritime Authority Access",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryDark.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryDark.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_boat_filled_rounded, size: 12, color: primaryDark),
                      const SizedBox(width: 4),
                      Text(
                        "MARITIME • ${_assignedPort ?? 'Unassigned'}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textSecondary.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: textSecondary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? count,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Matched border radius to MDRRMO modules
        border: Border.all(color: outlineColor), // Added matching border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),

                    if (isLoading && count != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8, right: 4),
                        child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)
                        ),
                      )
                    else if (count != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textPrimary, // Switched to textPrimary for a cleaner look
                              letterSpacing: -0.5
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.2, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogsSection() {
    if (_isLoadingLogs) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: primaryDark),
      );
    }

    if (_recentLogs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: outlineColor),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded, size: 32, color: textSecondary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text("No recent activity", style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary, fontSize: 15)),
            const SizedBox(height: 4),
            Text("Updates to the system will appear here.", style: TextStyle(fontSize: 12, color: textSecondary)),
          ],
        ),
      );
    }

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
          )
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _recentLogs.length,
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(left: 60, right: 20),
          child: Divider(height: 1, color: outlineColor, thickness: 1),
        ),
        itemBuilder: (context, index) {
          final log = _recentLogs[index];

          final rawDate = log['log_added_date'];
          String displayTime = "Just now";

          try {
            if (rawDate != null) {
              int epochMillis = rawDate is int ? rawDate : int.tryParse(rawDate.toString()) ?? 0;
              if (epochMillis > 0) {
                displayTime = _getTimeAgo(epochMillis);
              }
            }
          } catch(e) {
            // Fallback to "Just now"
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryDark.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.info_outline_rounded, size: 16, color: primaryDark),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              log['log_title'] ?? "System Update",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
                            ),
                          ),
                          Text(
                            displayTime,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log['log_message'] ?? "A modification was made to the system.",
                        style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
