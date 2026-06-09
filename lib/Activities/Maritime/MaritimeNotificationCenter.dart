import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/Maritime/MaritimeActivityLogger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import '../../Dialogs/Bottomsheets/AddEditMarineNotification.dart';

import '../../Utility/SearchBarView.dart';

class MaritimeNotificationCenter extends StatefulWidget {
  const MaritimeNotificationCenter({super.key});

  @override
  State<MaritimeNotificationCenter> createState() => _MaritimeNotificationCenterState();
}

class _MaritimeNotificationCenterState extends State<MaritimeNotificationCenter> {
  // Theme Colors
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color broadcastPurple = const Color(0xFF8B5CF6);

  final _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _sentAlerts = [];

  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();

  SharedPreferences? _preferences;

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  final int _limit = 15;
  int _offset = 0;

  // --- SEARCH VARIABLES ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initLogic();
    _fetchAlerts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        _fetchAlerts(isLoadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initLogic() async {
    _preferences = await SharedPreferences.getInstance();
  }

  // --- SEARCH LOGIC ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Wait 500ms after the user stops typing to fetch data
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
        });
        // Trigger a fresh fetch with the new search term
        _fetchAlerts();
      }
    });
  }

  Future<void> _fetchAlerts({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (_isFetchingMore || !_hasMore) return;
      setState(() => _isFetchingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
        _sentAlerts.clear();
      });
    }

    try {
      var query = _supabase
          .from('global_notification')
          .select()
          .eq('notification_source', 'maritime');

      // 2. Apply search filters if needed
      if (_searchQuery.isNotEmpty) {
        query = query.or('notification_title.ilike.%$_searchQuery%,notification_message.ilike.%$_searchQuery%');
      }

      // 3. Apply Modifiers (order and range) LAST and execute
      final data = await query
          .order('notification_date', ascending: false)
          .range(_offset, _offset + _limit - 1);

      final List<Map<String, dynamic>> fetchedAlerts = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          if (fetchedAlerts.length < _limit) {
            _hasMore = false;
          }
          _sentAlerts.addAll(fetchedAlerts);
          _offset += fetchedAlerts.length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      if (mounted && !isLoadMore) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to load alerts.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<void> _deleteAlert(String notificationId, String notificationTitle) async {
    try {
      String userName = _preferences?.getString("user_name") ?? "Administrator";
      String assignedPort = _preferences?.getString("assigned_port") ?? "Unknown Port";
      String userId = _preferences?.getString("user_id") ?? "unknown_user_id";

      _loadingDialog.showLoadingDialog(context);

      await _supabase
          .from('global_notification')
          .delete()
          .eq('notification_id', notificationId);

      String message = "[$assignedPort] - $userName deleted a notification. [$notificationTitle]";
      await MaritimeActivityLogger.createLog(
          title: "Deleted Notification",
          message: message,
          creatorId: userId);

      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Alert deleted successfully.");
        _fetchAlerts();
      }
    } catch (e) {
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to delete alert.");
      }
    }
  }

  void _confirmDeleteDialog(String notificationId, String notificationTitle) {

    _classicDialog.setTitle("Delete Alert?");
    _classicDialog.setMessage("This alert will be permanently removed from the global broadcast. Continue?");
    _classicDialog.setPositiveMessage("Delete");
    _classicDialog.setNegativeMessage("Cancel");
    _classicDialog.setCancelable(true);
    _classicDialog.showTwoButtonDialog(context, (negative){
      _classicDialog.dismissDialog();
      Navigator.pop(context);
    }, (positive){
      _classicDialog.dismissDialog();
      _deleteAlert(notificationId, notificationTitle);
    });
  }

  // --- HELPER: SHEET ITEM BUILDER ---
  Widget _buildSheetItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- OPTIONS BOTTOM SHEET ---
  void _showOptionsBottomSheet(Map<String, dynamic> alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                alert['notification_title'] ?? "Alert Options",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),

            _buildSheetItem(Icons.edit_rounded, "Edit Alert Details", broadcastPurple, () {
              Navigator.pop(context); // Close BottomSheet

              String userName = _preferences?.getString("user_name") ?? "Administrator";
              String assignedPort = _preferences?.getString("assigned_port") ?? "Unknown Port";
              String userId = _preferences?.getString("user_id") ?? "unknown_user_id";

              AddEditMarineNotification().showBottomSheet(
                  context,
                  alert,
                  userName,
                  userId,
                  assignedPort,
                      () => _fetchAlerts()
              );
            }),

            _buildSheetItem(Icons.delete_forever_rounded, "Delete Alert", Colors.redAccent, () {
              Navigator.pop(context);
              _confirmDeleteDialog(alert['notification_id'].toString(), alert["notification_title"].toString());
            }),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic epochValue) {
    if (epochValue == null) return "Unknown Date";
    int epoch = int.tryParse(epochValue.toString()) ?? 0;
    if (epoch == 0) return "Unknown Date";

    final date = DateTime.fromMillisecondsSinceEpoch(epoch);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Alerts"),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryDark, letterSpacing: -0.5),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              tooltip: "Create New Alert",
              icon: Icon(Icons.add_circle_outline_rounded, color: broadcastPurple, size: 28),
              onPressed: () {
                String userName = _preferences?.getString("user_name") ?? "Administrator";
                String assignedPort = _preferences?.getString("assigned_port") ?? "Unknown Port";
                String userId = _preferences?.getString("user_id") ?? "unknown_user_id";

                AddEditMarineNotification().showBottomSheet(
                    context,
                    null,
                    userName,
                    userId,
                    assignedPort,
                        () => _fetchAlerts()
                );
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --- REUSABLE SEARCH BAR WIDGET ---
              SearchBarView(
                controller: _searchController,
                onChanged: _onSearchChanged,
                searchQuery: _searchQuery,
                hintText: "Search alerts...",
                focusedColor: broadcastPurple,
                textSecondary: textSecondary,
                outlineColor: outlineColor,
              ),

              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: broadcastPurple))
                    : _sentAlerts.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                          _searchQuery.isNotEmpty ? "No results found." : "No alerts broadcasted yet.",
                          style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)
                      ),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  color: broadcastPurple,
                  onRefresh: () => _fetchAlerts(),
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.only(bottom: 24, top: 8),
                    itemCount: _sentAlerts.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (context, index) => Divider(height: 1, color: outlineColor.withValues(alpha: 0.5)),
                    itemBuilder: (context, index) {
                      if (index == _sentAlerts.length) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator(color: broadcastPurple)),
                        );
                      }
                      return _buildHistoryTile(_sentAlerts[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> alert) {
    String source = alert['notification_source'] ?? 'maritime';
    String title = alert['notification_title'] ?? 'No Title';
    String message = alert['notification_message'] ?? 'No Message';
    String displayDate = _formatDate(alert['notification_date']);

    Color iconColor;
    Color iconBg;
    IconData iconData;

    switch (source) {
      case 'emergency':
        iconColor = const Color(0xFFDC2626);
        iconBg = const Color(0xFFFEF2F2);
        iconData = Icons.warning_rounded;
        break;
      case 'warning':
        iconColor = const Color(0xFFD97706);
        iconBg = const Color(0xFFFFFBEB);
        iconData = Icons.storm_rounded;
        break;
      case 'success':
        iconColor = const Color(0xFF10B981);
        iconBg = const Color(0xFFECFDF5);
        iconData = Icons.check_circle_rounded;
        break;
      case 'maritime':
        iconColor = const Color(0xFF8B5CF6);
        iconBg = const Color(0xFFF3E8FF);
        iconData = Icons.directions_boat_filled_rounded;
        break;
      default:
        iconColor = const Color(0xFF3B82F6);
        iconBg = const Color(0xFFEFF6FF);
        iconData = Icons.info_rounded;
    }

    return Material(
      color: Colors.transparent, // Changed to transparent to fit the list background smoothly
      child: InkWell(
        onTap: () {
          _showOptionsBottomSheet(alert);
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textPrimary, height: 1.2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayDate,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(Icons.more_vert_rounded, color: outlineColor, size: 20),
              )
            ],
          ),
        ),
      ),
    );
  }
}
