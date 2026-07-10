import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../FloatingMessages/SnackbarMessenger.dart';
import '../../Maritime/MaritimeActivityLogger.dart';
import '../../Maritime/MaritimeDataMapper.dart';
import '../../Utility/SearchBarView.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';

import 'SubActivities/AddEditVessel.dart';

class VesselsManagement extends StatefulWidget {
  final Map<String, dynamic> shippingLine;

  const VesselsManagement({super.key, required this.shippingLine});

  @override
  State<VesselsManagement> createState() => _VesselsManagementState();
}

class _VesselsManagementState extends State<VesselsManagement> {
  final supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();

  // Design System
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color accentColor = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  List<Map<String, dynamic>> _vessels = [];
  bool _isLoading = true;

  // --- SEARCH VARIABLES ---
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _searchQuery = "";

  final int _limit = 15;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  SharedPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _fetchVessels();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreVessels();
      }
    });
  }

  Future<void> _initPrefs() async {
    _preferences = await SharedPreferences.getInstance();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- SEARCH LOGIC ---
  void _onSearchChanged(String queryText) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != queryText) {
        setState(() {
          _searchQuery = queryText;
        });
        _fetchVessels(isRefresh: true);
      }
    });
  }

  Future<void> _fetchVessels({bool isRefresh = false}) async {
    if (isRefresh || _vessels.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }

    _offset = 0;
    _hasMore = true;

    try {
      var query = supabase
          .from('vessels')
          .select('*, vessel_operations(*)')
          .eq('shipping_line_id', widget.shippingLine['shipping_line_id']);

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('vessel_name', '%$_searchQuery%');
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          _vessels = MaritimeDataMapper.normalizeVessels(supabase, data);
          _isLoading = false;
          if (data.length < _limit) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _loadMoreVessels() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    setState(() => _isLoadingMore = true);
    _offset += _limit;

    try {
      var query = supabase
          .from('vessels')
          .select('*, vessel_operations(*)')
          .eq('shipping_line_id', widget.shippingLine['shipping_line_id']);

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('vessel_name', '%$_searchQuery%');
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          _vessels.addAll(MaritimeDataMapper.normalizeVessels(supabase, data));
          _isLoadingMore = false;
          if (data.length < _limit) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
      debugPrint("Load More Error: $e");
    }
  }

  void _showErrorDialog(String message) {
    _classicDialog.setTitle("An error occurred");
    _classicDialog.setMessage(message);
    _classicDialog.setPositiveMessage("Close");
    _classicDialog.setCancelable(false);
    if (mounted) {
      _classicDialog.showOnButtonDialog(context, () {
        _classicDialog.dismissDialog();
      });
    }
  }

  void _deleteVessel(Map<String, dynamic> vessel) {
    _classicDialog.setTitle("Delete Vessel");
    _classicDialog.setMessage(
      "Permanently remove ${vessel['vessel_name']}?\n\nThis action cannot be undone.",
    );
    _classicDialog.setNegativeMessage("CANCEL");
    _classicDialog.setPositiveMessage("DELETE");
    _classicDialog.setCancelable(true);

    if (mounted) {
      _classicDialog.showTwoButtonDialog(
        context,
        (negativeClicked) => _classicDialog.dismissDialog(),
        (positiveClicked) async {
          _classicDialog.dismissDialog();
          _loadingDialog.showLoadingDialog(context);

          try {
            final List<dynamic> response = await supabase
                .from('vessels')
                .delete()
                .eq('vessel_id', vessel['vessel_id'])
                .select();

            if (response.isEmpty) {
              throw Exception(
                "Deletion blocked by the database. Please check your Supabase Row Level Security (RLS) policies.",
              );
            }

            String userName =
                _preferences?.getString("user_name") ?? "An Admin";
            String assignedPort =
                _preferences?.getString("assigned_port") ?? "Unknown Port";
            String userId =
                _preferences?.getString("user_id") ?? "unknown_user_id";
            String vesselName = vessel['vessel_name'].toString().toUpperCase();

            await MaritimeActivityLogger.createLog(
              title: "Vessel Deleted",
              message:
                  "$vesselName was permanently deleted by [$assignedPort] - $userName.",
              creatorId: userId,
            );

            _loadingDialog.dismiss();

            setState(() {
              _vessels.removeWhere(
                (v) => v['vessel_id'] == vessel['vessel_id'],
              );
              if (_offset > 0) _offset--;
            });

            if (mounted) {
              SnackbarMessenger().showSnackbar(
                context,
                SnackbarMessenger.success,
                "${vessel['vessel_name']} was deleted.",
              );
            }
          } catch (e) {
            Utility().printLog("Error: ${e.toString()}");
            _loadingDialog.dismiss();
            _showErrorDialog(e.toString());
          }
        },
      );
    }
  }

  void _showOptionsBottomSheet(Map<String, dynamic> vessel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: outlineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                vessel['vessel_name'] ?? "Options",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              _buildSheetItem(
                icon: Icons.edit_rounded,
                label: "Edit Details",
                color: primaryColor,
                onTap: () async {
                  Navigator.pop(context);
                  final dynamic result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditVessel(
                        vessel: vessel,
                        shippingLineId: widget.shippingLine['shipping_line_id'],
                      ),
                    ),
                  );

                  if (result != null && result is Map<String, dynamic>) {
                    if (_searchQuery.isNotEmpty) {
                      setState(() {
                        _searchQuery = "";
                        _searchController.clear();
                      });
                      _fetchVessels(isRefresh: true);
                    } else {
                      setState(() {
                        final index = _vessels.indexWhere(
                          (v) => v['vessel_id'] == vessel['vessel_id'],
                        );
                        if (index != -1) {
                          _vessels[index] = {..._vessels[index], ...result};
                        }
                      });
                    }
                  }
                },
              ),

              _buildSheetItem(
                icon: Icons.delete_forever_rounded,
                label: "Delete Permanently",
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _deleteVessel(vessel);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  // --- TIME FORMATTER LOGIC FOR TIMELINE ---
  String _formatTime(int epochMillis) {
    if (epochMillis <= 0) return "--:--";
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    int h = dt.hour;
    int m = dt.minute;
    String period = h >= 12 ? "PM" : "AM";
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    return "$h:${m.toString().padLeft(2, '0')} $period";
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Fleet Management",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              widget.shippingLine['shipping_line_name'],
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
            tooltip: "Register Vessel",
            onPressed: () async {
              final dynamic result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditVessel(
                    shippingLineId: widget.shippingLine['shipping_line_id'],
                  ),
                ),
              );

              if (result != null && result is Map<String, dynamic>) {
                setState(() {
                  _vessels.insert(0, result);
                  _offset++;
                });
              }
            },
          ),
          const SizedBox(width: 8),
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
                hintText: "Search vessel names...",
                focusedColor: primaryColor,
                textSecondary: textSecondary,
                outlineColor: outlineColor,
              ),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                    : RefreshIndicator(
                        color: primaryColor,
                        onRefresh: () => _fetchVessels(isRefresh: true),
                        child: _vessels.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                itemCount:
                                    _vessels.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _vessels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: accentColor,
                                        ),
                                      ),
                                    );
                                  }
                                  return _buildVesselCard(_vessels[index]);
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVesselCard(Map<String, dynamic> vessel) {
    String displayStatus = "Unknown";
    int departureEpoch = 0;
    int arrivalEpoch = 0;
    String dockedState = 'docked';

    final dynamic statusData = vessel['vessel_status'];

    if (statusData is Map) {
      displayStatus = (statusData['status'] ?? "Unknown").toString();
      departureEpoch =
          int.tryParse(statusData['departed']?.toString() ?? "0") ?? 0;
      arrivalEpoch =
          int.tryParse(statusData['arrival']?.toString() ?? "0") ?? 0;
      dockedState = statusData['docked_state']?.toString() ?? 'docked';
    } else {
      displayStatus = statusData?.toString() ?? "Unknown";
    }

    final String statusLower = displayStatus.toLowerCase();
    final displayLabel = statusLower == 'docked' && dockedState != 'docked'
        ? "Docked | ${dockedState == 'tba' ? 'TBA' : 'Preparing'}"
        : displayStatus.replaceAll('_', ' ');

    bool showTimeline =
        (departureEpoch > 0 || arrivalEpoch > 0) &&
        statusLower != "maintenance" &&
        statusLower != "onboarding" &&
        statusLower != "docked";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOptionsBottomSheet(vessel),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_boat_filled_rounded,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vessel['vessel_name'] ?? "Unknown Ship",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vessel['vessel_type'] ?? "Ro-Ro Passenger",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(Icons.more_vert_rounded, color: outlineColor),
                        const SizedBox(height: 8),
                        _buildStatusBadge(displayLabel),
                      ],
                    ),
                  ],
                ),

                if (showTimeline) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimeInfo(
                        "DEPARTURE",
                        departureEpoch > 0
                            ? _formatTime(departureEpoch)
                            : "--:--",
                        Icons.logout_rounded,
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: outlineColor,
                      ),
                      _buildTimeInfo(
                        "ARRIVAL",
                        arrivalEpoch > 0 ? _formatTime(arrivalEpoch) : "--:--",
                        Icons.login_rounded,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: textSecondary.withValues(alpha: 0.6),
              ),
            ),
            Text(
              time.isEmpty ? "--:--" : time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'docked':
        return Colors.teal;
      case 'active':
        return Colors.green;
      case 'en route':
        return accentColor;
      case 'delayed':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      case 'departed':
        return accentColor;
      case 'arrived':
        return const Color(0xFF10B981);
      case 'onboarding':
        return Colors.orange;
      default:
        return textSecondary;
    }
  }

  Widget _buildEmptyState() {
    return Stack(
      children: [
        ListView(),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.directions_boat_outlined,
                size: 60,
                color: outlineColor,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? "No matches found"
                    : "No vessels registered",
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
