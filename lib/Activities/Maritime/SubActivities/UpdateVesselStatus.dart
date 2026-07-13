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
  String _currentDockedState = 'docked';
  String _dockedState = 'docked';
  double _timerMinutes = 45;

  List<Map<String, dynamic>> _availablePorts = [];
  bool _isLoadingPorts = true;
  bool _isUploading = false;

  final DateTime _currentTime = DateTime.now();

  SharedPreferences? _preferences;
  @override
  void initState() {
    super.initState();

    _currentStatus = _statusLabel(widget.currentStatus ?? 'docked');
    _currentDockedState = widget.dockedState ?? 'docked';
    _dockedState = _currentDockedState;
    final month = DateTime.now().month;
    if (month == 11 || month == 12) {
      _passengerLevel = 'heavy';
    } else if (month == 9) {
      _passengerLevel = 'medium';
    }

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
      _dockedState = 'docked';
      return;
    }
    if (_statusCode(_currentStatus) == 'docked') {
      if (_currentDockedState == 'docked') {
        _selectedStatus = 'Docked';
        _dockedState = 'tba';
      } else if (_currentDockedState == 'tba') {
        _selectedStatus = 'Docked';
        _dockedState = 'preparing';
      } else {
        _selectedStatus = 'Onboarding';
        _dockedState = 'docked';
      }
      return;
    }
    if (_statusCode(_currentStatus) == 'onboarding') {
      _selectedStatus = 'Departed';
      return;
    }
    _selectedStatus = 'Docked';
    _dockedState = 'docked';
  }

  void _useAutomaticNextStatus() {
    setState(() {
      _overrideMode = false;
      _determineNextStatus();
      _resetTimerForStatus();
    });
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
    return _currentStatus;
  }

  String _nextStatusLabel() {
    return _selectedStatus;
  }

  String? _currentDockedStateLabel() {
    if (_statusCode(_currentStatus) != 'docked' ||
        _currentDockedState == 'docked') {
      return null;
    }
    return _currentDockedState == 'tba' ? 'TBA' : 'Preparing';
  }

  String? _nextDockedStateLabel() {
    if (_statusCode(_selectedStatus) != 'docked' || _dockedState == 'docked') {
      return null;
    }
    return _dockedState == 'tba' ? 'TBA' : 'Preparing';
  }

  ({double minimum, double maximum, double initial}) _timerSettings() {
    switch (_statusCode(_selectedStatus)) {
      case 'docked':
        return (minimum: 30, maximum: 60, initial: 45);
      case 'onboarding':
        return (minimum: 60, maximum: 120, initial: 90);
      default:
        return (minimum: 0, maximum: 0, initial: 0);
    }
  }

  void _resetTimerForStatus() {
    final settings = _timerSettings();
    final savedTimer = _preferences?.getInt(_timerPreferenceKey());
    _timerMinutes = (savedTimer?.toDouble() ?? settings.initial).clamp(
      settings.minimum,
      settings.maximum,
    );
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

  Future<void> _deleteProofImage(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      await supabase.storage.from('vessel-status-proofs').remove([path]);
    } catch (error) {
      debugPrint('Proof cleanup skipped: $error');
    }
  }

  Future<void> _initPrefs() async {
    _preferences = await SharedPreferences.getInstance();
    _loadSavedStatusDefaults();
  }

  String _timerPreferenceKey() {
    final status = _statusCode(_selectedStatus);
    if (status == 'docked' && _dockedState == 'preparing') {
      return 'maritime_timer_docked_preparing';
    }
    return 'maritime_timer_$status';
  }

  void _loadSavedStatusDefaults() {
    final savedPassenger = _preferences?.getString('maritime_passenger_level');
    final savedTimer = _preferences?.getInt(_timerPreferenceKey());
    final allowedPassengerLevels = {'light', 'medium', 'heavy', 'very_heavy'};
    if (!mounted) return;
    setState(() {
      if (savedPassenger != null &&
          allowedPassengerLevels.contains(savedPassenger)) {
        _passengerLevel = savedPassenger;
      }
      if (savedTimer != null) {
        final settings = _timerSettings();
        final adjusted = savedTimer.toDouble().clamp(
          settings.minimum,
          settings.maximum,
        );
        _timerMinutes = adjusted;
        _timerMinutesController.text = adjusted.round().toString();
      }
    });
  }

  Future<void> _saveStatusDefaults() async {
    await _preferences?.setString('maritime_passenger_level', _passengerLevel);
    final status = _statusCode(_selectedStatus);
    final shouldSaveTimer =
        (status == 'docked' && _dockedState == 'preparing') ||
        status == 'onboarding';
    if (shouldSaveTimer) {
      await _preferences?.setInt(_timerPreferenceKey(), _timerMinutes.round());
    }
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

          if (widget.originId != null && allPortIds.contains(widget.originId)) {
            _originPortId = widget.originId;
            _currentPortId = widget.originId;
          }
          if (widget.destinationId != null &&
              allPortIds.contains(widget.destinationId)) {
            _destinationPortId = widget.destinationId;
          }

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

    if (['docked', 'onboarding'].contains(statusLower)) {
      _validateTimerInput();
    }

    final bool requiresProofImage = statusLower != 'docked';

    if (requiresProofImage && _finalCapturedImage == null) {
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
    String? uploadedProofPath;

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

      final now = DateTime.now().toUtc();
      String? fileName;
      if (_finalCapturedImage != null) {
        final String fileExt = _finalCapturedImage!.name.split('.').last;
        fileName = '${widget.vesselId}/${now.millisecondsSinceEpoch}.$fileExt';
        final Uint8List fileBytes = await _finalCapturedImage!.readAsBytes();

        await supabase.storage
            .from('vessel-status-proofs')
            .uploadBinary(
              fileName,
              fileBytes,
              fileOptions: const FileOptions(upsert: false),
            );
        uploadedProofPath = fileName;
      }

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
        final minutes = routeMinutes(
          '${_weatherCondition}_weather_minutes',
          {'good': 165, 'moderate': 185, 'rough': 210}[_weatherCondition]!,
        );
        earliest = now.add(Duration(minutes: minutes));
        latest = earliest;
      }

      String? departedAtValue;
      if (statusLower == 'departed') {
        departedAtValue = now.toIso8601String();
      } else if (statusLower == 'arrived') {
        departedAtValue = activeOperation?['actual_departed_at']?.toString();
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
        'actual_departed_at': departedAtValue,
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
        'proof_uploaded_at': fileName == null ? null : now.toIso8601String(),
        'proof_uploaded_by': fileName == null ? null : userId,
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
        'proof_uploaded_at': fileName == null ? null : now.toIso8601String(),
        'proof_uploaded_by': fileName == null ? null : userId,
        'changed_by': userId,
      });

      final oldProofPath = activeOperation?['proof_image_path']?.toString();
      if (fileName != null && oldProofPath != fileName) {
        await _deleteProofImage(oldProofPath);
      }
      await _saveStatusDefaults();

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
      await _deleteProofImage(uploadedProofPath);
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
                _buildVesselHeaderCard(),
                const SizedBox(height: 16),
                _buildAdminFlowCard(),
                const SizedBox(height: 16),
                if (_overrideMode) ...[
                  _buildOverridePanel(statusLower),
                  const SizedBox(height: 16),
                ],
                _buildPhotoProofCard(),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: "Operation Details",
                  icon: Icons.fact_check_rounded,
                  children: [
                    if ((statusLower == 'docked' &&
                            _dockedState == 'preparing') ||
                        statusLower == 'onboarding') ...[
                      _buildTimerEditor(),
                      const SizedBox(height: 18),
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
                      const SizedBox(height: 18),
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
                      (value) {
                        setState(() => _passengerLevel = value);
                        _preferences?.setString(
                          'maritime_passenger_level',
                          value,
                        );
                      },
                    ),
                    if (statusLower == 'no_schedule') ...[
                      const SizedBox(height: 18),
                      _buildTextInput(
                        "NO SCHEDULE REASON",
                        _noScheduleReasonController,
                        "Typhoon, maintenance, port closure, or another reason",
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: isRouteStatus ? "Route" : "Current Location",
                  icon: isRouteStatus
                      ? Icons.route_rounded
                      : Icons.anchor_rounded,
                  children: [
                    if (isRouteStatus) ...[
                      _buildPortDropdown(
                        "Origin",
                        _originPortId,
                        (_currentStatus.toLowerCase() == 'onboarding' ||
                                    _currentStatus.toLowerCase() ==
                                        'departed') &&
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
                        _currentStatus.toLowerCase() == 'departed' &&
                                !_overrideMode
                            ? null
                            : (val) => setState(() => _destinationPortId = val),
                      ),
                    ] else ...[
                      _buildPortDropdown(
                        "Select Port",
                        _currentPortId,
                        (val) => setState(() => _currentPortId = val),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (isRouteStatus &&
                    _originPortId != null &&
                    _destinationPortId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildRouteSummary(statusLower),
                  ),
                _buildSectionCard(
                  title: "Note",
                  icon: Icons.edit_note_rounded,
                  children: [
                    _buildTextInput(
                      "STATUS NOTE",
                      _statusNoteController,
                      "Optional operational note",
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
              ],
            ),
          ),
        ),
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

  Widget _buildVesselHeaderCard() {
    final statusColor = _getStatusColor(_currentStatus);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primaryDark,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.directions_boat_filled_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.vesselName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildStatusPill(
                      _currentStatusLabel(),
                      statusColor,
                      backgroundColor: Colors.white,
                    ),
                    if (_currentDockedStateLabel() != null)
                      _buildStatusPill(
                        _currentDockedStateLabel()!,
                        const Color(0xFF64748B),
                        backgroundColor: Colors.white,
                      ),
                    Text(
                      "${_getFormattedDate()} • ${_getFormattedTime()}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
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

  Widget _buildAdminFlowCard() {
    final nextColor = _overrideMode ? const Color(0xFFEF4444) : accentBlue;
    final modeLabel = _overrideMode ? "MANUAL" : "AUTO";
    final modeColor = _overrideMode ? const Color(0xFFEF4444) : accentBlue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: outlineColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _overrideMode ? Icons.tune_rounded : Icons.auto_mode_rounded,
                  color: modeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _overrideMode ? "Manual Status Change" : "Next Status",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _buildStatusPill(modeLabel, modeColor),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isUploading
                    ? null
                    : () {
                        if (_overrideMode) {
                          _useAutomaticNextStatus();
                        } else {
                          setState(() {
                            _overrideMode = true;
                            _selectedStatus = _currentStatus;
                            _dockedState = _currentDockedState;
                            _resetTimerForStatus();
                          });
                        }
                      },
                icon: Icon(
                  _overrideMode ? Icons.auto_mode_rounded : Icons.tune_rounded,
                  size: 16,
                ),
                label: Text(_overrideMode ? 'Auto' : 'Override'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: modeColor,
                  side: BorderSide(color: modeColor.withValues(alpha: 0.28)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final currentBlock = _buildStatusBlock(
                "CURRENT",
                _currentStatusLabel(),
                _getStatusColor(_currentStatus),
                subBadge: _currentDockedStateLabel(),
              );
              final nextBlock = _buildStatusBlock(
                _overrideMode ? "TARGET" : "NEXT",
                _nextStatusLabel(),
                nextColor,
                subBadge: _nextDockedStateLabel(),
              );
              final arrow = Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: nextColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNarrow
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.arrow_forward_rounded,
                  color: nextColor,
                  size: 20,
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    currentBlock,
                    const SizedBox(height: 10),
                    arrow,
                    const SizedBox(height: 10),
                    nextBlock,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: currentBlock),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: arrow,
                  ),
                  Expanded(child: nextBlock),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverridePanel(String statusLower) {
    return _buildSectionCard(
      title: "Manual Override",
      icon: Icons.tune_rounded,
      toneColor: const Color(0xFFEF4444),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
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
                      fontWeight: FontWeight.w900,
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
                          if (_statusCode(newValue) != 'docked') {
                            _dockedState = 'docked';
                          }
                          _resetTimerForStatus();
                        });
                      }
                    },
            ),
          ),
        ),
        if (statusLower == 'docked') ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                {
                  'docked': 'Docked',
                  'tba': 'Docked | TBA',
                  'preparing': 'Docked | Preparing',
                }.entries.map((entry) {
                  final selected = _dockedState == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    selectedColor: const Color(0xFFFEE2E2),
                    checkmarkColor: const Color(0xFFB91C1C),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? const Color(0xFF991B1B) : textSecondary,
                    ),
                    side: BorderSide(
                      color: selected ? const Color(0xFFFCA5A5) : outlineColor,
                    ),
                    onSelected: _isUploading
                        ? null
                        : (_) {
                            setState(() {
                              _dockedState = entry.key;
                              _resetTimerForStatus();
                            });
                          },
                  );
                }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoProofCard() {
    final isOptional = _statusCode(_selectedStatus) == 'docked';

    return _buildSectionCard(
      title: isOptional ? "Photo Proof Optional" : "Photo Proof",
      icon: Icons.add_a_photo_rounded,
      toneColor: isOptional ? const Color(0xFFEF4444) : accentBlue,
      trailing: isOptional
          ? _buildStatusPill("OPTIONAL", const Color(0xFFEF4444))
          : _buildStatusPill("REQUIRED", accentBlue),
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _pickProofImage,
          child: Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _finalCapturedImage == null
                  ? const Color(0xFFF8FAFC)
                  : Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _finalCapturedImage == null
                    ? outlineColor
                    : Colors.transparent,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
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
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Change",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
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
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: accentBlue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 28,
                            color: accentBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isOptional
                              ? "Add a proof photo if available"
                              : "Capture proof before saving",
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Camera opens first, gallery opens if needed",
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? toneColor,
    Widget? trailing,
  }) {
    final color = toneColor ?? primaryDark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusBlock(
    String label,
    String value,
    Color color, {
    String? subBadge,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              if (subBadge != null)
                _buildStatusPill(subBadge, const Color(0xFF64748B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, Color color, {Color? backgroundColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildRouteSummary(String statusLower) {
    String summaryText = "";
    if (statusLower == 'arrived' || statusLower == 'docked') {
      summaryText =
          "Arrived at ${_getPortName(_destinationPortId).toUpperCase()} from ${_getPortName(_originPortId).toUpperCase()}";
    } else if (statusLower == 'departed') {
      summaryText =
          "Departing from ${_getPortName(_originPortId).toUpperCase()} to ${_getPortName(_destinationPortId).toUpperCase()}";
    } else if (statusLower == 'onboarding') {
      summaryText =
          "Onboarding at ${_getPortName(_originPortId).toUpperCase()} bound for ${_getPortName(_destinationPortId).toUpperCase()}";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentBlue.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, color: accentBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summaryText,
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: primaryDark,
              ),
            ),
          ),
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
        : 'TIME UNTIL DEPARTURE';
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
