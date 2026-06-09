import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Maritime/MaritimeActivityLogger.dart';
import '../../Utility/SearchBarView.dart';
import 'SubActivities/AddEditPort.dart';

class PortsManagement extends StatefulWidget {
  const PortsManagement({super.key});

  @override
  State<PortsManagement> createState() => _PortsManagementState();
}

class _PortsManagementState extends State<PortsManagement> {
  final supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color accentColor = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  List<Map<String, dynamic>> _ports = [];
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();

  // --- SEARCH VARIABLES ---
  final TextEditingController _searchController = TextEditingController();
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
    _fetchPorts();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _preferences = await SharedPreferences.getInstance();
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
          _loadMorePorts();
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchPorts({bool isRefresh = false}) async {
    if (isRefresh || _ports.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }

    _offset = 0;
    _hasMore = true;

    try {
      var query = supabase.from('ports').select();

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('port_name', '%$_searchQuery%');
      }

      final data = await query
          .order('port_added_date', ascending: true)
          .range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          _ports = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
          if (data.length < _limit) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      Utility().printLog("Ports Fetch Error: $e");
      _showError("Unable to fetch ports. Please check your internet connection.");
    }
  }

  Future<void> _loadMorePorts() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    setState(() => _isLoadingMore = true);
    _offset += _limit;

    try {
      var query = supabase.from('ports').select();

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('port_name', '%$_searchQuery%');
      }

      final data = await query
          .order('port_added_date', ascending: true)
          .range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          _ports.addAll(List<Map<String, dynamic>>.from(data));
          _isLoadingMore = false;
          if (data.length < _limit) _hasMore = false; // Reached the end
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
      Utility().printLog("Load More Error: $e");
    }
  }

  // --- SEARCH LOGIC ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
        });
        _fetchPorts(isRefresh: true);
      }
    });
  }

  void _showError(String message) {
    _classicDialog.setTitle("System Error");
    _classicDialog.setMessage(message);
    _classicDialog.setPositiveMessage("Close");
    if (mounted) {
      _classicDialog.showOnButtonDialog(context, () => _classicDialog.dismissDialog());
    }
  }

  void _deletePort(Map<String, dynamic> port) {
    _classicDialog.setTitle("Delete Port");
    _classicDialog.setMessage("Are you sure you want to permanently delete ${port['port_name']}? This action cannot be undone.");
    _classicDialog.setNegativeMessage("CANCEL");
    _classicDialog.setPositiveMessage("DELETE");
    _classicDialog.setCancelable(true);

    if (mounted) {
      _classicDialog.showTwoButtonDialog(context, (negative) {
        _classicDialog.dismissDialog();
      }, (positive) async {
        _classicDialog.dismissDialog();
        _loadingDialog.showLoadingDialog(context);

        try {
          String userName = _preferences?.getString("user_name") ?? "Administrator";
          String assignedPort = _preferences?.getString("assigned_port") ?? "Unknown Port";
          String userId = _preferences?.getString("user_id") ?? "unknown_user_id";

          await supabase.from('ports')
              .delete()
              .eq('port_id', port['port_id']);

          String portName = port['port_name'].toString().toUpperCase();

          await MaritimeActivityLogger.createLog(
              title: "Port Deleted",
              message: "$portName was permanently deleted by [$assignedPort] - $userName.",
              creatorId: userId
          );

          _loadingDialog.dismiss();

          setState(() {
            _ports.removeWhere((p) => p['port_id'] == port['port_id']);
          });

          if (mounted) {
            SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "$portName successfully deleted.");
          }

        } catch (e) {
          _loadingDialog.dismiss();
          _showError("Failed to delete port. It may be linked to existing routes.");
        }
      });
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
              "Ports Management",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 22)
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_location_alt_rounded, size: 26),
              tooltip: 'Add Port',
              onPressed: () async {
                final dynamic result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddEditPort()),
                );

                if (result != null && result is Map<String, dynamic>) {
                  setState(() {
                    _ports.add(result);
                  });
                } else if (result == true) {
                  _fetchPorts(isRefresh: true);
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
                  hintText: "Search port names...",
                  focusedColor: primaryColor,
                  textSecondary: textSecondary,
                  outlineColor: outlineColor,
                ),

                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: primaryColor))
                      : RefreshIndicator(
                      color: primaryColor,
                      backgroundColor: Colors.white,
                      onRefresh: () => _fetchPorts(isRefresh: true),
                      child: Center(
                        child: _ports.isEmpty
                            ? _buildEmptyStateScrollable()
                            : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _ports.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _ports.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0),
                                child: Center(child: CircularProgressIndicator(color: accentColor)),
                              );
                            }
                            return _buildPortCard(_ports[index]);
                          },
                        ),
                      )
                  ),
                ),
              ],
            ),
          ),
        )
    );
  }

  Widget _buildPortCard(Map<String, dynamic> port) {
    final String portStatus = port['port_status'].toString();

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
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPortOptions(port),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.anchor_rounded, color: accentColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(port['port_name'] ?? "Unknown Port",
                          style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(port['port_address'] ?? "No address set",
                          style: TextStyle(color: textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.more_vert_rounded, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 6),
                    _buildStatusChip(portStatus),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final Color statusColor = status == "operational" ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status == "operational" ? "OPERATIONAL" : "CLOSED",
        style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 9),
      ),
    );
  }

  Widget _buildEmptyStateScrollable() {
    return Stack(
      children: [
        ListView(),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.location_off_rounded,
                  size: 64,
                  color: outlineColor
              ),
              const SizedBox(height: 16),
              Text(
                  _searchQuery.isNotEmpty ? "No matches found" : "No Ports Found",
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18)
              ),
              const SizedBox(height: 4),
              Text(
                  _searchQuery.isNotEmpty ? "Try a different search term." : "Pull down to refresh or add a new port.",
                  style: TextStyle(color: textSecondary, fontSize: 13)
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPortOptions(Map<String, dynamic> port) {
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
            Text(port['port_name'],
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textPrimary)),
            const SizedBox(height: 20),

            _buildSheetItem(Icons.edit_location_alt_rounded, "Edit Port Details", primaryColor, () async {
              Navigator.pop(context);
              final dynamic result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddEditPort(port: port)),
              );

              if (result != null && result is Map<String, dynamic>) {
                if (_searchQuery.isNotEmpty) {
                  setState(() {
                    _searchQuery = "";
                    _searchController.clear();
                  });
                  _fetchPorts(isRefresh: true);
                } else {
                  setState(() {
                    final index = _ports.indexWhere((p) => p['port_id'] == port['port_id']);
                    if (index != -1) {
                      _ports[index] = { ..._ports[index], ...result };
                    }
                  });
                }
              } else if (result == true) {
                _fetchPorts(isRefresh: true);
              }
            }),

            // _buildSheetItem(Icons.delete_forever_rounded, "Delete Record", Colors.redAccent, () {
            //   Navigator.pop(context);
            //   _deletePort(port);
            // }),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetItem(IconData icon, String label, Color color, VoidCallback onTap) {
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
}
