import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import '../Dialogs/ViewNotificationDialog.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter({super.key});

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);

  final _supabase = Supabase.instance.client;

  bool _isLoadingGlobal = true;
  List<Map<String, dynamic>> _globalNotifications = [];

  bool _isLoadingLimited = true;
  List<Map<String, dynamic>> _limitedNotifications = [];
  List<String> _readNotificationIds = [];
  List<String> _deletedNotificationIds = [];
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _prefs = await SharedPreferences.getInstance();

    _readNotificationIds = _prefs?.getStringList('read_notifications') ?? [];
    _deletedNotificationIds =
        _prefs?.getStringList('deleted_notifications') ?? [];

    _fetchGlobalNotifications();
    _fetchLimitedNotifications();
  }

  Future<void> _fetchGlobalNotifications() async {
    setState(() => _isLoadingGlobal = true);

    try {
      final data = await _supabase
          .from('global_notification')
          .select()
          .order('notification_date', ascending: false);

      final List<Map<String, dynamic>> fetchedData =
          List<Map<String, dynamic>>.from(data);

      String currentUserZipCode =
          _prefs?.getString("preferred_notification_municipality_zipcode") ??
          "0000";

      final List<Map<String, dynamic>> visibleNotifications = fetchedData.where(
        (note) {
          if (_deletedNotificationIds.contains(
            note['notification_id'].toString(),
          )) {
            return false;
          }

          String notificationSource =
              note["notification_source"]?.toString() ?? "";
          String notificationOriginZipCode =
              note["notification_origin_zipcode"]?.toString() ?? "0000";

          if (notificationSource == "mdrrmo") {
            if (currentUserZipCode != "0000") {
              if (currentUserZipCode == notificationOriginZipCode) {
                return true;
              } else {
                return false;
              }
            } else {
              return true;
            }
          } else {
            return true;
          }
        },
      ).toList();

      if (mounted) {
        setState(() {
          _globalNotifications = visibleNotifications;
          _isLoadingGlobal = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching global notifications: $e");
      if (mounted) {
        setState(() => _isLoadingGlobal = false);
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.failed,
          "Failed to load global alerts.",
        );
      }
    }
  }

  Future<void> _fetchLimitedNotifications() async {
    setState(() => _isLoadingLimited = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoadingLimited = false);
        return;
      }

      final response = await _supabase
          .from('user_data')
          .select('limited_notifications')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['limited_notifications'] != null) {
        final rawData = response['limited_notifications'];
        List<Map<String, dynamic>> parsedList = [];

        if (rawData is List) {
          parsedList = List<Map<String, dynamic>>.from(rawData);
        } else if (rawData is Map) {
          parsedList.add(Map<String, dynamic>.from(rawData));
        }

        if (mounted) {
          setState(() {
            _limitedNotifications = parsedList;
            _isLoadingLimited = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _limitedNotifications = [];
            _isLoadingLimited = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching limited notifications: $e");
      if (mounted) {
        setState(() => _isLoadingLimited = false);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var note in _globalNotifications) {
        String id = note['notification_id'].toString();
        if (!_readNotificationIds.contains(id)) {
          _readNotificationIds.add(id);
        }
      }
      for (var note in _limitedNotifications) {
        String id = note['id'].toString();
        if (!_readNotificationIds.contains(id)) {
          _readNotificationIds.add(id);
        }
      }
    });
    await _prefs?.setStringList('read_notifications', _readNotificationIds);
  }

  Future<void> _markAsRead(String id) async {
    if (!_readNotificationIds.contains(id)) {
      setState(() {
        _readNotificationIds.add(id);
      });
      await _prefs?.setStringList('read_notifications', _readNotificationIds);
    }
  }

  Future<void> _deleteGlobalNotification(int index) async {
    String id = _globalNotifications[index]['notification_id'].toString();
    setState(() {
      _deletedNotificationIds.add(id);
      _globalNotifications.removeAt(index);
    });
    await _prefs?.setStringList(
      'deleted_notifications',
      _deletedNotificationIds,
    );
  }

  // --- DB ACTIONS (LIMITED) ---
  Future<void> _deleteLimitedNotification(int index) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _limitedNotifications.removeAt(index);
    });

    try {
      await _supabase
          .from('user_data')
          .update({'limited_notifications': _limitedNotifications})
          .eq('user_id', userId);
    } catch (e) {
      debugPrint("Failed to delete limited notification from DB: $e");
    }
  }

  // --- HELPER: DATE FORMATTER ---
  String _formatDate(dynamic epochValue) {
    if (epochValue == null) return "Unknown";
    int epoch = int.tryParse(epochValue.toString()) ?? 0;
    if (epoch == 0) return "Unknown";

    final date = DateTime.fromMillisecondsSinceEpoch(epoch);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${date.month}/${date.day}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    bool hasUnreadGlobal = _globalNotifications.any(
      (n) => !_readNotificationIds.contains(n['notification_id'].toString()),
    );
    bool hasUnreadLimited = _limitedNotifications.any(
      (n) => !_readNotificationIds.contains(n['id'].toString()),
    );
    bool hasAnyUnread = hasUnreadGlobal || hasUnreadLimited;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text("Notifications"),
          backgroundColor: Colors.white,
          foregroundColor: primaryDark,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: primaryDark,
            letterSpacing: -0.5,
          ),
          actions: [
            if (hasAnyUnread)
              TextButton(
                onPressed: _markAllAsRead,
                style: TextButton.styleFrom(foregroundColor: accentBlue),
                child: const Text(
                  "Mark all read",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
          ],
          bottom: TabBar(
            indicatorColor: accentBlue,
            labelColor: accentBlue,
            unselectedLabelColor: textSecondary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: "Global Alerts"),
              Tab(text: "Personal"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Global Notifications
            _buildGlobalTab(),
            // TAB 2: Limited Notifications
            _buildLimitedTab(),
          ],
        ),
      ),
    );
  }

  // --- TAB 1 BUILDER ---
  Widget _buildGlobalTab() {
    if (_isLoadingGlobal)
      return Center(child: CircularProgressIndicator(color: accentBlue));
    if (_globalNotifications.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: accentBlue,
      onRefresh: _fetchGlobalNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _globalNotifications.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: outlineColor.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          final note = _globalNotifications[index];
          String id = note['notification_id'].toString();

          return Dismissible(
            key: Key('global_$id'),
            direction: DismissDirection.endToStart,
            background: _buildDismissBackground(),
            onDismissed: (direction) {
              _deleteGlobalNotification(index);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Alert dismissed'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: _buildNotificationTile(
              id: id,
              title: note['notification_title'] ?? 'Alert',
              message: note['notification_message'] ?? 'No details provided.',
              type: note['notification_source'] ?? 'system',
              dateEpoch: note['notification_date'],
              onTap: () {
                _markAsRead(id);
                ViewNotificationDialog.show(context, note);
              },
            ),
          );
        },
      ),
    );
  }

  // --- TAB 2 BUILDER ---
  Widget _buildLimitedTab() {
    if (_isLoadingLimited)
      return Center(child: CircularProgressIndicator(color: accentBlue));
    if (_limitedNotifications.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: accentBlue,
      onRefresh: _fetchLimitedNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _limitedNotifications.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: outlineColor.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          final note = _limitedNotifications[index];
          String id = note['id']?.toString() ?? index.toString();

          return Dismissible(
            key: Key('limited_$id'),
            direction: DismissDirection.endToStart,
            background: _buildDismissBackground(),
            onDismissed: (direction) {
              _deleteLimitedNotification(index);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notice deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: _buildNotificationTile(
              id: id,
              title: note['title'] ?? 'Personal Notice',
              message: note['message'] ?? 'No details provided.',
              type: 'personal', // Force a specific theme for personal notes
              dateEpoch: note['date_sent'],
              onTap: () {
                _markAsRead(id);
                // Map the limited keys to match what ViewNotificationDialog expects
                Map<String, dynamic> mappedNote = {
                  'notification_title': note['title'],
                  'notification_message': note['message'],
                  'notification_date': note['date_sent'],
                  'notification_source':
                      'system', // To give it a default icon in the dialog
                };
                ViewNotificationDialog.show(context, mappedNote);
              },
            ),
          );
        },
      ),
    );
  }

  // --- SHARED UI COMPONENTS ---

  Widget _buildDismissBackground() {
    return Container(
      color: const Color(0xFFEF4444),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(
        Icons.delete_sweep_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildNotificationTile({
    required String id,
    required String title,
    required String message,
    required String type,
    required dynamic dateEpoch,
    required VoidCallback onTap,
  }) {
    bool isRead = _readNotificationIds.contains(id);
    String displayDate = _formatDate(dateEpoch);

    IconData iconData;
    Color iconBgColor;
    Color iconColor;

    switch (type) {
      case 'mdrrmo':
        iconData = Icons.warning_rounded;
        iconBgColor = const Color(0xFFFEF2F2);
        iconColor = const Color(0xFFDC2626);
        break;
      case 'warning':
        iconData = Icons.storm_rounded;
        iconBgColor = const Color(0xFFFFFBEB);
        iconColor = const Color(0xFFD97706);
        break;
      case 'success':
        iconData = Icons.check_circle_rounded;
        iconBgColor = const Color(0xFFECFDF5);
        iconColor = const Color(0xFF10B981);
        break;
      case 'maritime':
        iconData = Icons.directions_boat_filled_rounded;
        iconBgColor = const Color(0xFFF3E8FF);
        iconColor = const Color(0xFF8B5CF6);
        break;
      case 'personal':
        iconData = Icons.person_rounded;
        iconBgColor = const Color(0xFFF0FDF4); // Soft green
        iconColor = const Color(0xFF16A34A);
        break;
      default:
        iconData = Icons.info_rounded;
        iconBgColor = const Color(0xFFEFF6FF);
        iconColor = accentBlue;
    }

    return Material(
      color: isRead ? Colors.white : accentBlue.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayDate,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w800,
                            color: isRead ? textSecondary : accentBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead
                            ? textSecondary
                            : textPrimary.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isRead) ...[
                const SizedBox(width: 12),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryDark.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 48,
              color: textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No notifications yet",
            style: TextStyle(
              color: primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "When you get updates, they'll show up here.",
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
