import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/VesselStatus.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../Dialogs/ClassicDialog.dart';
import '../../../Maritime/MaritimeActivityLogger.dart';
import '../../ImageCapture.dart';

class UpdateVesselStatus extends StatefulWidget {
  final String vesselId;
  final String vesselName;
  final String? currentStatus;
  final String? originId;
  final String? destinationId;
  final int? onboardingDuration;
  final String? dockedState;

  const UpdateVesselStatus({
    super.key,
    required this.vesselId,
    required this.vesselName,
    this.currentStatus,
    this.originId,
    this.destinationId,
    this.onboardingDuration,
    this.dockedState,
  });

  @override
  State<UpdateVesselStatus> createState() => _UpdateVesselStatusState();
}

class _UpdateVesselStatusState extends State<UpdateVesselStatus> {
  final supabase = Supabase.instance.client;

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final _classicDialog = ClassicDialog();
  final _imagePicker = ImagePicker();

  XFile? _finalCapturedImage;

  // Flow control
  String _currentStatus = 'Docked';
  String _selectedStatus = 'Onboarding';
  bool _overrideMode = false;

  String? _currentPortId;
  String? _originPortId;
  String? _destinationPortId;

  final TextEditingController _noScheduleReasonController =
      TextEditingController();
  final TextEditingController _statusNoteController = TextEditingController();
  final TextEditingController _timerMinutesController = TextEditingController();
  String _weatherCondition = 'moderate';
  String _passengerLevel = 'medium';
  String _dockedState = 'docked';
  double _timerMinutes = 45;

  List<Map<String, dynamic>> _availablePorts = [];
  bool _isLoadingPorts = true;
  bool _isUploading = false;

  final DateTime _currentTime = DateTime.now();

  SharedPreferences? _preferences;
  static const List<String> _statusFlow = [
    'Docked',
    'Onboarding',
    'Departed',
    'Arrived',
  ];

  @override
  void initState() {
    super.initState();

    _currentStatus = _statusLabel(widget.currentStatus ?? 'docked');
    _dockedState = widget.dockedState ?? 'docked';
    final month = DateTime.now().month;
    if (month == 11 || month == 12) {
      _passengerLevel = 'heavy';
    } else if (month == 9) {
      _passengerLevel = 'medium';
    }

    // Normalize status casing
    _determineNextStatus();
    _resetTimerForStatus();

    _initPrefs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPorts();
    });
  }

  void _determineNextStatus() {
    if (_statusCode(_currentStatus) == 'no_schedule') {
      _selectedStatus = 'Docked';
      return;
    }
    final currentStepIndex = _flowIndexForStatus(_currentStatus);
    final nextStepIndex = (currentStepIndex + 1) % _statusFlow.length;
    _selectedStatus = _statusFlow[nextStepIndex];
  }

  int _flowIndexForStatus(String status) {
    final statusLower = _statusCode(status);
    if (statusLower == 'docked') return 0;
    final index = _statusFlow.indexWhere(
      (step) => step.toLowerCase() == statusLower,
    );
    return index < 0 ? 0 : index;
  }

  String _statusCode(String status) {
    return status.toLowerCase().trim().replaceAll(' ', '_');
  }

  String _statusLabel(String status) {
    return _statusCode(status)
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _currentStatusLabel() {
    if (_statusCode(_currentStatus) == 'docked' && _dockedState != 'docked') {
      return 'Docked | ${_dockedState == 'tba' ? 'TBA' : 'Preparing'}';
    }
    return _currentStatus;
  }

  ({double minimum, double maximum, double initial}) _timerSettings() {
    switch (_statusCode(_selectedStatus)) {
      case 'docked':
        return (minimum: 30, maximum: 60, initial: 45);
      case 'onboarding':
        return (minimum: 60, maximum: 120, initial: 90);
      case 'departed':
        final initial = switch (_weatherCondition) {
          'good' => 165.0,
          'rough' => 210.0,
          _ => 185.0,
        };
        return (minimum: 165, maximum: 210, initial: initial);
      default:
        return (minimum: 0, maximum: 0, initial: 0);
    }
  }

  void _resetTimerForStatus() {
    final settings = _timerSettings();
    _timerMinutes = settings.initial;
    _timerMinutesController.text = _timerMinutes.round().toString();
  }

  void _setTimerMinutes(double value) {
    final settings = _timerSettings();
    final adjusted = value.clamp(settings.minimum, settings.maximum);
    setState(() {
      _timerMinutes = adjusted;
      _timerMinutesController.text = adjusted.round().toString();
    });
  }

  void _validateTimerInput() {
    final value = double.tryParse(_timerMinutesController.text.trim());
    _setTimerMinutes(value ?? _timerSettings().initial);
  }

  Future<void> _initPrefs() async {
    _preferences = await SharedPreferences.getInstance();
  }

  Future<void> _fetchPorts() async {
    try {
      final response = await supabase
          .from('ports')
          .select('port_id, port_name')
          .order('port_name');
      if (mounted) {
        setState(() {
          _availablePorts = List<Map<String, dynamic>>.from(response);
          _isLoadingPorts = false;

          final List<String> allPortIds = _availablePorts
              .map((p) => p['port_id'].toString())
              .toList();

          // Set up defaults based on current status and parameters
          if (widget.originId != null && allPortIds.contains(widget.originId)) {
            _originPortId = widget.originId;
            _currentPortId = widget.originId;
          }
          if (widget.destinationId != null &&
              allPortIds.contains(widget.destinationId)) {
            _destinationPortId = widget.destinationId;
          }

          // If transitioning from Departed to Docked, destinationPortId becomes the new docked location
          if (['departed', 'arrived'].contains(_statusCode(_currentStatus)) &&
              _destinationPortId != null) {
            _currentPortId = _destinationPortId;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching ports: $e");
      if (mounted) setState(() => _isLoadingPorts = false);
    }
  }

  @override
  void dispose() {
    _noScheduleReasonController.dispose();
    _statusNoteController.dispose();
    _timerMinutesController.dispose();
    super.dispose();
  }

  String _getFormattedDate() {
    List<String> months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${months[_currentTime.month - 1]} ${_currentTime.day}, ${_currentTime.year}";
  }

  String _getFormattedTime() {
    int hour = _currentTime.hour;
    String minute = _currentTime.minute.toString().padLeft(2, '0');
    String second = _currentTime.second.toString().padLeft(2, '0');
    String period = hour >= 12 ? "PM" : "AM";
    if (hour == 0) hour = 12;
    if (hour > 12) hour -= 12;
    return "$hour:$minute:$second $period";
  }

  String _getPortName(String? portId) {
    if (portId == null) return "Unknown";
    final port = _availablePorts.firstWhere(
      (p) => p['port_id'].toString() == portId,
      orElse: () => {'port_name': 'Unknown'},
    );
    return port['port_name'];
  }

  void _showClassicDialog(
    String title,
    String message, {
    VoidCallback? onClose,
  }) {
    _classicDialog.setTitle(title);
    _classicDialog.setMessage(message);
    _classicDialog.setCancelable(false);
    _classicDialog.setPositiveMessage("Close");
    if (mounted) {
      _classicDialog.showOnButtonDialog(context, () {
        _classicDialog.dismissDialog();
        if (mounted) if (onClose != null) onClose();
      });
    }
  }

  Future<void> _pickProofImage() async {
    if (_isUploading) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty && mounted) {
        final XFile? captured = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ImageCaptureScreen()),
        );
        if (captured != null && mounted) {
          setState(() => _finalCapturedImage = captured);
          return;
        }
      }
    } catch (error) {
      debugPrint('Camera unavailable, opening gallery: $error');
    }

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _finalCapturedImage = picked);
      }
    } catch (error) {
      debugPrint('Gallery picker failed: $error');
      if (mounted) {
        _showClassicDialog(
          'Image Required',
          'Could not open the camera or gallery. Please try again.',
        );
      }
    }
  }

  Future<void> _submitStatusUpdate() async {
    final String statusLower = _statusCode(_selectedStatus);
    final bool isRouteStatus =
        statusLower == 'departed' ||
        statusLower == 'arrived' ||
        statusLower == 'onboarding';

    if (['docked', 'onboarding', 'departed'].contains(statusLower)) {
      _validateTimerInput();
    }

    if (_finalCapturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please capture a photo proof first!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (isRouteStatus) {
      if (_originPortId == null || _destinationPortId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select both Origin and Destination ports."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } else {
      if (_currentPortId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select a Current Location port."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    if (statusLower == 'no_schedule' &&
        _noScheduleReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("A reason is required when there is no schedule."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'An authenticated administrator is required.';

      final vesselData = await supabase
          .from('vessels')
          .select('shipping_line_id, vessel_operations(*)')
          .eq('vessel_id', widget.vesselId)
          .single();
      final operations = List<Map<String, dynamic>>.from(
        vesselData['vessel_operations'] as List? ?? const [],
      );
      final activeOperations = operations
          .where((item) => item['completed_at'] == null)
          .toList();
      final activeOperation = activeOperations.isEmpty
          ? null
          : activeOperations.first;

      Map<String, dynamic>? routeProfile;
      if (_originPortId != null && _destinationPortId != null) {
        routeProfile = await supabase
            .from('shipping_line_route_profiles')
            .select()
            .eq('shipping_line_id', vesselData['shipping_line_id'])
            .eq('origin_port_id', _originPortId!)
            .eq('destination_port_id', _destinationPortId!)
            .eq('is_active', true)
            .limit(1)
            .maybeSingle();
      }

      int routeMinutes(String key, int fallback) {
        return int.tryParse(routeProfile?[key]?.toString() ?? '') ?? fallback;
      }

      final String fileExt = _finalCapturedImage!.name.split('.').last;
      final now = DateTime.now().toUtc();
      final String fileName =
          '${widget.vesselId}/${now.millisecondsSinceEpoch}.$fileExt';
      final Uint8List fileBytes = await _finalCapturedImage!.readAsBytes();

      await supabase.storage
          .from('vessel-status-proofs')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: false),
          );

      String? trueOrigin = isRouteStatus ? _originPortId : _currentPortId;
      String? trueDestination = isRouteStatus ? _destinationPortId : null;
      String? currentPort = statusLower == 'arrived'
          ? _destinationPortId
          : trueOrigin;

      DateTime? earliest;
      DateTime? latest;
      DateTime? boardingCloses;
      if ((statusLower == 'docked' && _dockedState == 'preparing') ||
          statusLower == 'onboarding') {
        earliest = now.add(Duration(minutes: _timerMinutes.round()));
        latest = earliest;
      }
      if (statusLower == 'onboarding') {
        boardingCloses = latest!.subtract(
          Duration(minutes: routeMinutes('boarding_close_buffer_minutes', 15)),
        );
      } else if (statusLower == 'departed') {
        earliest = now.add(Duration(minutes: _timerMinutes.round()));
        latest = earliest;
      }

      final payload = <String, dynamic>{
        'vessel_id': widget.vesselId,
        'route_profile_id': routeProfile?['profile_id'],
        'origin_port_id': trueOrigin,
        'destination_port_id': trueDestination,
        'current_port_id': currentPort,
        'status': statusLower,
        'docked_state': statusLower == 'docked' ? _dockedState : null,
        'status_started_at': now.toIso8601String(),
        'estimated_transition_earliest_at': earliest?.toIso8601String(),
        'estimated_transition_latest_at': latest?.toIso8601String(),
        'boarding_closes_at': boardingCloses?.toIso8601String(),
        'actual_departed_at': statusLower == 'departed'
            ? now.toIso8601String()
            : activeOperation?['actual_departed_at'],
        'actual_arrived_at': statusLower == 'arrived'
            ? now.toIso8601String()
            : null,
        'no_schedule_reason': statusLower == 'no_schedule'
            ? _noScheduleReasonController.text.trim()
            : null,
        'status_note': _statusNoteController.text.trim().isEmpty
            ? null
            : _statusNoteController.text.trim(),
        'weather_condition': statusLower == 'departed'
            ? _weatherCondition
            : null,
        'passenger_level': _passengerLevel,
        'passenger_level_source': 'manual',
        'proof_image_path': fileName,
        'proof_uploaded_at': now.toIso8601String(),
        'proof_uploaded_by': userId,
        'last_confirmed_at': now.toIso8601String(),
        'updated_by': userId,
      };

      Map<String, dynamic> savedOperation;
      if (activeOperation == null) {
        savedOperation = Map<String, dynamic>.from(
          await supabase
              .from('vessel_operations')
              .insert(payload)
              .select()
              .single(),
        );
      } else {
        savedOperation = Map<String, dynamic>.from(
          await supabase
              .from('vessel_operations')
              .update(payload)
              .eq('operation_id', activeOperation['operation_id'])
              .select()
              .single(),
        );
      }

      await supabase.from('vessel_status_history').insert({
        'operation_id': savedOperation['operation_id'],
        'vessel_id': widget.vesselId,
        'previous_status': activeOperation?['status'],
        'new_status': statusLower,
        'docked_state': statusLower == 'docked' ? _dockedState : null,
        'origin_port_id': trueOrigin,
        'destination_port_id': trueDestination,
        'current_port_id': currentPort,
        'status_started_at': now.toIso8601String(),
        'estimate_earliest_at': earliest?.toIso8601String(),
        'estimate_latest_at': latest?.toIso8601String(),
        'boarding_closes_at': boardingCloses?.toIso8601String(),
        'reason': statusLower == 'no_schedule'
            ? _noScheduleReasonController.text.trim()
            : null,
        'weather_condition': statusLower == 'departed'
            ? _weatherCondition
            : null,
        'passenger_level': _passengerLevel,
        'passenger_level_source': 'manual',
        'proof_image_path': fileName,
        'proof_uploaded_at': now.toIso8601String(),
        'proof_uploaded_by': userId,
        'changed_by': userId,
      });

      String userName = _preferences?.getString("user_name") ?? "An Admin";
      String assignedPort =
          _preferences?.getString("assigned_port") ?? "Unknown Port";
      String vesselNameUpper = widget.vesselName.toUpperCase();
      String statusUpper = _selectedStatus.toUpperCase();

      await MaritimeActivityLogger.createLog(
        title: "Vessel Status Updated",
        message:
            "$vesselNameUpper status updated to $statusUpper by [$assignedPort] - $userName.",
        creatorId: userId,
      );

      setState(() => _isUploading = false);

      _showClassicDialog(
        "Success!",
        "Vessel status updated successfully.",
        onClose: () => Navigator.pop(context),
      );
    } catch (e) {
      debugPrint("Upload Error: $e");
      setState(() => _isUploading = false);
      _showClassicDialog(
        "Update Failed",
        "An error occurred while saving the status.\n\n$e",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String statusLower = _statusCode(_selectedStatus);
    final bool isRouteStatus =
        statusLower == 'departed' ||
        statusLower == 'arrived' ||
        statusLower == 'onboarding';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Update Status"),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vessel Header Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.directions_boat_rounded,
                            color: primaryDark,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.vesselName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ),
                      Row(
                        children: [
                          const Text(
                            "Current Status: ",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                _currentStatus,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _currentStatusLabel().toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(_currentStatus),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (!_overrideMode) ...[
                  _buildAdminFlowCard(),
                  const SizedBox(height: 20),
                ],

                const Text(
                  "2. PHOTO PROOF",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _isUploading ? null : _pickProofImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _finalCapturedImage == null
                          ? Colors.white
                          : Colors.black,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _finalCapturedImage == null
                            ? accentBlue.withValues(alpha: 0.5)
                            : outlineColor,
                        width: _finalCapturedImage == null ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _finalCapturedImage != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                kIsWeb
                                    ? Image.network(
                                        _finalCapturedImage!.path,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_finalCapturedImage!.path),
                                        fit: BoxFit.cover,
                                      ),
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "Change Photo",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_rounded,
                                  size: 48,
                                  color: accentBlue.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Tap to capture live proof",
                                  style: TextStyle(
                                    color: accentBlue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Offstage(
                  offstage: true,
                  child: StatefulBuilder(
                    builder: (context, stateSetter) {
                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: outlineColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 14,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "CURRENT DATE",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getFormattedDate(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: outlineColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_filled_rounded,
                                        size: 14,
                                        color: Color(0xFF10B981),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "LOCAL TIME",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getFormattedTime(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox.shrink(),

                if (_overrideMode) ...[
                  const Text(
                    "OVERRIDE VESSEL STATUS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFEF4444),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedStatus,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFFEF4444),
                        ),
                        items: VesselStatus().statusList.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7F1D1D),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: _isUploading
                            ? null
                            : (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedStatus = newValue;
                                    _resetTimerForStatus();
                                  });
                                }
                              },
                      ),
                    ),
                  ),
                  _buildFlowStepper(),
                  const SizedBox(height: 24),
                ],

                if ((statusLower == 'docked' && _dockedState == 'preparing') ||
                    statusLower == 'onboarding' ||
                    statusLower == 'departed') ...[
                  _buildTimerEditor(),
                  const SizedBox(height: 24),
                ],

                if (statusLower == 'departed') ...[
                  _buildChoiceDropdown(
                    "WEATHER CONDITION",
                    _weatherCondition,
                    const {
                      'good': 'Good',
                      'moderate': 'Moderate',
                      'rough': 'Rough',
                    },
                    (value) {
                      setState(() {
                        _weatherCondition = value;
                        _resetTimerForStatus();
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                _buildChoiceDropdown(
                  "PASSENGER LEVEL",
                  _passengerLevel,
                  const {
                    'light': 'Light',
                    'medium': 'Medium',
                    'heavy': 'Heavy',
                    'very_heavy': 'Very Heavy',
                  },
                  (value) => setState(() => _passengerLevel = value),
                ),
                const SizedBox(height: 24),

                if (statusLower == 'no_schedule') ...[
                  _buildTextInput(
                    "NO SCHEDULE REASON",
                    _noScheduleReasonController,
                    "Typhoon, maintenance, port closure, or another reason",
                  ),
                  const SizedBox(height: 24),
                ],

                if (isRouteStatus) ...[
                  const Text(
                    "ROUTE INFORMATION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // If transitioning to Departed or Docked from an existing route, origin port can be locked
                  _buildPortDropdown(
                    "Origin",
                    _originPortId,
                    (_currentStatus.toLowerCase() == 'onboarding' ||
                                _currentStatus.toLowerCase() == 'departed') &&
                            !_overrideMode
                        ? null
                        : (val) => setState(() => _originPortId = val),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      color: Color(0xFFCBD5E1),
                      size: 20,
                    ),
                  ),
                  _buildPortDropdown(
                    "Destination",
                    _destinationPortId,
                    _currentStatus.toLowerCase() == 'departed' && !_overrideMode
                        ? null
                        : (val) => setState(() => _destinationPortId = val),
                  ),
                ] else ...[
                  const Text(
                    "CURRENT LOCATION (PORT)",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPortDropdown(
                    "Select Port",
                    _currentPortId,
                    (val) => setState(() => _currentPortId = val),
                  ),
                ],

                const SizedBox(height: 24),

                _buildTextInput(
                  "STATUS NOTE",
                  _statusNoteController,
                  "Optional operational note",
                ),

                const SizedBox(height: 24),

                if (isRouteStatus &&
                    _originPortId != null &&
                    _destinationPortId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Builder(
                      builder: (context) {
                        String summaryText = "";
                        if (statusLower == 'arrived' ||
                            statusLower == 'docked') {
                          summaryText =
                              "Arrived at ${_getPortName(_destinationPortId).toUpperCase()} from ${_getPortName(_originPortId).toUpperCase()}";
                        } else if (statusLower == 'departed') {
                          summaryText =
                              "Departing from ${_getPortName(_originPortId).toUpperCase()} to ${_getPortName(_destinationPortId).toUpperCase()}";
                        } else if (statusLower == 'onboarding') {
                          summaryText =
                              "Onboarding at ${_getPortName(_originPortId).toUpperCase()} bound for ${_getPortName(_destinationPortId).toUpperCase()}";
                        }
                        return Text(
                          summaryText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: accentBlue,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _overrideMode
                          ? const Color(0xFFEF4444)
                          : accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isUploading ? null : _submitStatusUpdate,
                    child: _isUploading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            _submitButtonLabel(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Reset/Override option
                Center(
                  child: TextButton.icon(
                    icon: Icon(
                      _overrideMode
                          ? Icons.check_circle_outline_rounded
                          : Icons.warning_amber_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _overrideMode
                          ? "Back to Flow Sequence"
                          : "More status options",
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _overrideMode
                          ? accentBlue
                          : textSecondary,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _overrideMode = !_overrideMode;
                        if (_overrideMode) {
                          _selectedStatus = _currentStatus;
                        } else {
                          _determineNextStatus();
                        }
                        _resetTimerForStatus();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlowStepper() {
    final steps = _statusFlow;
    final currentStepIndex = _flowIndexForStatus(_currentStatus);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "FLOW PROGRESSION",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "STEP ${currentStepIndex + 1} OF ${steps.length}",
                  style: const TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (index) {
            final isPassed = index < currentStepIndex;
            final isCurrent = index == currentStepIndex;
            final isNext = index == currentStepIndex + 1;
            final isLast = index == steps.length - 1;

            Color stepColor = const Color(0xFFCBD5E1);
            String desc = "";
            if (index == 0) {
              desc =
                  "Vessel is docked. Ready for cargo, vehicle and passenger loading.";
            } else if (index == 1) {
              desc =
                  "Passengers onboarding. Recording duration and boarding metrics.";
            } else if (index == 2) {
              desc = "Vessel has left the port. En route to destination.";
            } else if (index == 3) {
              desc =
                  "Vessel has reached its destination and completed the route.";
            }

            if (isCurrent) {
              stepColor = accentBlue;
            } else if (isPassed) {
              stepColor = const Color(0xFF10B981);
            } else if (isNext) {
              stepColor = const Color(0xFF64748B);
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline column
                  Column(
                    children: [
                      // Bubble
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? stepColor
                              : (isPassed
                                    ? const Color(0xFFE8F5E9)
                                    : Colors.white),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: stepColor,
                            width: isCurrent ? 3 : 2,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: stepColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isPassed
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Color(0xFF10B981),
                                )
                              : Text(
                                  (index + 1).toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: isCurrent ? Colors.white : stepColor,
                                  ),
                                ),
                        ),
                      ),
                      // Connector line
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2.5,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isPassed
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Content column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              steps[index],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w900
                                    : FontWeight.bold,
                                color: isCurrent
                                    ? primaryDark
                                    : (isPassed
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFF94A3B8)),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: accentBlue.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  "ACTIVE",
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: accentBlue,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isCurrent
                                ? const Color(0xFF334155)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        if (!isLast) const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _submitButtonLabel() {
    final status = _statusCode(_selectedStatus);
    if (status == 'docked') {
      if (_dockedState == 'tba') return 'Save Docked | TBA';
      if (_dockedState == 'preparing') return 'Save Docked | Preparing';
      return 'Save Docked';
    }
    return 'Update to $_selectedStatus';
  }

  Widget _buildAdminFlowCard() {
    final currentStatus = _statusCode(_currentStatus);
    final selectedStatus = _statusCode(_selectedStatus);
    final showDockedActions =
        currentStatus == 'docked' || selectedStatus == 'docked';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. CHOOSE ACTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (showDockedActions) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  {
                    'docked': 'Docked',
                    'tba': 'Docked | TBA',
                    'preparing': 'Docked | Preparing',
                  }.entries.map((entry) {
                    final selected =
                        selectedStatus == 'docked' && _dockedState == entry.key;
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: selected,
                      onSelected: _isUploading
                          ? null
                          : (_) {
                              setState(() {
                                _overrideMode = false;
                                _selectedStatus = 'Docked';
                                _dockedState = entry.key;
                                _resetTimerForStatus();
                              });
                            },
                    );
                  }).toList(),
            ),
            if (currentStatus == 'docked') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () {
                          setState(() {
                            _overrideMode = false;
                            _selectedStatus = 'Onboarding';
                            _resetTimerForStatus();
                          });
                        },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Continue to Onboarding'),
                ),
              ),
            ],
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _currentStatus,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: textSecondary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: accentBlue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedStatus,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: accentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortDropdown(
    String hint,
    String? currentValue,
    ValueChanged<String?>? onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: onChanged == null ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
      ),
      child: _isLoadingPorts
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                "Loading...",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: currentValue,
                disabledHint: Text(
                  currentValue != null ? _getPortName(currentValue) : hint,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryDark.withValues(alpha: 0.6),
                  ),
                ),
                hint: Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                icon: Icon(
                  Icons.location_on_rounded,
                  color: onChanged == null
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF0A2E5C),
                  size: 18,
                ),
                items: _availablePorts.map((port) {
                  return DropdownMenuItem<String>(
                    value: port['port_id'].toString(),
                    child: Text(
                      port['port_name'].toString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _isUploading ? null : onChanged,
              ),
            ),
    );
  }

  Widget _buildChoiceDropdown(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outlineColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: choices.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isUploading
                  ? null
                  : (selected) {
                      if (selected != null) onChanged(selected);
                    },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerEditor() {
    final settings = _timerSettings();
    final status = _statusCode(_selectedStatus);
    final label = status == 'docked'
        ? 'DOCK PREPARATION AND FUELING TIME'
        : status == 'onboarding'
        ? 'TIME UNTIL DEPARTURE'
        : 'ESTIMATED TRAVEL TIME';
    final expectedTime = DateTime.now().add(
      Duration(minutes: _timerMinutes.round()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outlineColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _timerMinutes,
                      min: settings.minimum,
                      max: settings.maximum,
                      divisions: (settings.maximum - settings.minimum).round(),
                      label: '${_timerMinutes.round()} min',
                      onChanged: _isUploading ? null : _setTimerMinutes,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: TextField(
                      controller: _timerMinutesController,
                      enabled: !_isUploading,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null &&
                            parsed >= settings.minimum &&
                            parsed <= settings.maximum) {
                          setState(() => _timerMinutes = parsed);
                        }
                      },
                      onEditingComplete: _validateTimerInput,
                      onSubmitted: (_) => _validateTimerInput(),
                      decoration: InputDecoration(
                        suffixText: 'min',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${settings.minimum.round()} min',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                    Text(
                      'Expected ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(expectedTime))}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accentBlue,
                      ),
                    ),
                    Text(
                      '${settings.maximum.round()} min',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          enabled: !_isUploading,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: outlineColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: outlineColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (_statusCode(status)) {
      case 'docked':
        return Colors.red;
      case 'departed':
        return Colors.green;
      case 'onboarding':
        return Colors.orange;
      case 'arrived':
        return Colors.blue;
      case 'no_schedule':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
