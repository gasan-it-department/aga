import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'VesselTracking.dart';
import '../../Maritime/MaritimeDataMapper.dart';

class MaritimeUserView extends StatefulWidget {
  const MaritimeUserView({super.key});

  @override
  State<MaritimeUserView> createState() => _MaritimeUserViewState();
}

class _MaritimeUserViewState extends State<MaritimeUserView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _vessels = [];
  List<Map<String, dynamic>> _ports = [];
  List<Map<String, dynamic>> _shippingLines = [];

  String _searchQuery = '';
  String? _selectedPortId;
  String? _selectedShippingLineId;
  Timer? _countdownTimer;

  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color bgColor = const Color(0xFFF1F5F9);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color accentBlue = const Color(0xFF2563EB);

  // Operational metrics
  int get _activeVoyagesCount => _vessels
      .where(
        (v) =>
            (v['vessel_status']?['status'] ?? '').toString().toLowerCase() ==
            'departed',
      )
      .length;
  int get _dockedCount => _vessels
      .where(
        (v) => ['docked', 'arrived'].contains(
          (v['vessel_status']?['status'] ?? '').toString().toLowerCase(),
        ),
      )
      .length;
  int get _onboardingCount => _vessels
      .where(
        (v) =>
            (v['vessel_status']?['status'] ?? '').toString().toLowerCase() ==
            'onboarding',
      )
      .length;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _vessels.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _remainingTime(int endEpoch) {
    final remaining = endEpoch - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return "Awaiting status update";
    final totalSeconds = remaining ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) return "${hours}h ${minutes}m ${seconds}s";
    return "${minutes}m ${seconds}s";
  }

  Future<void> _fetchData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        _supabase.from('ports').select().order('port_name'),
        _supabase
            .from('vessels')
            .select(
              '*, shipping_lines(shipping_line_name), vessel_operations(*)',
            )
            .order('vessel_name'),
      ]);

      if (mounted) {
        final vessels = MaritimeDataMapper.normalizeVessels(
          _supabase,
          responses[1],
        ).where((vessel) => vessel['vessel_status'] != null).toList();
        final linesById = <String, Map<String, dynamic>>{};
        for (final vessel in vessels) {
          final id = vessel['shipping_line_id']?.toString();
          final name = vessel['shipping_lines']?['shipping_line_name']
              ?.toString();
          if (id != null && name != null) {
            linesById[id] = {
              'shipping_line_id': id,
              'shipping_line_name': name,
            };
          }
        }
        setState(() {
          _ports = List<Map<String, dynamic>>.from(responses[0] as List);
          _vessels = vessels;
          _shippingLines = linesById.values.toList()
            ..sort(
              (a, b) => a['shipping_line_name'].toString().compareTo(
                b['shipping_line_name'].toString(),
              ),
            );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching maritime data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVessels {
    return _vessels.where((vessel) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final name = (vessel['vessel_name'] ?? '').toString().toLowerCase();
        final type = (vessel['vessel_type'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery.toLowerCase()) &&
            !type.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // Filter by Shipping Line
      if (_selectedShippingLineId != null &&
          vessel['shipping_line_id']?.toString() != _selectedShippingLineId) {
        return false;
      }

      // Filter by Port
      if (_selectedPortId != null) {
        final currentPort = vessel['vessel_current_port']?.toString();
        final dynamic statusData = vessel['vessel_status'];
        String? originPort;
        String? destPort;
        if (statusData is Map) {
          originPort = statusData['origin']?.toString();
          destPort = statusData['destination']?.toString();
        }

        final matchesPort =
            currentPort == _selectedPortId ||
            originPort == _selectedPortId ||
            destPort == _selectedPortId;
        if (!matchesPort) return false;
      }
      return true;
    }).toList();
  }

  String _getPortName(dynamic portId) {
    if (portId == null) return "N/A";
    final port = _ports.firstWhere(
      (p) => p['port_id'].toString() == portId.toString(),
      orElse: () => {},
    );
    return port['port_name']?.toString() ?? "Unknown Port";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "COMMERCIAL PORT CONTROL",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _fetchData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: outlineColor, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          if (!_isLoading) _buildMetricsDashboard(),
          _buildSearchAndFilterBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryDark))
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: primaryDark,
                    child: _filteredVessels.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: _filteredVessels.length,
                            itemBuilder: (context, index) {
                              final vessel = _filteredVessels[index];
                              return _buildVesselCard(vessel);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsDashboard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "MARITIME FLEET STATUS",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  "Voyages",
                  _activeVoyagesCount.toString(),
                  Icons.explore_rounded,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  "Onboarding",
                  _onboardingCount.toString(),
                  Icons.timer_outlined,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  "In Port",
                  _dockedCount.toString(),
                  Icons.anchor_rounded,
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: outlineColor, width: 1)),
      ),
      child: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: TextStyle(
                fontSize: 13,
                color: primaryDark,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: "Search vessel name or type...",
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: outlineColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentBlue, width: 1.5),
                ),
              ),
            ),
          ),
          // Port & Line Dropdowns
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: outlineColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPortId,
                        hint: const Row(
                          children: [
                            Icon(
                              Icons.place_rounded,
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 4),
                            Text(
                              "All Ports",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Color(0xFF64748B),
                        ),
                        isExpanded: true,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F2042),
                          fontWeight: FontWeight.w600,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text("All Ports"),
                          ),
                          ..._ports.map((port) {
                            return DropdownMenuItem<String>(
                              value: port['port_id']?.toString(),
                              child: Text(
                                port['port_name']?.toString() ?? "Port",
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedPortId = val;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: outlineColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedShippingLineId,
                        hint: const Row(
                          children: [
                            Icon(
                              Icons.directions_boat_rounded,
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 4),
                            Text(
                              "All Lines",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Color(0xFF64748B),
                        ),
                        isExpanded: true,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F2042),
                          fontWeight: FontWeight.w600,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text("All Lines"),
                          ),
                          ..._shippingLines.map((line) {
                            return DropdownMenuItem<String>(
                              value: line['shipping_line_id']?.toString(),
                              child: Text(
                                line['shipping_line_name']?.toString() ??
                                    "Line",
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedShippingLineId = val;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVesselCard(Map<String, dynamic> vessel) {
    String displayStatus = "No Schedule";
    String originId = "";
    String destId = "";
    int departed = 0;
    int arrival = 0;
    int onboardingTime = 0;
    int estimatedLatest = 0;
    String passengerLevel = "medium";
    String noScheduleReason = "";
    String dockedState = "docked";

    final dynamic statusData = vessel['vessel_status'];
    if (statusData is Map) {
      displayStatus = (statusData['status'] ?? "Docked").toString().trim();
      originId = statusData['origin']?.toString() ?? "";
      destId = statusData['destination']?.toString() ?? "";
      departed = int.tryParse(statusData['departed']?.toString() ?? "0") ?? 0;
      arrival = int.tryParse(statusData['arrival']?.toString() ?? "0") ?? 0;
      onboardingTime =
          int.tryParse(statusData['onboarding_time']?.toString() ?? "0") ?? 0;
      estimatedLatest =
          int.tryParse(
            statusData['estimated_transition_latest']?.toString() ?? "0",
          ) ??
          0;
      passengerLevel = statusData['passenger_level']?.toString() ?? "medium";
      noScheduleReason = statusData['no_schedule_reason']?.toString() ?? "";
      dockedState = statusData['docked_state']?.toString() ?? "docked";
    } else {
      displayStatus = statusData?.toString().trim() ?? "No Schedule";
    }

    if (originId.isEmpty) {
      originId = vessel['vessel_current_port']?.toString() ?? "";
    }

    final shippingLineName =
        vessel['shipping_lines']?['shipping_line_name'] ??
        'Unknown Shipping Line';
    final originName = _getPortName(originId);
    final destName = _getPortName(destId);
    final vesselType = vessel['vessel_type'] ?? "Ro-Ro Passenger";

    String timeDetail = "";
    double progress = 0.0;
    final statusColor = _getStatusColor(displayStatus);

    if (displayStatus.toLowerCase() == 'departed' && departed > 0) {
      timeDetail = "Departed ${Utility().getEpochTimeAgo(departed)}";
    } else if (displayStatus.toLowerCase() == 'onboarding' &&
        onboardingTime > 0) {
      timeDetail = estimatedLatest > 0
          ? "Departure by ${Utility().formatEpochToTime(estimatedLatest)}"
          : "Boarding now";
    } else if (displayStatus.toLowerCase() == 'docked') {
      if (dockedState == 'preparing' && estimatedLatest > 0) {
        timeDetail = "Preparing: ${_remainingTime(estimatedLatest)}";
      } else if (dockedState == 'tba') {
        timeDetail = "Selected to depart";
      } else {
        timeDetail = "Docked · No timer";
      }
    } else if (displayStatus.toLowerCase() == 'arrived' && arrival > 0) {
      final arrivalTimeStr = Utility().formatEpochToTime(arrival);
      timeDetail = "Docked: $arrivalTimeStr";
    } else if (displayStatus.toLowerCase().replaceAll(' ', '_') ==
        'no_schedule') {
      timeDetail = noScheduleReason.isEmpty ? "Unavailable" : noScheduleReason;
    }
    final passengerLabel = displayStatus.toLowerCase() == 'docked'
        ? "-:-"
        : passengerLevel.replaceAll('_', ' ').toUpperCase();
    timeDetail = timeDetail.isEmpty
        ? passengerLabel
        : "$passengerLabel · $timeDetail";
    final displayLabel =
        displayStatus.toLowerCase() == 'docked' && dockedState != 'docked'
        ? "Docked | ${dockedState == 'tba' ? 'TBA' : 'Preparing'}"
        : displayStatus.replaceAll('_', ' ');

    final isTransit = displayStatus.toLowerCase() == 'departed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VesselTracking(vessel: vessel, availablePorts: _ports),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.directions_boat_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vessel['vessel_name'] ?? "Unknown Vessel",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shippingLineName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          displayLabel.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Route Progress Track Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: isTransit
                      ? _buildRouteTrack(
                          originName,
                          destName,
                          progress,
                          statusColor,
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.anchor_rounded,
                                size: 14,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "PORT STATIONARY",
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  Text(
                                    originName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),

                // Bottom Metadata Info Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.airplane_ticket_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            vesselType,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      if (timeDetail.isNotEmpty)
                        Flexible(
                          child: Text(
                            timeDetail,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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

  Widget _buildRouteTrack(
    String origin,
    String destination,
    double progress,
    Color statusColor,
  ) {
    final double alignmentValue = -1.0 + (progress.clamp(0.0, 1.0) * 2.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ORIGIN PORT",
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    origin,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "DESTINATION PORT",
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: [
            // Track background line
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Progress Fill Line
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Sailing Ship Icon along the track
            Align(
              alignment: Alignment(alignmentValue, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.15),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.directions_boat_rounded,
                  color: statusColor,
                  size: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'docked':
        return const Color(0xFFE11D48);
      case 'departed':
        return const Color(0xFF047857);
      case 'onboarding':
        return const Color(0xFFD97706);
      case 'arrived':
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_boat_outlined,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "No vessels tracked yet.",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
