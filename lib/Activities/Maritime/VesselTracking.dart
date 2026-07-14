import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gasan_port_tracker/Colors/IndicatorColors.dart';

class VesselTracking extends StatefulWidget {
  final Map<String, dynamic> vessel;
  final List<Map<String, dynamic>> availablePorts;

  const VesselTracking({
    super.key,
    required this.vessel,
    required this.availablePorts,
  });

  @override
  State<VesselTracking> createState() => _VesselTrackingState();
}

class _VesselTrackingState extends State<VesselTracking> {
  Timer? _countdownTimer;
  int _endTimeEpoch = 0;
  String _timeRemaining = "Calculating...";
  String _timerPurpose = "Next update";

  StateSetter? _timerStateSetter;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _initializeTimer() {
    final dynamic statusData = widget.vessel['vessel_status'];
    if (statusData is Map) {
      String status = (statusData['status'] ?? "")
          .toString()
          .trim()
          .toLowerCase();

      if (['docked', 'onboarding'].contains(status)) {
        _endTimeEpoch =
            int.tryParse(
              statusData['estimated_transition_latest']?.toString() ?? "0",
            ) ??
            0;
        _timerPurpose = status == 'docked' ? 'Preparing' : 'Est. Departure';
        if (_endTimeEpoch > 0) _startCountdownTimer();
      }
    }
  }

  void _startCountdownTimer() {
    _updateTimeText();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeText();
    });
  }

  void _updateTimeText() {
    int now = DateTime.now().millisecondsSinceEpoch;
    int diff = _endTimeEpoch - now;

    if (diff <= 0) {
      _timeRemaining = "Awaiting confirmation";
      _countdownTimer?.cancel();
      _timerStateSetter?.call(() {});
    } else {
      int totalSeconds = (diff / 1000).floor();
      int h = totalSeconds ~/ 3600;
      int m = (totalSeconds % 3600) ~/ 60;
      int s = totalSeconds % 60;

      if (h > 0) {
        _timeRemaining = "${h}h ${m}m ${s}s";
      } else if (m > 0) {
        _timeRemaining = "${m}m ${s}s";
      } else {
        _timeRemaining = "${s}s";
      }

      _timerStateSetter?.call(() {});
    }
  }

  String _getPortName(String? portId) {
    if (portId == null || portId.isEmpty) return "--:--";
    final port = widget.availablePorts.firstWhere(
      (p) => p['port_id'].toString() == portId.toString(),
      orElse: () => {'port_name': 'Unknown Port'},
    );
    return port['port_name'].toString();
  }

  Future<void> _launchDirections(double lat, double lng) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch Google Maps");
      }
    } catch (e) {
      debugPrint("Error launching Maps: $e");
    }
  }

  Widget _buildDynamicStatusBadge(String status, StatusColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
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
    const Color bgColor = Color(0xFFF8FAFC);
    const Color primaryDark = Color(0xFF0A2E5C);
    const Color borderColor = Color(0xFFE5E7EB);
    const Color sectionBgColor = Color(0xFFF9FAFB);
    const Color textPrimary = Color(0xFF111827);
    const Color textSecondary = Color(0xFF6B7280);

    String vesselName = widget.vessel['vessel_name'] ?? 'Unknown Vessel';
    String displayStatus = "No Schedule";
    String? proofUrl;

    String originId = "";
    String originName = "N/A";
    String destName = "N/A";

    int departed = 0;
    int arrival = 0;
    int onboardingTime = 0;
    String noScheduleReason = "";
    String dockedState = "docked";
    int lastConfirmedAt = 0;

    final dynamic statusData = widget.vessel['vessel_status'];
    if (statusData is Map) {
      displayStatus = (statusData['status'] ?? "Docked").toString().trim();
      originId = statusData['origin']?.toString() ?? "";

      originName = _getPortName(originId);
      destName = _getPortName(statusData['destination']?.toString());
      departed = int.tryParse(statusData['departed']?.toString() ?? "0") ?? 0;
      arrival = int.tryParse(statusData['arrival']?.toString() ?? "0") ?? 0;
      onboardingTime =
          int.tryParse(statusData['onboarding_time']?.toString() ?? "0") ?? 0;
      proofUrl = statusData['image_proof']?.toString();
      noScheduleReason = statusData['no_schedule_reason']?.toString() ?? "";
      dockedState = statusData['docked_state']?.toString() ?? "docked";
      lastConfirmedAt =
          int.tryParse(statusData['last_confirmed_at']?.toString() ?? "0") ?? 0;
      if (proofUrl != null && proofUrl.isEmpty) proofUrl = null;
    } else {
      displayStatus = statusData?.toString().trim() ?? "No Schedule";
    }

    if (originId.isEmpty) {
      originId = widget.vessel['vessel_current_port']?.toString() ?? "";
      originName = _getPortName(originId);
    }

    final String statusLower = displayStatus.toLowerCase();
    final displayLabel = displayStatus.replaceAll('_', ' ');
    final dockedLabel = statusLower == 'docked' && dockedState != 'docked'
        ? (dockedState == 'tba' ? 'TBA' : 'Preparing')
        : null;
    String departedTime = departed > 0
        ? Utility().formatEpochToTime(departed)
        : "--:--";
    String departedTimeAgo = departed > 0
        ? Utility().getEpochTimeAgo(departed)
        : "";
    String arrivalTime = arrival > 0
        ? Utility().formatEpochToTime(arrival)
        : "--:--";
    String arrivalTimeAgo = arrival > 0
        ? Utility().getEpochTimeAgo(arrival)
        : "";
    String onboardingFormatted = onboardingTime > 0
        ? Utility().formatEpochToTime(onboardingTime)
        : "--:--";
    String onboardingTimeAgo = onboardingTime > 0
        ? Utility().getEpochTimeAgo(onboardingTime)
        : "";

    double? originLat;
    double? originLng;
    if (originId.isNotEmpty) {
      final portData = widget.availablePorts.firstWhere(
        (p) => p['port_id'].toString() == originId,
        orElse: () => {},
      );

      originLat = double.tryParse(
        portData['port_latitude']?.toString() ??
            portData['latitude']?.toString() ??
            '',
      );
      originLng = double.tryParse(
        portData['port_longitude']?.toString() ??
            portData['longitude']?.toString() ??
            '',
      );
    }

    final StatusColors statusColors = IndicatorColors.getColors(displayStatus);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        title: const Text(
          "Vessel Tracking",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                    children: [
                      _buildHeroCard(
                        vesselName,
                        displayLabel,
                        dockedLabel,
                        statusColors,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        "Route Details",
                        Icons.route_rounded,
                        primaryDark,
                        borderColor,
                        [
                          _buildDetailTile(
                            Icons.my_location_rounded,
                            "Current / Origin",
                            originName,
                            textPrimary,
                          ),
                          _buildDetailTile(
                            Icons.location_on_rounded,
                            "Destination",
                            destName,
                            textPrimary,
                          ),
                          if (noScheduleReason.isNotEmpty)
                            _buildDetailTile(
                              Icons.info_outline_rounded,
                              "Reason",
                              noScheduleReason,
                              IndicatorColors.maintenance.text,
                            ),
                          if (lastConfirmedAt > 0)
                            _buildDetailTile(
                              Icons.verified_outlined,
                              "Last Confirmed",
                              Utility().getEpochTimeAgo(lastConfirmedAt),
                              textSecondary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        "Timeline",
                        Icons.schedule_rounded,
                        primaryDark,
                        borderColor,
                        [
                          if (_endTimeEpoch > 0)
                            StatefulBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    StateSetter setLocalState,
                                  ) {
                                    _timerStateSetter = setLocalState;
                                    return _buildDetailTile(
                                      Icons.timer_outlined,
                                      _timerPurpose,
                                      _timeRemaining,
                                      statusColors.text,
                                    );
                                  },
                            ),
                          if (statusLower == 'onboarding' || onboardingTime > 0)
                            _buildDetailTile(
                              Icons.group_add_rounded,
                              "Onboarding",
                              onboardingFormatted,
                              IndicatorColors.onboarding.text,
                              subValue: onboardingTimeAgo,
                            ),
                          if (statusLower == 'departed' ||
                              statusLower == 'arrived')
                            _buildDetailTile(
                              Icons.logout_rounded,
                              "Departed",
                              departedTime,
                              IndicatorColors.departed.text,
                              subValue: departedTimeAgo,
                            ),
                          if (statusLower == 'arrived' || arrival > 0)
                            _buildDetailTile(
                              Icons.login_rounded,
                              "Arrived",
                              arrivalTime,
                              IndicatorColors.arrival.text,
                              subValue: arrivalTimeAgo,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        "Latest Live Proof",
                        Icons.image_rounded,
                        primaryDark,
                        borderColor,
                        [
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: sectionBgColor,
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: proofUrl != null
                                ? Image.network(
                                    proofUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildImageError(),
                                  )
                                : _buildImageError(
                                    message: "No proof image uploaded",
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (statusLower == 'onboarding' &&
                    originLat != null &&
                    originLng != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    width: double.infinity,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _launchDirections(originLat!, originLng!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.directions_car_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          "Get Directions to Port",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    String vesselName,
    String displayLabel,
    String? dockedLabel,
    StatusColors statusColors,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColors.border),
        boxShadow: [
          BoxShadow(
            color: statusColors.text.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: statusColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColors.border),
            ),
            child: Icon(
              Icons.directions_boat_filled_rounded,
              color: statusColors.text,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vesselName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Live vessel information",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _buildDynamicStatusBadge(displayLabel, statusColors),
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
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color primaryDark,
    Color borderColor,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryDark, size: 19),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: primaryDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            _buildDetailTile(
              Icons.info_outline_rounded,
              "Status",
              "No timeline available",
              const Color(0xFF6B7280),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _buildDetailTile(
    IconData icon,
    String label,
    String value,
    Color valueColor, {
    String? subValue,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: valueColor, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                  ),
                ),
                if (subValue != null && subValue.isNotEmpty)
                  Text(
                    subValue,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

  Widget _buildImageError({String message = "Failed to load image"}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.image_not_supported,
          size: 32,
          color: Color(0xFF9CA3AF),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      ],
    );
  }
}
