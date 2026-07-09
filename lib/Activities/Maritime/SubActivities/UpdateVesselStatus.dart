import 'dart:async';
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

  const UpdateVesselStatus({
    super.key,
    required this.vesselId,
    required this.vesselName,
    this.currentStatus,
    this.originId,
    this.destinationId,
    this.onboardingDuration,
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
  StateSetter? _dateAndTimeStateSetter;

  // Flow control
  String _currentStatus = 'Docked';
  String _selectedStatus = 'Onboarding';
  bool _overrideMode = false;

  String? _currentPortId;
  String? _originPortId;
  String? _destinationPortId;

  final TextEditingController _onboardingDurationController =
      TextEditingController();

  List<Map<String, dynamic>> _availablePorts = [];
  bool _isLoadingPorts = true;
  bool _isUploading = false;

  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;

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

    _currentStatus = widget.currentStatus ?? 'Docked';

    // Normalize status casing
    if (_currentStatus.isNotEmpty) {
      _currentStatus =
          _currentStatus[0].toUpperCase() +
          _currentStatus.substring(1).toLowerCase();
    }

    // Determine the next step in the flow automatically
    _determineNextStatus();

    if (widget.onboardingDuration != null && widget.onboardingDuration! > 0) {
      _onboardingDurationController.text = widget.onboardingDuration.toString();
    }

    _initPrefs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPorts();
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          _dateAndTimeStateSetter?.call(() {
            _currentTime = DateTime.now();
          });
        }
      });
    });
  }

  void _determineNextStatus() {
    final currentStepIndex = _flowIndexForStatus(_currentStatus);
    final nextStepIndex = (currentStepIndex + 1) % _statusFlow.length;
    _selectedStatus = _statusFlow[nextStepIndex];
  }

  int _flowIndexForStatus(String status) {
    final statusLower = status.toLowerCase().trim();
    if (statusLower == 'docked') return 0;
    final index = _statusFlow.indexWhere(
      (step) => step.toLowerCase() == statusLower,
    );
    return index < 0 ? 0 : index;
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
          if (_currentStatus.toLowerCase() == 'departed' &&
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
    _clockTimer?.cancel();
    _onboardingDurationController.dispose();
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
    final String statusLower = _selectedStatus.toLowerCase();
    final bool isRouteStatus =
        statusLower == 'departed' ||
        statusLower == 'arrived' ||
        statusLower == 'onboarding';
    final bool isOnboarding = statusLower == 'onboarding';
    final bool isStandby = statusLower == 'standby';

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
    } else if (isStandby) {
      if (_currentPortId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select a Current Location port."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_destinationPortId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select a Destination port for standby."),
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

    if (isOnboarding) {
      final String durationText = _onboardingDurationController.text.trim();
      if (durationText.isEmpty ||
          int.tryParse(durationText) == null ||
          int.parse(durationText) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please enter a valid onboarding duration in minutes.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isUploading = true);

    try {
      final vesselData = await supabase
          .from('vessels')
          .select('vessel_status')
          .eq('vessel_id', widget.vesselId)
          .single();

      String? oldImageUrl;
      if (vesselData['vessel_status'] != null) {
        final dynamic statusData = vesselData['vessel_status'];
        if (statusData is Map && statusData['image_proof'] != null) {
          oldImageUrl = statusData['image_proof'].toString();
        }
      }

      const String bucketName = 'images';
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          Uri uri = Uri.parse(oldImageUrl);
          String pathToRemove = uri.pathSegments.last;
          await supabase.storage.from(bucketName).remove([pathToRemove]);
          debugPrint("Old image deleted: $pathToRemove");
        } catch (e) {
          debugPrint("Failed to delete old image, continuing upload... $e");
        }
      }

      final String fileExt = _finalCapturedImage!.name.split('.').last;
      final String fileName =
          '${widget.vesselId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final Uint8List fileBytes = await _finalCapturedImage!.readAsBytes();

      await supabase.storage
          .from(bucketName)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String newImageUrl = supabase.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      int nowEpoch = DateTime.now().millisecondsSinceEpoch;
      int departedEpoch = 0;
      int arrivalEpoch = 0;

      if (statusLower == 'departed') {
        departedEpoch = nowEpoch;
      }
      if (statusLower == 'docked' || statusLower == 'arrived') {
        arrivalEpoch = nowEpoch;
      }

      int onboardingDurationMins = 0;
      if (isOnboarding) {
        onboardingDurationMins =
            int.tryParse(_onboardingDurationController.text.trim()) ?? 0;
      }

      String? trueOrigin = isRouteStatus ? _originPortId : _currentPortId;
      String? trueDestination = (isRouteStatus || isStandby)
          ? _destinationPortId
          : null;

      // When arrived, destination becomes the new starting origin, and destination is reset to null
      if (statusLower == 'arrived' || statusLower == 'docked') {
        trueOrigin = _destinationPortId ?? _originPortId ?? _currentPortId;
        trueDestination = null;
      }

      Map<String, dynamic> statusUpdateJson = {
        "origin": trueOrigin,
        "destination": trueDestination,
        "status": _selectedStatus,
        "departed": departedEpoch,
        "onboarding_time": isOnboarding ? Utility().getCurrentMSEpochTime() : 0,
        "onboarding_duration_minutes": onboardingDurationMins,
        "arrival": arrivalEpoch,
        "image_proof": newImageUrl,
      };

      // Construct update query
      Map<String, dynamic> updatePayload = {'vessel_status': statusUpdateJson};

      // Set vessel_current_port column on the database table to synchronize filter queries
      if (trueOrigin != null) {
        updatePayload['vessel_current_port'] = trueOrigin;
      }

      await supabase
          .from('vessels')
          .update(updatePayload)
          .eq('vessel_id', widget.vesselId);

      String userName = _preferences?.getString("user_name") ?? "An Admin";
      String assignedPort =
          _preferences?.getString("assigned_port") ?? "Unknown Port";
      String userId = _preferences?.getString("user_id") ?? "unknown_user_id";
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
    final String statusLower = _selectedStatus.toLowerCase();
    final bool isRouteStatus =
        statusLower == 'departed' ||
        statusLower == 'arrived' ||
        statusLower == 'onboarding';
    final bool isOnboarding = statusLower == 'onboarding';
    final bool isStandby = statusLower == 'standby';

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
                              _currentStatus.toUpperCase(),
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

                // Flow Stepper Header
                if (!_overrideMode) ...[
                  _buildFlowStepper(),
                  const SizedBox(height: 20),
                ],

                const Text(
                  "LIVE PROOF (PHOTO)",
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

                StatefulBuilder(
                  builder: (context, stateSetter) {
                    _dateAndTimeStateSetter = stateSetter;
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
                const SizedBox(height: 24),

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
                                    if (newValue.toLowerCase() !=
                                        'onboarding') {
                                      _onboardingDurationController.clear();
                                    }
                                  });
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Show next step action label
                  Text(
                    "UPDATING STATUS TO: ${_selectedStatus.toUpperCase()}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: accentBlue,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (isOnboarding) ...[
                  const Text(
                    "ESTIMATED ONBOARDING DURATION (MINUTES)",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _onboardingDurationController,
                    keyboardType: TextInputType.number,
                    enabled: !_isUploading,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: "e.g. 45",
                      hintStyle: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: const Icon(
                        Icons.timer_outlined,
                        color: Color(0xFF64748B),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
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
                ] else if (isStandby) ...[
                  const Text(
                    "STANDBY INFORMATION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPortDropdown(
                    "Current Location",
                    _currentPortId,
                    (val) => setState(() => _currentPortId = val),
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
                    "Next Destination",
                    _destinationPortId,
                    (val) => setState(() => _destinationPortId = val),
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
                            _overrideMode
                                ? "Force Override Status"
                                : "Set as $_selectedStatus",
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
                          : "Manual Override / Reset Status",
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _overrideMode
                          ? accentBlue
                          : const Color(0xFFEF4444),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'docked':
      case 'arrived':
        return Colors.teal;
      case 'departed':
        return Colors.blue;
      case 'onboarding':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
