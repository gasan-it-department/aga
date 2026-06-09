import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/VesselStatus.dart';
import '../../Colors/IndicatorColors.dart'; // Added IndicatorColors
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

  // Theme Colors
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color accentBlue = const Color(0xFF3B82F6);

  List<Map<String, dynamic>> _vessels = [];
  List<Map<String, dynamic>> _availablePorts = [];

  // --- SEARCH & FILTER VARIABLES ---
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = "";
  String? _selectedStatusFilter;
  String? _selectedPortFilter;

  // --- PAGINATION VARIABLES ---
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
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
        final portsResponse = await supabase.from('ports').select('port_id, port_name').order('port_name');
        if (mounted) _availablePorts = List<Map<String, dynamic>>.from(portsResponse);
      }

      var query = supabase.from('vessels').select().eq('shipping_line_id', widget.shippingLine['shipping_line_id']);

      if (_searchQuery.isNotEmpty) query = query.ilike('vessel_name', '%$_searchQuery%');
      if (_selectedStatusFilter != null) query = query.eq('vessel_status->>status', _selectedStatusFilter!);
      if (_selectedPortFilter != null) query = query.eq('vessel_status->>destination', _selectedPortFilter!);

      final vesselsResponse = await query.order('vessel_name').range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          _vessels = List<Map<String, dynamic>>.from(vesselsResponse);
          _offset += _vessels.length;
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
      var query = supabase.from('vessels').select().eq('shipping_line_id', widget.shippingLine['shipping_line_id']);
      if (_searchQuery.isNotEmpty) query = query.ilike('vessel_name', '%$_searchQuery%');
      if (_selectedStatusFilter != null) query = query.eq('vessel_status->>status', _selectedStatusFilter!);
      if (_selectedPortFilter != null) query = query.eq('vessel_status->>destination', _selectedPortFilter!);

      final vesselsResponse = await query.order('vessel_name').range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          final newVessels = List<Map<String, dynamic>>.from(vesselsResponse);
          _vessels.addAll(newVessels);
          _offset += newVessels.length;
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
    } catch (e) { return []; }
  }

  String _getPortName(String? portId) {
    if (portId == null) return "";
    final port = _availablePorts.firstWhere((p) => p['port_id'].toString() == portId, orElse: () => {});
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

  String _calculateStaticETA(int startEpoch, int? durationMinutes) {
    int duration = (durationMinutes != null && durationMinutes > 0) ? durationMinutes : 170;
    return _formatTime(startEpoch + (duration * 60 * 1000));
  }

  void _openFaresBottomSheet() {
    final List<dynamic> fares = _parseData(widget.shippingLine['shipping_line_fares']);
    final String lineName = widget.shippingLine['shipping_line_name'] ?? 'Shipping Line';
    ViewFares.showBottomSheet(context: context, shippingLineName: lineName, fares: fares);
  }

  void _openSchedulesBottomSheet() {
    final List<dynamic> schedules = _parseData(widget.shippingLine['shipping_line_schedules']);
    final String lineName = widget.shippingLine['shipping_line_name'] ?? 'Shipping Line';
    ViewSchedules.showBottomSheet(context: context, shippingLineName: lineName, schedules: schedules);
  }

  // --- Helper method to build the badge using IndicatorColors ---
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: primaryDark, elevation: 0, centerTitle: false, title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Fleet Details", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text(widget.shippingLine['shipping_line_name'] ?? 'Shipping Line', style: TextStyle(fontSize: 12, color: textSecondary))])),
      body: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        SearchBarView(
            controller: _searchController,
            onChanged: _onSearchChanged,
            searchQuery: _searchQuery,
            hintText: "Search fleet...",
            focusedColor: accentBlue,
            textSecondary: textSecondary,
            outlineColor: outlineColor
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // DESTINATION FILTER
              Expanded(
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: outlineColor)),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedPortFilter,
                            hint: Text("Destination port", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                            icon: Icon(Icons.location_on_rounded, size: 16, color: textSecondary),
                            items: [
                              DropdownMenuItem(value: null, child: Text("Destination port", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary))),
                              ..._availablePorts.map((port) => DropdownMenuItem(value: port['port_id'].toString(), child: Text(port['port_name'].toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryDark), overflow: TextOverflow.ellipsis)))
                            ],
                            onChanged: (val) { setState(() => _selectedPortFilter = val); _fetchData(isRefresh: true); }
                        )
                    )
                ),
              ),
              const SizedBox(width: 8),
              // STATUS FILTER
              Expanded(
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: outlineColor)),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedStatusFilter,
                            hint: Text("Status", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                            icon: Icon(Icons.filter_list_rounded, size: 16, color: textSecondary),
                            items: [
                              DropdownMenuItem(value: null, child: Text("All Status", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary))),
                              ...VesselStatus().statusList.map((status) => DropdownMenuItem(value: status, child: Text(status.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryDark))))
                            ],
                            onChanged: (val) { setState(() => _selectedStatusFilter = val); _fetchData(isRefresh: true); }
                        )
                    )
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Expanded(child: _isLoading ? Center(child: CircularProgressIndicator(color: accentBlue)) : _vessels.isEmpty ? _buildEmptyState() : RefreshIndicator(onRefresh: () => _fetchData(isRefresh: true), color: accentBlue, child: ListView.builder(controller: _scrollController, padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), itemCount: _vessels.length + (_isFetchingMore ? 1 : 0), itemBuilder: (context, index) { if (index == _vessels.length) return Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: accentBlue))); return _buildVesselCard(_vessels[index]); }))),

        // --- BOTTOM ACTION BUTTONS ---
        Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: outlineColor)), boxShadow: [BoxShadow(color: primaryDark.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
            child: Row(
                children: [
                  Expanded(
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: const Color(0xFFF1F5F9), foregroundColor: primaryDark, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          icon: const Icon(Icons.confirmation_number_rounded, size: 18),
                          label: const Text("View Fares", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          onPressed: _openFaresBottomSheet
                      )
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: accentBlue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          icon: const Icon(Icons.calendar_month_rounded, size: 18),
                          label: const Text("Schedules", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          onPressed: _openSchedulesBottomSheet
                      )
                  ),
                ]
            )
        )
      ]))),
    );
  }

  Widget _buildVesselCard(Map<String, dynamic> vessel) {
    String displayStatus = "Unknown";
    String originName = "";
    String destName = "";
    int departedEpoch = 0;
    int onboardingEpoch = 0;
    int onboardingDuration = 0;
    int? travelDuration;

    final dynamic statusData = vessel['vessel_status'];
    if (statusData is Map) {
      // Added .trim() to ensure reliable string matching
      displayStatus = (statusData['status'] ?? "Docked").toString().trim();
      originName = _getPortName(statusData['origin']?.toString());
      destName = _getPortName(statusData['destination']?.toString());
      departedEpoch = int.tryParse(statusData['departed']?.toString() ?? "0") ?? 0;
      onboardingEpoch = int.tryParse(statusData['onboarding_time']?.toString() ?? "0") ?? 0;
      onboardingDuration = int.tryParse(statusData['onboarding_duration_minutes']?.toString() ?? "0") ?? 0;
      travelDuration = int.tryParse(statusData['travel_duration_minutes']?.toString() ?? "0");
    } else {
      displayStatus = statusData?.toString().trim() ?? "Docked";
    }

    final String statusLower = displayStatus.toLowerCase();
    bool showRoute = statusLower == 'departed' || statusLower == 'arrived' || statusLower == 'onboarding' || statusLower == 'standby';
    bool isOnboarding = statusLower == 'onboarding' && onboardingEpoch > 0;

    // Fetch dynamic colors based on status
    final StatusColors statusColors = IndicatorColors.getColors(displayStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: primaryDark.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4)
            )
          ]
      ),
      // --- FIXED: Use Material to enforce background color painting ---
      child: Material(
          color: statusColors.background, // Pastel status background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: statusColors.border), // Status border
          ),
          child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => showDialog(context: context, builder: (context) => VesselTracking(vessel: vessel, availablePorts: _availablePorts)),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. LEADING ICON
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: statusColors.text.withValues(alpha: 0.1), // Soft wash of the text color
                                shape: BoxShape.circle
                            ),
                            child: Icon(Icons.directions_boat_filled_rounded, size: 20, color: statusColors.text)
                        ),
                        const SizedBox(width: 16),

                        // 2. MAIN CONTENT (Header + Details)
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // HEADER ROW
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(vessel['vessel_name'] ?? "Unknown", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textPrimary)),
                                            Text(vessel['vessel_type'] ?? 'Passenger Ship', style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildDynamicStatusBadge(displayStatus, statusColors),
                                    ],
                                  ),

                                  // DYNAMIC DETAILS BELOW
                                  if (showRoute && originName.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(destName.isNotEmpty ? "$originName  ➔  $destName" : originName, style: TextStyle(fontSize: 11, color: statusColors.text, fontWeight: FontWeight.w900))
                                  ],

                                  if (statusLower == 'departed' && departedEpoch > 0) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors.white, // Pops out perfectly against the pastel background
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: statusColors.border)
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.event_available_rounded, size: 12, color: statusColors.text),
                                            const SizedBox(width: 4),
                                            Text("Est. Arrival: ${_calculateStaticETA(departedEpoch, travelDuration)}", style: TextStyle(fontSize: 11, color: statusColors.text, fontWeight: FontWeight.w800))
                                          ]
                                      ),
                                    ),
                                  ],

                                  if (isOnboarding) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                                color: Colors.white, // Pops out beautifully against the yellow background
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: statusColors.border)
                                            ),
                                            child: LiveOnboardingCounter(
                                                startTimeEpoch: onboardingEpoch,
                                                durationMinutes: onboardingDuration,
                                                colorTheme: statusColors.text
                                            )
                                        )
                                    )
                                  ],
                                ]
                            )
                        ),
                      ]
                  )
              )
          )
      ),
    );
  }

  Widget _buildEmptyState() {
    bool hasFilters = _searchQuery.isNotEmpty || _selectedStatusFilter != null || _selectedPortFilter != null;
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(hasFilters ? Icons.search_off_rounded : Icons.directions_boat_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)), const SizedBox(height: 16), Text("No vessels found", style: TextStyle(color: primaryDark, fontWeight: FontWeight.w900, fontSize: 18)), Text(hasFilters ? "Try adjusting your filters." : "Directory is empty.", style: TextStyle(color: textSecondary))]));
  }
}

class LiveOnboardingCounter extends StatefulWidget {
  final int startTimeEpoch;
  final int durationMinutes;
  final Color colorTheme; // Added to match the parent status text color
  const LiveOnboardingCounter({super.key, required this.startTimeEpoch, required this.durationMinutes, required this.colorTheme});
  @override State<LiveOnboardingCounter> createState() => _LiveOnboardingCounterState();
}

class _LiveOnboardingCounterState extends State<LiveOnboardingCounter> {
  Timer? _timer; int _remainingSeconds = 0;
  @override void initState() { super.initState(); _calculateTime(); _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTime()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  void _calculateTime() {
    final diff = (widget.startTimeEpoch + (widget.durationMinutes * 60 * 1000)) - DateTime.now().millisecondsSinceEpoch;
    if (diff > 0) { if (mounted) setState(() => _remainingSeconds = diff ~/ 1000); }
    else { if (_remainingSeconds != 0 && mounted) setState(() => _remainingSeconds = 0); _timer?.cancel(); }
  }
  @override
  Widget build(BuildContext context) {
    final bool isOver = _remainingSeconds <= 0;
    final Color textColor = isOver ? Colors.redAccent : widget.colorTheme; // Use dynamic color
    int m = (_remainingSeconds % 3600) ~/ 60; int s = _remainingSeconds % 60;
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(isOver ? Icons.timer_off_outlined : Icons.timer_outlined, size: 12, color: textColor), const SizedBox(width: 4), Text(isOver ? "Waiting for departure" : "Est. Departure in ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textColor))]);
  }
}
