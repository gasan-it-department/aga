import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditVehicle extends StatefulWidget {
  final int municipalZipCode;
  final Map<String, dynamic>? vehicle;

  const AddEditVehicle({super.key, this.vehicle, required this.municipalZipCode});

  @override
  State<AddEditVehicle> createState() => _AddEditVehicleState();
}

class _AddEditVehicleState extends State<AddEditVehicle> {
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  String? _selectedType;
  String? _selectedStatus;

  final List<String> _types = ['Medical', 'Rescue', 'Utility'];
  final List<String> _statuses = ['Available', 'Patrol', 'Dispatched', 'Maintenance'];

  final _loadingDialog = LoadingDialog();
  final _classicDialog = ClassicDialog();

  bool get isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      _nameController.text = widget.vehicle!['name'] ?? '';
      _modelController.text = widget.vehicle!['model'] ?? '';
      _plateController.text = widget.vehicle!['vehicle_plate_number'] ?? '';
      if (_types.contains(widget.vehicle!['type'])) {
        _selectedType = widget.vehicle!['type'];
      }
      if (_statuses.contains(widget.vehicle!['status'])) {
        _selectedStatus = widget.vehicle!['status'];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null || _selectedStatus == null) {
      _showError("Please select both a Vehicle Type and Status.");
      return;
    }

    try {
      _loadingDialog.showLoadingDialog(context);
      final supabase = Supabase.instance.client;

      final Map<String, dynamic> vehiclePayload = {
        'vehicle_name': _nameController.text.trim(),
        'vehicle_model': _modelController.text.trim(),
        'vehicle_plate_number': _plateController.text.trim().toUpperCase(),
        'vehicle_type': _selectedType,
        'vehicle_status': _selectedStatus
      };

      if (isEditing) {
        final vehicleId = widget.vehicle!['id'];
        await supabase
            .from('vehicles')
            .update(vehiclePayload)
            .eq('vehicle_id', vehicleId)
            .eq('vehicle_municipal_owner', widget.municipalZipCode);
      } else {
        final Map<String, dynamic> currentLocation = {
          "latitude": 13.324021160756043,
          "longitude": 121.846548740283
        };

        vehiclePayload["vehicle_municipal_owner"] = widget.municipalZipCode;
        vehiclePayload["vehicle_id"] = Utility().generateUniqueID();
        vehiclePayload["vehicle_current_coordinates"] = jsonEncode(currentLocation);
        await supabase.from('vehicles').insert(vehiclePayload);
      }

      _loadingDialog.dismiss();

      if (mounted) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      _loadingDialog.dismiss();
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    _classicDialog.setTitle("Action Failed");
    _classicDialog.setMessage(message);
    _classicDialog.setPositiveMessage("Okay");
    _classicDialog.setCancelable(false);
    _classicDialog.showOnButtonDialog(context, () => _classicDialog.dismissDialog());
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
            isEditing ? "Edit Vehicle" : "Register New Unit",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // --- SECTION 1: IDENTIFICATION ---
                          _buildSectionTitle(Icons.badge_rounded, "VEHICLE IDENTIFICATION"),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _nameController,
                                  label: "Call Sign / Vehicle Name",
                                  hint: "e.g., Rescue Alpha 1",
                                  icon: Icons.campaign_rounded,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _plateController,
                                  label: "Plate Number",
                                  hint: "e.g., ABC-1234",
                                  icon: Icons.branding_watermark_rounded,
                                  textCapitalization: TextCapitalization.characters,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _modelController,
                                  label: "Vehicle Make & Model",
                                  hint: "e.g., Toyota Hilux 2023",
                                  icon: Icons.directions_car_rounded,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // --- SECTION 2: OPERATIONAL DETAILS ---
                          _buildSectionTitle(Icons.tune_rounded, "OPERATIONAL STATUS"),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                _buildDropdown(
                                  label: "Vehicle Category",
                                  icon: Icons.category_rounded,
                                  value: _selectedType,
                                  items: _types,
                                  onChanged: (val) => setState(() => _selectedType = val),
                                ),
                                const SizedBox(height: 16),
                                _buildDropdown(
                                  label: "Current Status",
                                  icon: Icons.online_prediction_rounded,
                                  value: _selectedStatus,
                                  items: _statuses,
                                  onChanged: (val) => setState(() => _selectedStatus = val),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- BOTTOM ACTION BUTTON ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveVehicle,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                          isEditing ? "Save Changes" : "Register Unit",
                          style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: textSecondary, size: 20),
        filled: true,
        fillColor: bgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryDark, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      icon: Icon(Icons.expand_more_rounded, color: textSecondary),
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: textSecondary, size: 20),
        filled: true,
        fillColor: bgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryDark, width: 2),
        ),
      ),
      items: items.map((String item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
