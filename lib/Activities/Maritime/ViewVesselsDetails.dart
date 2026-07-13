import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Maritime/MaritimeDataMapper.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/VesselStatus.dart';
import '../../Colors/IndicatorColors.dart';
import '../../Dialogs/Bottomsheets/ViewFares.dart';
import '../../Dialogs/Bottomsheets/ViewSchedules.dart';
import '../../Utility/SearchBarView.dart';
import 'VesselTracking.dart';

class ViewVesselsDetails extends StatefulWidget {
  final Map<String, dynamic> shippingLine;

  const ViewVesselsDetails({super.key, required this.shippingLine});

  @override
  State<ViewVesselsDetails> createState() => _ViewVesselsDetailsState();
}

class _ViewVesselsDetailsState extends State<ViewVesselsDetails> {
  final supabase = Supabase.instance.client;

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color accentBlue = const Color(0xFF3B82F6);

  List<Map<String, dynamic>> _vessels = [];
  List<Map<String, dynamic>> _availablePorts = [];

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = "";
  String? _selectedStatusFilter;
  String? _selectedPortFilter;

  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  final int _limit = 15;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String queryText) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != queryText) {
        setState(() => _searchQuery = queryText);
        _fetchData(isRefresh: true);
      }
    });
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    if (isRefresh || _vessels.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }
    _offset = 0;
    _hasMore = true;

    try {
      if (_availablePorts.isEmpty) {
        final portsResponse = await supabase
            .from('ports')
            .select('port_id, port_name')
            .order('port_name');
        if (mounted) {
          _availablePorts = List<Map<String, dynamic>>.from(portsResponse);
        }
      }

      var query = supabase
          .from('vessels')
          .select('*, vessel_operations(*)')
          .eq('shipping_line_id', widget.shippingLine['shipping_line_id']);

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('vessel_name', '%$_searchQuery%');
      }
      final vesselsResponse = await query
          .order('vessel_name')
          .range(_offset, _offset + _limit - 1);
      final normalized =
          MaritimeDataMapper.normalizeVessels(supabase, vesselsResponse).where((
            vessel,
          ) {
            final status = vessel['vessel_status']?['status']?.toString();
            final destination = vessel['vessel_status']?['destination']
                ?.toString();
            if (_selectedStatusFilter != null &&
                status !=
                    _selectedStatusFilter!.toLowerCase().replaceAll(' ', '_')) {
              return false;
            }
            if (_selectedPortFilter != null &&
                destination != _selectedPortFilter) {
              return false;
            }
            return true;
          }).toList();

      if (mounted) {
        setState(() {
          _vessels = normalized;
          _offset += (vesselsResponse as List).length;
          if ((vesselsResponse as List).length < _limit) _hasMore = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching vessels: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreData() async {
    if (!_hasMore || _isFetchingMore || _isLoading) return;
    setState(() => _isFetchingMore = true);

    try {
      var query = supabase
          .from('vessels')
          .select('*, vessel_operations(*)')
          .eq('shipping_line_id', widget.shippingLine['shipping_line_id']);
      if (_searchQuery.isNotEmpty) {
        query = query.ilike('vessel_name', '%$_searchQuery%');
      }
      final vesselsResponse = await query
          .order('vessel_name')
          .range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          final newVessels =
              MaritimeDataMapper.normalizeVessels(
                supabase,
                vesselsResponse,
              ).where((vessel) {
                final status = vessel['vessel_status']?['status']?.toString();
                final destination = vessel['vessel_status']?['destination']
                    ?.toString();
                if (_selectedStatusFilter != null &&
                    status !=
                        _selectedStatusFilter!.toLowerCase().replaceAll(
                          ' ',
                          '_',
                        )) {
                  return false;
                }
                if (_selectedPortFilter != null &&
                    destination != _selectedPortFilter) {
                  return false;
                }
                return true;
              }).toList();
          _vessels.addAll(newVessels);
          _offset += (vesselsResponse as List).length;
          if (newVessels.length < _limit) _hasMore = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading more: $e");
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  List<dynamic> _parseData(dynamic data) {
    if (data == null) return [];
    try {
      if (data is String) {
        if (data.trim().isEmpty) return [];
        var decoded = jsonDecode(data);
        return decoded is List ? decoded : [decoded];
      }
      return data is List ? data : [data];
    } catch (e) {
      return [];
    }
  }

  String _getPortName(String? portId) {
    if (portId == null) return "";
    final port = _availablePorts.firstWhere(
      (p) => p['port_id'].toString() == portId,
      orElse: () => {},
    );
    return port['port_name']?.toString() ?? "";
  }

  String _formatTime(int epochMillis) {
    if (epochMillis <= 0) return "--:--";
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    int h = dt.hour;
    String m = dt.minute.toString().padLeft(2, '0');
    String period = h >= 12 ? "PM" : "AM";
    if (h == 0) {
      h = 12;
    } else if (h > 12) {
      h -= 12;
    }
    return "$h:$m $period";
  }

  void _openFaresBottomSheet() {
    final List<dynamic> fares = _parseData(
      widget.shippingLine['shipping_line_fares'],
    );
    final String lineName =
        widget.shippingLine['shipping_line_name'] ?? 'Shipping Line';
    ViewFares.showBottomSheet(
      context: context,
      shippingLineName: lineName,
      fares: fares,
    );
  }

  void _openSchedulesBottomSheet() {
    final List<dynamic> schedules = _parseData(
      widget.shippingLine['shipping_line_schedules'],
    );
    final String lineName =
        widget.shippingLine['shipping_line_name'] ?? 'Shipping Line';
    ViewSchedules.showBottomSheet(
      context: context,
      shippingLineName: lineName,
      schedules: schedules,
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStatusFilter != null) count++;
    if (_selectedPortFilter != null) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedPortFilter = null;
    });
    _fetchData(isRefresh: true);
  }

  void _openFilterSheet() {
    String? tempPort = _selectedPortFilter;
    String? tempStatus = _selectedStatusFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accentBlue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.filter_list_rounded,
                            color: accentBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Filter Fleet",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildFilterDropdown(
                      label: "Destination Port",
                      value: tempPort,
                      icon: Icons.location_on_rounded,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            "All destinations",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        ..._availablePorts.map(
                          (port) => DropdownMenuItem<String>(
                            value: port['port_id'].toString(),
                            child: Text(
                              port['port_name'].toString(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: primaryDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setModalState(() {
                        tempPort = value;
                      }),
                    ),
                    const SizedBox(height: 14),
                    _buildFilterDropdown(
                      label: "Status",
                      value: tempStatus,
                      icon: Icons.flag_rounded,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            "All statuses",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        ...VesselStatus().statusList.map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: primaryDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setModalState(() {
                        tempStatus = value;
                      }),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _clearFilters();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: primaryDark,
                              side: BorderSide(color: outlineColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Clear",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {
                                _selectedPortFilter = tempPort;
                                _selectedStatusFilter = tempStatus;
                              });
                              _fetchData(isRefresh: true);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: accentBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Apply",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDynamicStatusBadge(String status, StatusColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: colors.text,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String label, Color textColor, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withValues(alpha: 0.12)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: outlineColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              icon: Icon(icon, size: 18, color: textSecondary),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color color, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 9),
        Text(
          "$label:",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child:
              trailing ??
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
        ),
      ],
    );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Fleet Details",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              widget.shippingLine['shipping_line_name'] ?? 'Shipping Line',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: "Filter fleet",
                onPressed: _openFilterSheet,
                icon: const Icon(Icons.filter_list_rounded),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accentBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _activeFilterCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
              SearchBarView(
                controller: _searchController,
                onChanged: _onSearchChanged,
                searchQuery: _searchQuery,
                hintText: "Search fleet...",
                focusedColor: accentBlue,
                textSecondary: textSecondary,
                outlineColor: outlineColor,
              ),

              const SizedBox(height: 12),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: accentBlue),
                      )
                    : _vessels.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _fetchData(isRefresh: true),
                        color: accentBlue,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount:
                              _vessels.length + (_isFetchingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _vessels.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: accentBlue,
                                  ),
                                ),
                              );
                            }
                            return _buildVesselCard(_vessels[index]);
                          },
                        ),
                      ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: outlineColor)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: primaryDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.confirmation_number_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          "View Fares",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: _openFaresBottomSheet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: accentBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          "Schedules",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: _openSchedulesBottomSheet,
                      ),
                    ),
                  ],
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
    String originName = "";
    String destName = "";
    int departedEpoch = 0;
    int onboardingEpoch = 0;
    int onboardingDuration = 0;
    String dockedState = 'docked';

    final dynamic statusData = vessel['vessel_status'];
    if (statusData is Map) {
      displayStatus = (statusData['status'] ?? "Docked").toString().trim();
      originName = _getPortName(statusData['origin']?.toString());
      destName = _getPortName(statusData['destination']?.toString());
      departedEpoch =
          int.tryParse(statusData['departed']?.toString() ?? "0") ?? 0;
      onboardingEpoch =
          int.tryParse(statusData['onboarding_time']?.toString() ?? "0") ?? 0;
      onboardingDuration =
          int.tryParse(
            statusData['onboarding_duration_minutes']?.toString() ?? "0",
          ) ??
          0;
      dockedState = statusData['docked_state']?.toString() ?? 'docked';
    } else {
      displayStatus = statusData?.toString().trim() ?? "Docked";
    }

    final String statusLower = displayStatus.toLowerCase();
    final displayLabel = displayStatus.replaceAll('_', ' ');
    final dockedLabel = statusLower == 'docked' && dockedState != 'docked'
        ? (dockedState == 'tba' ? 'TBA' : 'Preparing')
        : null;
    bool showRoute =
        statusLower == 'departed' ||
        statusLower == 'arrived' ||
        statusLower == 'onboarding' ||
        statusLower == 'standby';
    bool isOnboarding = statusLower == 'onboarding' && onboardingEpoch > 0;

    final StatusColors statusColors = IndicatorColors.getColors(displayStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: outlineColor),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showDialog(
            context: context,
            builder: (context) =>
                VesselTracking(vessel: vessel, availablePorts: _availablePorts),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: statusColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusColors.border),
                      ),
                      child: Icon(
                        Icons.directions_boat_filled_rounded,
                        size: 22,
                        color: statusColors.text,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vessel['vessel_name'] ?? "Unknown",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vessel['vessel_type'] ?? 'Passenger Ship',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildDynamicStatusBadge(
                                displayLabel,
                                statusColors,
                              ),
                              if (dockedLabel != null)
                                _buildSmallBadge(
                                  dockedLabel,
                                  const Color(0xFF475569),
                                  const Color(0xFFF1F5F9),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: outlineColor),
                  ),
                  child: Column(
                    children: [
                      if (showRoute && originName.isNotEmpty)
                        _buildInfoRow(
                          Icons.route_rounded,
                          "Route",
                          destName.isNotEmpty
                              ? "$originName to $destName"
                              : originName,
                          statusColors.text,
                        )
                      else
                        _buildInfoRow(
                          Icons.anchor_rounded,
                          "Port",
                          originName.isNotEmpty ? originName : "-:-",
                          statusColors.text,
                        ),
                      if (statusLower == 'docked' && dockedState == 'tba') ...[
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          Icons.flag_rounded,
                          "Departure",
                          "Selected to depart",
                          statusColors.text,
                        ),
                      ],
                      if (statusLower == 'departed' && departedEpoch > 0) ...[
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          Icons.logout_rounded,
                          "Departed",
                          _formatTime(departedEpoch),
                          statusColors.text,
                        ),
                      ],
                      if (isOnboarding) ...[
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          Icons.timer_outlined,
                          "Boarding",
                          "",
                          statusColors.text,
                          trailing: LiveOnboardingCounter(
                            startTimeEpoch: onboardingEpoch,
                            durationMinutes: onboardingDuration,
                            colorTheme: statusColors.text,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    bool hasFilters =
        _searchQuery.isNotEmpty ||
        _selectedStatusFilter != null ||
        _selectedPortFilter != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters
                ? Icons.search_off_rounded
                : Icons.directions_boat_outlined,
            size: 48,
            color: textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "No vessels found",
            style: TextStyle(
              color: primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            hasFilters ? "Try adjusting your filters." : "Directory is empty.",
            style: TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class LiveOnboardingCounter extends StatefulWidget {
  final int startTimeEpoch;
  final int durationMinutes;
  final Color colorTheme;
  const LiveOnboardingCounter({
    super.key,
    required this.startTimeEpoch,
    required this.durationMinutes,
    required this.colorTheme,
  });
  @override
  State<LiveOnboardingCounter> createState() => _LiveOnboardingCounterState();
}

class _LiveOnboardingCounterState extends State<LiveOnboardingCounter> {
  Timer? _timer;
  int _remainingSeconds = 0;
  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _calculateTime(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTime() {
    final diff =
        (widget.startTimeEpoch + (widget.durationMinutes * 60 * 1000)) -
        DateTime.now().millisecondsSinceEpoch;
    if (diff > 0) {
      if (mounted) {
        setState(() => _remainingSeconds = diff ~/ 1000);
      }
    } else {
      if (_remainingSeconds != 0 && mounted) {
        setState(() => _remainingSeconds = 0);
      }
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOver = _remainingSeconds <= 0;
    final Color textColor = isOver ? Colors.redAccent : widget.colorTheme;
    int m = (_remainingSeconds % 3600) ~/ 60;
    int s = _remainingSeconds % 60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOver ? Icons.timer_off_outlined : Icons.timer_outlined,
          size: 12,
          color: textColor,
        ),
        const SizedBox(width: 4),
        Text(
          isOver
              ? "Waiting for departure"
              : "Est. Departure in ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
