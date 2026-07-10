import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../Maritime/MaritimeActivityLogger.dart';
import '../../Maritime/MaritimeDataMapper.dart';
import '../../Utility/SearchBarView.dart';
import 'SubActivities/AddEditShippingLine.dart';
import 'VesselsManagement.dart';

class ShippingLinesManagement extends StatefulWidget {
  const ShippingLinesManagement({super.key});

  @override
  State<ShippingLinesManagement> createState() =>
      _ShippingLinesManagementState();
}

class _ShippingLinesManagementState extends State<ShippingLinesManagement> {
  final supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();

  // Design System Colors
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color accentColor = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  List<Map<String, dynamic>> _shippingLines = [];
  List<Map<String, dynamic>> _ports = [];
  bool _isLoading = true;

  // --- SEARCH & PAGINATION VARIABLES ---
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _searchQuery = "";

  final int _limit = 10; // Limit per load
  int _offset = 0;
  bool _hasMore = true; // Tells us if there's more data to fetch in the DB
  bool _isLoadingMore = false; // Prevents overlapping fetch calls

  SharedPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchShippingLines();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreShippingLines();
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
        _fetchShippingLines(isRefresh: true);
      }
    });
  }

  Future<void> _fetchShippingLines({bool isRefresh = false}) async {
    if (isRefresh || _shippingLines.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }

    _offset = 0;
    _hasMore = true;

    try {
      if (_ports.isEmpty) await _fetchPorts();
      final portNames = {
        for (final port in _ports)
          port['port_id'].toString(): port['port_name'].toString(),
      };
      var query = supabase
          .from('shipping_lines')
          .select('*, shipping_line_route_profiles(*, shipping_line_fares(*))');

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('shipping_line_name', '%$_searchQuery%');
      }

      final shippingLineData = await query
          .order('created_at', ascending: true)
          .range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          _shippingLines = List<Map<String, dynamic>>.from(shippingLineData)
              .map(
                (line) =>
                    MaritimeDataMapper.normalizeShippingLine(line, portNames),
              )
              .toList();
          _isLoading = false;
          if (shippingLineData.length < _limit) _hasMore = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _isLoading = false);
      _showErrorDialog(error.toString());
    }
  }

  Future<void> _loadMoreShippingLines() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    setState(() => _isLoadingMore = true);
    _offset += _limit;

    try {
      final portNames = {
        for (final port in _ports)
          port['port_id'].toString(): port['port_name'].toString(),
      };
      var query = supabase
          .from('shipping_lines')
          .select('*, shipping_line_route_profiles(*, shipping_line_fares(*))');

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('shipping_line_name', '%$_searchQuery%');
      }

      final data = await query
          .order('created_at', ascending: true)
          .range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          _shippingLines.addAll(
            List<Map<String, dynamic>>.from(data).map(
              (line) =>
                  MaritimeDataMapper.normalizeShippingLine(line, portNames),
            ),
          );
          _isLoadingMore = false;
          if (data.length < _limit) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
      debugPrint("Load More Error: $e");
    }
  }

  Future<void> _fetchPorts() async {
    try {
      final portData = await supabase
          .from('ports')
          .select()
          .order('port_name', ascending: true);
      _ports = List<Map<String, dynamic>>.from(portData);
    } catch (error) {
      _showErrorDialog(error.toString());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        title: const Text(
          "Shipping Lines",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_rounded, size: 26),
            tooltip: "Add Line",
            onPressed: () async {
              if (_ports.isEmpty || _ports.length < 2) {
                SnackbarMessenger().showSnackbar(
                  context,
                  SnackbarMessenger.neutral,
                  "Please add at least 2 ports first.",
                );
                return;
              }

              final dynamic result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditShippingLine(ports: _ports),
                ),
              );

              if (result != null && result is Map<String, dynamic>) {
                setState(() => _shippingLines.add(result));
              } else if (result == true) {
                _fetchShippingLines(isRefresh: true);
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
                hintText: "Search shipping lines...",
                focusedColor: primaryColor,
                textSecondary: textSecondary,
                outlineColor: outlineColor,
              ),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                    : _shippingLines.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: primaryColor,
                        backgroundColor: Colors.white,
                        onRefresh: () => _fetchShippingLines(isRefresh: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          itemCount:
                              _shippingLines.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _shippingLines.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24.0,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: accentColor,
                                  ),
                                ),
                              );
                            }

                            final line = _shippingLines[index];
                            return _buildLineCard(line);
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

  Widget _buildLineCard(Map<String, dynamic> line) {
    final List schedules = line['shipping_line_schedules'] is String
        ? jsonDecode(line['shipping_line_schedules'])
        : (line['shipping_line_schedules'] ?? []);
    final List fares = line['shipping_line_fares'] is String
        ? jsonDecode(line['shipping_line_fares'])
        : (line['shipping_line_fares'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOptionsBottomSheet(line),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.business_rounded, color: primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line['shipping_line_name'] ?? "Unknown Line",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${schedules.length} Routes • ${fares.length} Fares",
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_vert_rounded, color: outlineColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsBottomSheet(Map<String, dynamic> line) {
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
                line['shipping_line_name'] ?? "Options",
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
                      builder: (context) => AddEditShippingLine(
                        shippingLine: line,
                        ports: _ports,
                      ),
                    ),
                  );

                  if (result != null && result is Map<String, dynamic>) {
                    if (_searchQuery.isNotEmpty) {
                      setState(() {
                        _searchQuery = "";
                        _searchController.clear();
                      });
                      _fetchShippingLines(isRefresh: true);
                    } else {
                      setState(() {
                        final index = _shippingLines.indexWhere(
                          (l) =>
                              l['shipping_line_id'] == line['shipping_line_id'],
                        );
                        if (index != -1) {
                          _shippingLines[index] = {
                            ..._shippingLines[index],
                            ...result,
                          };
                        }
                      });
                    }
                  } else if (result == true) {
                    _fetchShippingLines(isRefresh: true);
                  }
                },
              ),

              _buildSheetItem(
                icon: Icons.directions_boat_filled_rounded,
                label: "View Vessels",
                color: accentColor,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          VesselsManagement(shippingLine: line),
                    ),
                  );
                },
              ),

              _buildSheetItem(
                icon: Icons.delete_forever_rounded,
                label: "Delete Permanently",
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _deleteLine(line);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _deleteLine(Map<String, dynamic> line) {
    _classicDialog.setTitle("Delete Record & Fleet");
    _classicDialog.setMessage(
      "Permanently remove ${line['shipping_line_name']} and ALL its registered vessels?\n\nThis action cannot be undone.",
    );
    _classicDialog.setNegativeMessage("CANCEL");
    _classicDialog.setPositiveMessage("DELETE");
    _classicDialog.setCancelable(true);

    if (mounted) {
      _classicDialog.showTwoButtonDialog(
        context,
        (negativeClicked) {
          _classicDialog.dismissDialog();
        },
        (positiveClicked) async {
          _classicDialog.dismissDialog();
          _loadingDialog.showLoadingDialog(context);

          try {
            await supabase
                .from('shipping_lines')
                .delete()
                .eq('shipping_line_id', line['shipping_line_id']);

            String userName =
                _preferences?.getString("user_name") ?? "An Admin";
            String assignedPort =
                _preferences?.getString("assigned_port") ?? "Unknown Port";
            String lineName = line['shipping_line_name']
                .toString()
                .toUpperCase();
            String userId =
                _preferences?.getString("user_id") ?? "unknown_user_id";

            await MaritimeActivityLogger.createLog(
              title: "Shipping Line Deleted",
              message:
                  "$lineName and its fleet were permanently deleted by [$assignedPort] - $userName.",
              creatorId: userId,
            );

            _loadingDialog.dismiss();

            // Instantly remove it from the list without hitting the database
            setState(() {
              _shippingLines.removeWhere(
                (l) => l['shipping_line_id'] == line['shipping_line_id'],
              );
            });

            if (mounted) {
              SnackbarMessenger().showSnackbar(
                context,
                SnackbarMessenger.success,
                "${line['shipping_line_name']} and its fleet were deleted.",
              );
            }
          } catch (e) {
            _loadingDialog.dismiss();
            _showErrorDialog(e.toString());
          }
        },
      );
    }
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

  Widget _buildEmptyState() {
    return Stack(
      children: [
        ListView(), // Enables pull-to-refresh even when empty
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.anchor_rounded,
                size: 60,
                color: outlineColor,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? "No matches found"
                    : "No records found",
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
