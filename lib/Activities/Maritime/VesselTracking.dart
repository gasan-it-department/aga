import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:url_launcher/url_launcher.dart';
// Added the new IndicatorColors import
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

  // --- Local State Setter for the StatefulBuilder ---
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
      String status = (statusData['status'] ?? "").toString().trim().toLowerCase();

      if (status == 'onboarding') {
        int startEpoch = int.tryParse(statusData['onboarding_time']?.toString() ?? "0") ?? 0;
        int durationMin = int.tryParse(statusData['onboarding_duration_minutes']?.toString() ?? "0") ?? 0;

        if (startEpoch > 0 && durationMin > 0) {
          _endTimeEpoch = startEpoch + (durationMin * 60 * 1000);
          _startCountdownTimer();
        }
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
      _timeRemaining = "Waiting for departure";
      _countdownTimer?.cancel();
      // Update ONLY the local StatefulBuilder
      _timerStateSetter?.call(() {});
    } else {
      // Calculate total remaining seconds
      int totalSeconds = (diff / 1000).floor();

      // Break down into Hours, Minutes, and Seconds
      int h = totalSeconds ~/ 3600;
      int m = (totalSeconds % 3600) ~/ 60;
      int s = totalSeconds % 60;

      // Conditionally format the string
      if (h > 0) {
        _timeRemaining = "${h}h ${m}m ${s}s";
      } else if (m > 0) {
        _timeRemaining = "${m}m ${s}s";
      } else {
        _timeRemaining = "${s}s";
      }

      // Update ONLY the local StatefulBuilder
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
    final Uri uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
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

  // --- Dynamic Badge Helper using IndicatorColors ---
  Widget _buildDynamicStatusBadge(String status, StatusColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white, // Pure white inside the pastel header to make it pop
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
    // --- Flat Color Palette ---
    const Color bgColor = Colors.white;
    const Color primaryDark = Color(0xFF0A2E5C);
    const Color borderColor = Color(0xFFE5E7EB);
    const Color sectionBgColor = Color(0xFFF9FAFB);
    const Color textPrimary = Color(0xFF111827);
    const Color textSecondary = Color(0xFF6B7280);

    // --- Data Extraction ---
    String vesselName = widget.vessel['vessel_name'] ?? 'Unknown Vessel';
    String displayStatus = "Docked";
    String? proofUrl;

    String originId = "";
    String originName = "N/A";
    String destName = "N/A";

    int departed = 0;
    int arrival = 0;
    int onboardingTime = 0;
    int travelDuration = 170;

    final dynamic statusData = widget.vessel['vessel_status'];
    if (statusData is Map) {
      // Added .trim() for reliable string matching
      displayStatus = (statusData['status'] ?? "Docked").toString().trim();
      originId = statusData['origin']?.toString() ?? "";

      originName = _getPortName(originId);
      destName = _getPortName(statusData['destination']?.toString());
      departed = int.tryParse(statusData['departed']?.toString() ?? "0") ?? 0;
      arrival = int.tryParse(statusData['arrival']?.toString() ?? "0") ?? 0;
      onboardingTime = int.tryParse(statusData['onboarding_time']?.toString() ?? "0") ?? 0;
      travelDuration = int.tryParse(statusData['travel_duration_minutes']?.toString() ?? "170") ?? 170;
      proofUrl = statusData['image_proof']?.toString();
      if (proofUrl != null && proofUrl.isEmpty) proofUrl = null;
    } else {
      displayStatus = statusData?.toString().trim() ?? "Docked";
    }

    if (originId.isEmpty) {
      originId = widget.vessel['vessel_current_port']?.toString() ?? "";
      originName = _getPortName(originId);
    }

    final String statusLower = displayStatus.toLowerCase();
    String departedTime = departed > 0 ? Utility().formatEpochToTime(departed) : "--:--";
    String departedTimeAgo = departed > 0 ? Utility().getEpochTimeAgo(departed) : "";
    String arrivalTime = arrival > 0 ? Utility().formatEpochToTime(arrival) : "--:--";
    String arrivalTimeAgo = arrival > 0 ? Utility().getEpochTimeAgo(arrival) : "";
    String onboardingFormatted = onboardingTime > 0 ? Utility().formatEpochToTime(onboardingTime) : "--:--";
    String onboardingTimeAgo = onboardingTime > 0 ? Utility().getEpochTimeAgo(onboardingTime) : "";

    String etaTime = "--:--";
    if (departed > 0) {
      int etaEpoch = departed + (travelDuration * 60 * 1000);
      etaTime = Utility().formatEpochToTime(etaEpoch);
    }

    double? originLat;
    double? originLng;
    if (originId.isNotEmpty) {
      final portData = widget.availablePorts.firstWhere(
            (p) => p['port_id'].toString() == originId,
        orElse: () => {},
      );

      originLat = double.tryParse(portData['port_latitude']?.toString() ?? portData['latitude']?.toString() ?? '');
      originLng = double.tryParse(portData['port_longitude']?.toString() ?? portData['longitude']?.toString() ?? '');
    }

    // --- FETCH DYNAMIC INDICATOR COLORS ---
    final StatusColors statusColors = IndicatorColors.getColors(displayStatus);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        title: const Text("Vessel Tracking", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
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
                    padding: const EdgeInsets.all(20.0),
                    children: [

                      // --- Pastel Colored Flat Header ---
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: statusColors.background, // Applies the beautiful pastel tint
                          border: Border.all(color: statusColors.border), // Matching border
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColors.text.withValues(alpha: 0.1), // Tinted circle
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.directions_boat, color: statusColors.text), // Matching Icon
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vesselName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Live Vessel Information",
                                    style: TextStyle(fontSize: 13, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            _buildDynamicStatusBadge(displayStatus, statusColors),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- Route Details Flat Container ---
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text("ROUTE DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _buildFlatRow(Icons.my_location, "Current / Origin:", originName, textPrimary),
                            const Divider(height: 1, color: borderColor),
                            _buildFlatRow(Icons.location_on, "Destination:", destName, textPrimary),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- Timestamps Flat Container ---
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text("TIMESTAMPS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (statusLower == 'onboarding' || onboardingTime > 0) ...[
                              // Used IndicatorColors for onboarding to ensure visual sync
                              _buildFlatRow(Icons.group_add, "Onboarding:", onboardingFormatted, IndicatorColors.onboarding.text, subValue: onboardingTimeAgo),
                              const Divider(height: 1, color: borderColor),

                              // --- STATEFUL BUILDER TIMER OPTIMIZATION ---
                              if (statusLower == 'onboarding' && _endTimeEpoch > 0) ...[
                                StatefulBuilder(
                                    builder: (BuildContext context, StateSetter setLocalState) {
                                      _timerStateSetter = setLocalState;

                                      return _buildFlatRow(
                                          Icons.timer_outlined,
                                          "Est. Departure:",
                                          _timeRemaining,
                                          IndicatorColors.onboarding.text
                                      );
                                    }
                                ),
                                const Divider(height: 1, color: borderColor),
                              ]
                            ],

                            // Kept hardcoded timeline colors since timeline logic assumes blue = departed, green = arrived
                            _buildFlatRow(Icons.logout, "Departed:", departedTime, Colors.blue.shade700, subValue: departedTimeAgo),

                            if (statusLower == 'departed') ...[
                              const Divider(height: 1, color: borderColor),
                              _buildFlatRow(Icons.event_available, "Estimated Arrival:", etaTime, Colors.blue.shade700),
                            ] else if (statusLower == 'arrived' || arrival > 0) ...[
                              const Divider(height: 1, color: borderColor),
                              _buildFlatRow(Icons.login, "Arrived:", arrivalTime, Colors.green.shade700, subValue: arrivalTimeAgo),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- Image Proof Flat Container ---
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text("LATEST LIVE PROOF", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
                      ),
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: sectionBgColor,
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: proofUrl != null
                            ? Image.network(
                          proofUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildImageError(),
                        )
                            : _buildImageError(message: "No proof image uploaded"),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // --- STICKY BOTTOM BUTTON (Directions) ---
                if (statusLower == 'onboarding' && originLat != null && originLng != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    decoration: const BoxDecoration(
                      color: bgColor,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    width: double.infinity,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchDirections(originLat!, originLng!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.directions_car_rounded, size: 20),
                        label: const Text(
                            "Get Directions to Port",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
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

  // --- Flat UI Helpers ---

  Widget _buildFlatRow(IconData icon, String label, String value, Color valueColor, {String? subValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
              if (subValue != null && subValue.isNotEmpty)
                Text(subValue, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageError({String message = "Failed to load image"}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.image_not_supported, size: 32, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      ],
    );
  }
}
