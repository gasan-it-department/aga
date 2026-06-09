import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditTravelTicket extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic>? travelLog;
  final String plateNumber;

  const AddEditTravelTicket({
    super.key,
    required this.vehicleId,
    this.travelLog,
    this.plateNumber = "No plate"
  });

  @override
  State<AddEditTravelTicket> createState() => _AddEditTravelTicketState();
}

class _AddEditTravelTicketState extends State<AddEditTravelTicket> {
  // --- Theme Colors ---
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  final _loadingDialog = LoadingDialog();
  SupabaseClient? _supabase;

  bool _isEditMode = false;

  final _formKey = GlobalKey<FormState>();
  final _driverCtrl = TextEditingController();
  final _plateNoCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _passengerInputCtrl = TextEditingController();

  List<String> _passengersList = [];
  DateTime? _timeDepartGarage;
  DateTime? _timeArriveDest;
  DateTime? _timeDepartDest;
  DateTime? _timeArriveGarage;

  final _timeDepartGarageCtrl = TextEditingController();
  final _timeArriveDestCtrl = TextEditingController();
  final _timeDepartDestCtrl = TextEditingController();
  final _timeArriveGarageCtrl = TextEditingController();

  // 3. Speedometer & Distance
  final _odoStartCtrl = TextEditingController();
  final _odoEndCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();

  // 4. Fuel & Oil
  final _gasStartCtrl = TextEditingController();
  final _gasIssuedCtrl = TextEditingController();
  final _gasPurchasedCtrl = TextEditingController();
  final _gasUsedCtrl = TextEditingController();

  final _lubeOilUsedCtrl = TextEditingController();
  final _gearOilUsedCtrl = TextEditingController();
  final _gearOilUnusedCtrl = TextEditingController();

  // 5. Remarks
  final _remarksCtrl = TextEditingController();

  // Computed display values
  double _computedGasTotal = 0.0;
  double _computedGasBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _isEditMode = widget.travelLog != null;

    _plateNoCtrl.text = widget.plateNumber;

    // Add listeners for auto-calculations
    _odoStartCtrl.addListener(_calculateDistance);
    _odoEndCtrl.addListener(_calculateDistance);
    _gasStartCtrl.addListener(_calculateFuel);
    _gasIssuedCtrl.addListener(_calculateFuel);
    _gasPurchasedCtrl.addListener(_calculateFuel);
    _gasUsedCtrl.addListener(_calculateFuel);

    if (_isEditMode) {
      _loadExistingData();
    }
  }

  @override
  void dispose() {
    _driverCtrl.dispose();
    _plateNoCtrl.dispose();
    _passengerInputCtrl.dispose();
    _destinationCtrl.dispose();
    _purposeCtrl.dispose();
    _timeDepartGarageCtrl.dispose();
    _timeArriveDestCtrl.dispose();
    _timeDepartDestCtrl.dispose();
    _timeArriveGarageCtrl.dispose();
    _odoStartCtrl.dispose();
    _odoEndCtrl.dispose();
    _distanceCtrl.dispose();
    _gasStartCtrl.dispose();
    _gasIssuedCtrl.dispose();
    _gasPurchasedCtrl.dispose();
    _gasUsedCtrl.dispose();
    _lubeOilUsedCtrl.dispose();
    _gearOilUsedCtrl.dispose();
    _gearOilUnusedCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // PASSENGER LIST LOGIC
  // ==========================================
  void _addPassenger() {
    final name = _passengerInputCtrl.text.trim();
    if (name.isNotEmpty && !_passengersList.contains(name)) {
      setState(() {
        _passengersList.add(name);
        _passengerInputCtrl.clear();
      });
    }
  }

  void _removePassenger(String name) {
    setState(() {
      _passengersList.remove(name);
    });
  }

  // ==========================================
  // AUTO CALCULATIONS
  // ==========================================
  void _calculateDistance() {
    double start = double.tryParse(_odoStartCtrl.text) ?? 0.0;
    double end = double.tryParse(_odoEndCtrl.text) ?? 0.0;
    if (end > start) {
      _distanceCtrl.text = (end - start).toStringAsFixed(1);
    }
  }

  void _calculateFuel() {
    double start = double.tryParse(_gasStartCtrl.text) ?? 0.0;
    double issued = double.tryParse(_gasIssuedCtrl.text) ?? 0.0;
    double purchased = double.tryParse(_gasPurchasedCtrl.text) ?? 0.0;
    double used = double.tryParse(_gasUsedCtrl.text) ?? 0.0;

    setState(() {
      _computedGasTotal = start + issued + purchased;
      _computedGasBalance = _computedGasTotal - used;
    });
  }

  void _loadExistingData() {
    final log = widget.travelLog!;

    _driverCtrl.text = log['driver_name']?.toString() ?? '';
    _plateNoCtrl.text = widget.plateNumber;
    _destinationCtrl.text = log['destination']?.toString() ?? '';
    _purposeCtrl.text = log['purpose']?.toString() ?? '';

    // Load Passengers (Parse from comma-separated string)
    final passengerStr = log['authorized_passenger']?.toString() ?? '';
    if (passengerStr.isNotEmpty) {
      _passengersList = passengerStr.split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Load Times
    _timeDepartGarage = _parseEpoch(log['time_depart_garage']);
    _timeArriveDest = _parseEpoch(log['time_arrive_dest']);
    _timeDepartDest = _parseEpoch(log['time_depart_dest']);
    _timeArriveGarage = _parseEpoch(log['time_arrive_garage']);

    if (_timeDepartGarage != null) _timeDepartGarageCtrl.text = _formatDateForInput(_timeDepartGarage!);
    if (_timeArriveDest != null) _timeArriveDestCtrl.text = _formatDateForInput(_timeArriveDest!);
    if (_timeDepartDest != null) _timeDepartDestCtrl.text = _formatDateForInput(_timeDepartDest!);
    if (_timeArriveGarage != null) _timeArriveGarageCtrl.text = _formatDateForInput(_timeArriveGarage!);

    // Load Metrics
    _odoStartCtrl.text = log['odo_start']?.toString() ?? '';
    _odoEndCtrl.text = log['odo_end']?.toString() ?? '';
    _distanceCtrl.text = log['distance_km']?.toString() ?? '';

    _gasStartCtrl.text = log['gas_balance_start']?.toString() ?? '';
    _gasIssuedCtrl.text = log['gas_issued']?.toString() ?? '';
    _gasPurchasedCtrl.text = log['gas_purchased']?.toString() ?? '';
    _gasUsedCtrl.text = log['gas_used']?.toString() ?? '';

    _lubeOilUsedCtrl.text = log['lube_oil_used']?.toString() ?? '';
    _gearOilUsedCtrl.text = log['gear_oil_used']?.toString() ?? '';
    _gearOilUnusedCtrl.text = log['gear_oil_unused']?.toString() ?? '';

    _remarksCtrl.text = log['remarks']?.toString() ?? '';

    _calculateFuel();
  }

  DateTime? _parseEpoch(dynamic epochStr) {
    final int epochMs = int.tryParse(epochStr?.toString() ?? '0') ?? 0;
    return epochMs > 0 ? DateTime.fromMillisecondsSinceEpoch(epochMs) : null;
  }

  Future<void> _saveTravelTicket() async {
    if (!_formKey.currentState!.validate()) {
      SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Please fill in all required fields.");
      return;
    }

    try {
      _loadingDialog.showLoadingDialog(context);

      final Map<String, dynamic> travelData = {
        'driver_name': _driverCtrl.text.trim(),
        'plate_number': _plateNoCtrl.text.trim(),
        'authorized_passenger': _passengersList.join(', '),
        'destination': _destinationCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'time_depart_garage': _timeDepartGarage?.millisecondsSinceEpoch ?? 0,
        'time_arrive_dest': _timeArriveDest?.millisecondsSinceEpoch ?? 0,
        'time_depart_dest': _timeDepartDest?.millisecondsSinceEpoch ?? 0,
        'time_arrive_garage': _timeArriveGarage?.millisecondsSinceEpoch ?? 0,
        'departure_time': _timeDepartGarage?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,

        'odo_start': double.tryParse(_odoStartCtrl.text.trim()) ?? 0.0,
        'odo_end': double.tryParse(_odoEndCtrl.text.trim()) ?? 0.0,
        'distance_km': double.tryParse(_distanceCtrl.text.trim()) ?? 0.0,

        // Fuel
        'gas_balance_start': double.tryParse(_gasStartCtrl.text.trim()) ?? 0.0,
        'gas_issued': double.tryParse(_gasIssuedCtrl.text.trim()) ?? 0.0,
        'gas_purchased': double.tryParse(_gasPurchasedCtrl.text.trim()) ?? 0.0,
        'gas_total': _computedGasTotal,
        'gas_used': double.tryParse(_gasUsedCtrl.text.trim()) ?? 0.0,
        'gas_balance_end': _computedGasBalance,

        // Oil
        'lube_oil_used': double.tryParse(_lubeOilUsedCtrl.text.trim()) ?? 0.0,
        'gear_oil_used': double.tryParse(_gearOilUsedCtrl.text.trim()) ?? 0.0,
        'gear_oil_unused': double.tryParse(_gearOilUnusedCtrl.text.trim()) ?? 0.0,

        'remarks': _remarksCtrl.text.trim(),
      };

      if (_isEditMode) {
        await _supabase!.from('travel_history').update(travelData).eq('travel_id', widget.travelLog!['travel_id']);
      } else {
        travelData['travel_id'] = Utility().generateUniqueID();
        travelData["vehicle_id"] = widget.vehicleId;
        await _supabase!.from('travel_history').insert(travelData);
      }

      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, _isEditMode ? "Trip Ticket updated." : "Trip Ticket saved.");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error: $e");
      }
    }
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
        title: Text(
          _isEditMode ? "Edit Trip Ticket" : "New Trip Ticket",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // SECTION 1: OFFICIALS
                  _buildSectionHeader("A. Officials (Authorization)", Icons.admin_panel_settings_rounded),
                  _buildCardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(_driverCtrl, "Name of Driver", Icons.badge_rounded, required: true),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_plateNoCtrl, "Plate No.", Icons.branding_watermark_rounded)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(_destinationCtrl, "Destination", Icons.place_rounded, required: true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(_purposeCtrl, "Purpose", Icons.assignment_rounded, required: true),

                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

                        // NEW PASSENGER LIST UI
                        const Text("Authorized Passengers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _passengerInputCtrl,
                                textCapitalization: TextCapitalization.words,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: "Type name and press +",
                                  prefixIcon: Icon(Icons.person_add_rounded, color: textSecondary, size: 20),
                                  filled: true,
                                  fillColor: bgColor,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 2)),
                                ),
                                onFieldSubmitted: (val) => _addPassenger(), // Adds when "Enter" is pressed
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: primaryDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add_rounded, color: Colors.white),
                                onPressed: _addPassenger, // Adds when button is tapped
                              ),
                            )
                          ],
                        ),

                        // Display the Passenger Chips
                        if (_passengersList.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _passengersList.map((passenger) {
                              return Chip(
                                label: Text(passenger, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                backgroundColor: Colors.white,
                                deleteIcon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFFEF4444)),
                                onDeleted: () => _removePassenger(passenger),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              );
                            }).toList(),
                          )
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 2: TIMES
                  _buildSectionHeader("B. Driver's Itinerary (Time)", Icons.schedule_rounded),
                  _buildCardContainer(
                    child: Column(
                      children: [
                        _buildDateTimePicker("Departure from Garage", _timeDepartGarageCtrl, (dt) => _timeDepartGarage = dt, isRequired: true),
                        const SizedBox(height: 12),
                        _buildDateTimePicker("Arrival at Destination", _timeArriveDestCtrl, (dt) => _timeArriveDest = dt),
                        const SizedBox(height: 12),
                        _buildDateTimePicker("Departure from Destination", _timeDepartDestCtrl, (dt) => _timeDepartDest = dt),
                        const SizedBox(height: 12),
                        _buildDateTimePicker("Arrival back to Garage", _timeArriveGarageCtrl, (dt) => _timeArriveGarage = dt),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 3: SPEEDOMETER
                  _buildSectionHeader("C. Distance & Speedometer", Icons.speed_rounded),
                  _buildCardContainer(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_odoStartCtrl, "Beginning Odo", Icons.looks_one_rounded, isNum: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(_odoEndCtrl, "Ending Odo", Icons.looks_two_rounded, isNum: true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(_distanceCtrl, "Approx. Distance Traveled (KM)", Icons.add_road_rounded, isNum: true, required: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 4: FUEL & OIL
                  _buildSectionHeader("D. Gasoline & Oil Consumption", Icons.local_gas_station_rounded),
                  _buildCardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Gasoline Details (Liters)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_gasStartCtrl, "Balance in Tank", Icons.water_drop_rounded, isNum: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(_gasIssuedCtrl, "Issued from Stock", Icons.outbox_rounded, isNum: true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(_gasPurchasedCtrl, "Add: Purchased during trip", Icons.receipt_long_rounded, isNum: true),

                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),

                        // Computed Totals UI
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Gasoline:", style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            Text("${_computedGasTotal.toStringAsFixed(2)} L", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF10B981))),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(_gasUsedCtrl, "Deduct: Used during trip", Icons.local_fire_department_rounded, isNum: true),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Balance at end of trip:", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                              Text("${_computedGasBalance.toStringAsFixed(2)} L", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0A2E5C))),
                            ],
                          ),
                        ),

                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                        const Text("Oil Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
                        const SizedBox(height: 12),
                        _buildTextField(_lubeOilUsedCtrl, "Lubricating Oil Used", Icons.opacity_rounded, isNum: true),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_gearOilUsedCtrl, "Gear Oil Used", Icons.settings_applications_rounded, isNum: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(_gearOilUnusedCtrl, "Gear Oil Unused", Icons.settings_rounded, isNum: true)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 5: REMARKS
                  _buildSectionHeader("E. Remarks", Icons.notes_rounded),
                  _buildCardContainer(
                    child: TextFormField(
                      controller: _remarksCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "Enter any issues, delays, or additional info here...",
                        filled: true,
                        fillColor: bgColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 2)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saveTravelTicket,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                          _isEditMode ? "Update Trip Ticket" : "Save Trip Ticket",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryDark),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: child,
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false, bool required = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      textCapitalization: isNum ? TextCapitalization.none : TextCapitalization.words,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      decoration: InputDecoration(
        labelText: required ? "$label *" : label,
        prefixIcon: Icon(icon, color: textSecondary, size: 20),
        filled: true,
        fillColor: bgColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 2)),
      ),
      validator: required ? (val) => (val == null || val.isEmpty) ? "Required" : null : null,
    );
  }

  Widget _buildDateTimePicker(String label, TextEditingController ctrl, Function(DateTime) onPicked, {bool isRequired = false}) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      decoration: InputDecoration(
        labelText: isRequired ? "$label *" : label,
        prefixIcon: Icon(Icons.access_time_filled_rounded, color: textSecondary, size: 20),
        filled: true,
        fillColor: bgColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 2)),
      ),
      validator: isRequired ? (val) => (val == null || val.isEmpty) ? "Required" : null : null,
      onTap: () async {
        final initial = DateTime.now();
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: primaryDark)), child: child!),
        );

        if (pickedDate != null) {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(initial),
            builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: primaryDark)), child: child!),
          );

          if (pickedTime != null) {
            final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
            ctrl.text = _formatDateForInput(dt);
            onPicked(dt);
          }
        }
      },
    );
  }

  String _formatDateForInput(DateTime date) {
    int hour12 = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    String amPm = date.hour >= 12 ? 'PM' : 'AM';
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} at $hour12:${date.minute.toString().padLeft(2, '0')} $amPm";
  }
}
