import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Colors/IndicatorColors.dart';
import 'SubActivities/UpdateVesselStatus.dart';
import '../../Maritime/MaritimeDataMapper.dart';

class VesselStatusUpdater extends StatefulWidget {
  const VesselStatusUpdater({super.key});

  @override
  State<VesselStatusUpdater> createState() => _VesselStatusUpdaterState();
}

class _VesselStatusUpdaterState extends State<VesselStatusUpdater> {
  final supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);

  List<Map<String, dynamic>> _vessels = [];
  List<Map<String, dynamic>> _shippingLines = [];
  List<Map<String, dynamic>> _portsList = [];
  final Map<String, String> _portsMap = {};

  bool _isLoading = true;

  String _searchQuery = '';
  String? _selectedShippingLineId;
  String? _selectedPortId;
  String? _assignedPortId;
  String? _assignedPortName;
  bool _showAllPorts = false;

  Timer? _debounce;
  Timer? _countdownTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _vessels.isNotEmpty) {
        setState(() {});
      }
    });
  }

  Future<void> _initializeData() async {
    await _loadAssignedPort();
    await _fetchPorts();
    await _fetchShippingLines();
    _fetchVessels();
  }

  Future<void> _loadAssignedPort() async {
    final prefs = await SharedPreferences.getInstance();
    _assignedPortId = prefs.getString('assigned_port_id');
    _assignedPortName = prefs.getString('assigned_port');
    if ((_assignedPortId ?? '').trim().isNotEmpty) {
      _selectedPortId = _assignedPortId!.trim();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
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

  Future<void> _fetchPorts() async {
    try {
      final response = await _fetchAssignedPorts();
      if (mounted) {
        setState(() {
          _portsList = List<Map<String, dynamic>>.from(response);
          _portsMap
            ..clear()
            ..addEntries(
              _portsList.map(
                (port) =>
                    MapEntry(_portKey(port['port_id']), _portDisplayName(port)),
              ),
            );
          final availableIds = _portsList
              .map((port) => _portKey(port['port_id']))
              .where((id) => id.isNotEmpty)
              .toSet();

          // Resolve the assigned port against the complete ports list. Access
          // data may contain either the port ID or the display name.
          Map<String, dynamic>? assignedPort;
          if ((_assignedPortId ?? '').trim().isNotEmpty) {
            for (final port in _portsList) {
              if (_portKey(port['port_id']) == _assignedPortId!.trim()) {
                assignedPort = port;
                break;
              }
            }
          }
          if (assignedPort == null &&
              (_assignedPortName ?? '').trim().isNotEmpty) {
            final assignedName = _normalizePortName(_assignedPortName!);
            for (final port in _portsList) {
              if (_normalizePortName(_portDisplayName(port)) == assignedName) {
                assignedPort = port;
                break;
              }
            }
          }
          if (assignedPort != null) {
            _assignedPortId = _portKey(assignedPort['port_id']);
            _assignedPortName = _portDisplayName(assignedPort);
            _selectedPortId = _assignedPortId;
            _showAllPorts = false;
          } else if (!availableIds.contains(_selectedPortId)) {
            _selectedPortId = null;
            _showAllPorts = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching ports: $e");
    }
  }

  Future<List<dynamic>> _fetchAssignedPorts() async {
    // Load every port first. The user's access data is only used to choose
    // the initial filter, not to restrict the available port options.
    return await supabase
        .from('ports')
        .select('port_id, port_name')
        .order('port_name');
  }

  String _normalizePortName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _portKey(dynamic value) => value?.toString().trim() ?? '';

  String _portDisplayName(Map<String, dynamic> port) {
    final name = port['port_name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Unnamed Port' : name;
  }

  Future<void> _fetchShippingLines() async {
    try {
      final response = await supabase
          .from('shipping_lines')
          .select('shipping_line_id, shipping_line_name')
          .order('shipping_line_name');
      if (mounted) {
        setState(() {
          _shippingLines = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint("Error fetching shipping lines: $e");
    }
  }

  Future<void> _fetchVessels() async {
    setState(() {
      _isLoading = true;
      _vessels.clear();
    });

    try {
      var query = supabase
          .from('vessels')
          .select(
            '*, shipping_lines(shipping_line_name), vessel_operations(*)',
          );

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('vessel_name', '%$_searchQuery%');
      }
      if (_selectedShippingLineId != null) {
        query = query.eq('shipping_line_id', _selectedShippingLineId!);
      }
      final response = await query.order('vessel_name', ascending: true);
      final normalized = MaritimeDataMapper.normalizeVessels(
        supabase,
        response,
      );
      final activePortFilter = _showAllPorts
          ? null
          : _selectedPortId?.trim().isNotEmpty == true
          ? _selectedPortId!.trim()
          : ((_assignedPortId ?? '').trim().isNotEmpty
                ? _assignedPortId!.trim()
                : null);
      final filtered = activePortFilter == null
          ? normalized
          : normalized.where((vessel) {
              final status = vessel['vessel_status'];
              return vessel['vessel_current_port']?.toString() ==
                      activePortFilter ||
                  status?['origin']?.toString() == activePortFilter ||
                  status?['destination']?.toString() == activePortFilter;
            }).toList();

      if (mounted) {
        setState(() {
          _vessels = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching vessels: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != value) {
        setState(() => _searchQuery = value);
        _fetchVessels();
      }
    });
  }

  void _onLineFilterChanged(String? newValue) {
    setState(() => _selectedShippingLineId = newValue);
    _fetchVessels();
  }

  void _onPortFilterChanged(String? newValue) {
    setState(() {
      _selectedPortId = newValue;
      _showAllPorts = newValue == null;
    });
    _fetchVessels();
  }

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

  void _showProofImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          size: 48,
                          color: textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Image could not be loaded",
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Vessel Status Updater"),
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
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: outlineColor)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // --- SEARCH BAR ---
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(
                        fontSize: 14,
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search vessel name...",
                        hintStyle: TextStyle(
                          color: textSecondary.withValues(alpha: 0.6),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: textSecondary,
                        ),
                        filled: true,
                        fillColor: bgColor,
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

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: outlineColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedShippingLineId,
                                hint: Text(
                                  "Lines",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.business_rounded,
                                  size: 16,
                                  color: textSecondary,
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      "All Lines",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: primaryDark,
                                      ),
                                    ),
                                  ),
                                  ..._shippingLines.map(
                                    (line) => DropdownMenuItem(
                                      value: line['shipping_line_id']
                                          .toString(),
                                      child: Text(
                                        line['shipping_line_name'].toString(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: primaryDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: _onLineFilterChanged,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: outlineColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedPortId,
                                hint: Text(
                                  "Ports",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.anchor_rounded,
                                  size: 16,
                                  color: textSecondary,
                                ),
                                items: [
                                  if (!_isAssignedPortLocked)
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        "All Ports",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: primaryDark,
                                        ),
                                      ),
                                    ),
                                  ..._portsList.map(
                                    (port) => DropdownMenuItem(
                                      value: port['port_id'].toString(),
                                      child: Text(
                                        port['port_name'].toString(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: primaryDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: _isAssignedPortLocked
                                    ? null
                                    : _onPortFilterChanged,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: accentBlue),
                      )
                    : _vessels.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _fetchVessels(),
                        color: accentBlue,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.all(16),
                          itemCount: _vessels.length,
                          itemBuilder: (context, index) {
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

  bool get _isAssignedPortLocked => false;

  Widget _buildDynamicStatusBadge(String status, StatusColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
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

  Widget _buildVesselCard(Map<String, dynamic> vessel) {
    String vesselName = vessel['vessel_name'] ?? 'Unknown Vessel';
    String vesselId = vessel['vessel_id'] ?? 'null';
    String lineName =
        vessel['shipping_lines']?['shipping_line_name'] ??
        'Unknown Shipping Line';

    String displayStatus = "No Schedule";
    String? proofUrl;

    String? passOriginId;
    String? passDestId;
    int? passOnboardingDuration;
    String dockedState = 'docked';

    final dynamic statusData = vessel['vessel_status'];
    if (statusData is Map) {
      displayStatus = (statusData['status'] ?? "no_schedule").toString().trim();
      proofUrl = statusData['image_proof']?.toString();
      if (proofUrl != null && proofUrl.isEmpty) proofUrl = null;

      passOriginId = statusData['origin']?.toString();
      passDestId = statusData['destination']?.toString();
      passOnboardingDuration = int.tryParse(
        statusData['onboarding_duration_minutes']?.toString() ?? "0",
      );
      dockedState = statusData['docked_state']?.toString() ?? 'docked';
    } else {
      displayStatus = statusData?.toString().trim() ?? "No Schedule";
    }

    passOriginId ??= vessel['vessel_current_port']?.toString();

    final StatusColors statusColors = IndicatorColors.getColors(displayStatus);
    final displayLabel =
        displayStatus.toLowerCase() == 'docked' && dockedState != 'docked'
        ? "Docked | ${dockedState == 'tba' ? 'TBA' : 'Preparing'}"
        : displayStatus.replaceAll('_', ' ');

    final bool isDockedOrMaintenance = [
      'no_schedule',
      'no schedule',
    ].contains(displayStatus.toLowerCase());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: statusColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColors.border),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vesselName,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lineName,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildDynamicStatusBadge(
                        displayLabel,
                        statusColors,
                      ),
                    ),
                  ],
                ),

                // --- CONDITIONAL DETAILS BOX ---
                if (!isDockedOrMaintenance) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColors.border),
                    ),
                    child: _buildDetailedStatus(
                      statusData,
                      displayStatus,
                      statusColors,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(height: 1, color: statusColors.border),

          Container(
            decoration: const BoxDecoration(
              color: Colors.white, // Bottom action row stays white
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (proofUrl != null) {
                        _showProofImage(proofUrl);
                      } else {
                        _classicDialog.setTitle("No Image Available");
                        _classicDialog.setMessage(
                          "There is no image proof yet.",
                        );
                        _classicDialog.setCancelable(false);
                        _classicDialog.setPositiveMessage("Close");
                        _classicDialog.showOnButtonDialog(context, () {
                          _classicDialog.dismissDialog();
                        });
                      }
                    },
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            proofUrl != null
                                ? Icons.image_search_rounded
                                : Icons.hide_image_rounded,
                            size: 18,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Image Proof",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(width: 1, height: 24, color: outlineColor),

                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UpdateVesselStatus(
                            vesselId: vesselId,
                            vesselName: vesselName,
                            currentStatus: displayStatus,
                            originId: passOriginId,
                            destinationId: passDestId,
                            onboardingDuration: passOnboardingDuration,
                            dockedState: dockedState,
                          ),
                        ),
                      );
                      _fetchVessels();
                    },
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 18,
                            color: accentBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Update Status",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: accentBlue,
                            ),
                          ),
                        ],
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

  // --- Passed statusColors to properly theme the inner details ---
  Widget _buildDetailedStatus(
    dynamic statusData,
    String statusLabel,
    StatusColors statusColors,
  ) {
    if (statusData == null || statusData is! Map) {
      return _buildInfoRow(
        Icons.help_outline,
        "No recent route data",
        color: textSecondary,
      );
    }

    String status = statusLabel.toLowerCase();
    String originId = statusData['origin']?.toString() ?? '';
    String destId = statusData['destination']?.toString() ?? '';

    int departed = int.tryParse(statusData['departed']?.toString() ?? '0') ?? 0;
    int arrival = int.tryParse(statusData['arrival']?.toString() ?? '0') ?? 0;
    int onboarding =
        int.tryParse(statusData['onboarding_time']?.toString() ?? '0') ?? 0;
    int estimatedLatest =
        int.tryParse(
          statusData['estimated_transition_latest']?.toString() ?? '0',
        ) ??
        0;
    String dockedState = statusData['docked_state']?.toString() ?? 'docked';

    String originName = _portsMap[originId] ?? 'Unknown Port';
    String destName = _portsMap[destId] ?? 'Unknown Port';

    if (['docked', 'departed', 'arrived', 'onboarding'].contains(status)) {
      List<Widget> children = [
        _buildInfoRow(
          status == 'docked' ? Icons.anchor_rounded : Icons.route_rounded,
          status == 'docked' ? originName : "$originName  →  $destName",
          color: textPrimary,
        ),
      ];

      if (status == 'docked') {
        children.addAll([
          const SizedBox(height: 4),
          _buildInfoRow(
            Icons.local_gas_station_rounded,
            dockedState == 'preparing' && estimatedLatest > 0
                ? "Preparing: ${_remainingTime(estimatedLatest)}"
                : dockedState == 'tba'
                ? "Selected to depart"
                : "Docked · No timer",
            color: statusColors.text,
          ),
        ]);
      } else if (status == 'departed') {
        children.addAll([
          const SizedBox(height: 4),
          _buildInfoRow(
            Icons.logout_rounded,
            "Departed at: ${_formatTime(departed)}",
            color: statusColors.text,
          ),
        ]);
      } else if (status == 'arrived') {
        children.addAll([
          const SizedBox(height: 4),
          _buildInfoRow(
            Icons.login_rounded,
            "Arrived at: ${_formatTime(arrival)}",
            color: statusColors.text,
          ),
        ]);
      } else if (status == 'onboarding') {
        children.addAll([
          const SizedBox(height: 4),
          _buildInfoRow(
            Icons.timer_outlined,
            "Onboarding at: ${_formatTime(onboarding)}",
            color: statusColors.text,
          ),
        ]);
      } else if (status == 'standby') {
        children.addAll([
          const SizedBox(height: 4),
          _buildInfoRow(
            Icons.access_time_rounded,
            "Awaiting departure",
            color: statusColors.text,
          ),
        ]);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    // Default fallback in case a weird status slips through
    return const SizedBox.shrink();
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color ?? textSecondary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: outlineColor.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No vessels found",
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isAssignedPortLocked
                ? "No vessels are linked to your assigned port."
                : "Try adjusting your search or filter.",
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
