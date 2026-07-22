import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/VesselTypes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../Maritime/MaritimeActivityLogger.dart';

class AddEditVessel extends StatefulWidget {
  final Map<String, dynamic>? vessel;
  final String shippingLineId;

  const AddEditVessel({super.key, this.vessel, required this.shippingLineId});

  @override
  State<AddEditVessel> createState() => _AddEditVesselState();
}

class _AddEditVesselState extends State<AddEditVessel> {
  final supabase = Supabase.instance.client;
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color accentColor = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _imoController = TextEditingController();

  String? _selectedVesselType;
  bool _isSaving = false;
  bool get isEditMode => widget.vessel != null;
  String get namePreview => _nameController.text.trim();

  SharedPreferences? _preferences; // --- NEW: Preferences variable ---

  @override
  void initState() {
    super.initState();
    _initPrefs(); // --- NEW: Initialize preferences ---

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isEditMode) {
        _nameController.text = widget.vessel!['vessel_name'] ?? '';
        _imoController.text = widget.vessel!['imo_number'] ?? '';
        _selectedVesselType = widget.vessel!['vessel_type'];
      }
    });
  }

  // --- NEW: Load SharedPreferences ---
  Future<void> _initPrefs() async {
    _preferences = await SharedPreferences.getInstance();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imoController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Vessel Name is required")));
      return;
    }

    setState(() => _isSaving = true);

    final Map<String, dynamic> data = {
      'vessel_name': name,
      'imo_number': _imoController.text.trim().isEmpty
          ? null
          : _imoController.text.trim(),
      'vessel_type': _selectedVesselType,
      'shipping_line_id': widget.shippingLineId,
    };

    // --- NEW: Get admin info for logging ---
    String userName = _preferences?.getString("user_name") ?? "An Admin";
    String assignedPort =
        _preferences?.getString("assigned_port") ?? "Unknown Port";
    String userId = _preferences?.getString("user_id") ?? "unknown_user_id";
    String vesselName = name.toUpperCase();

    try {
      if (isEditMode) {
        await supabase
            .from('vessels')
            .update(data)
            .eq('vessel_id', widget.vessel!['vessel_id']);

        // --- NEW: Log Update ---
        await MaritimeActivityLogger.createLog(
          title: "Vessel Updated",
          message:
              "$vesselName details were modified by [$assignedPort] - $userName.",
          creatorId: userId,
        );
      } else {
        final created = await supabase
            .from('vessels')
            .insert(data)
            .select()
            .single();
        data.addAll(Map<String, dynamic>.from(created));

        // --- NEW: Log Creation ---
        await MaritimeActivityLogger.createLog(
          title: "Vessel Registered",
          message:
              "$vesselName was added to the fleet by [$assignedPort] - $userName.",
          creatorId: userId,
        );
      }
      if (mounted) Navigator.pop(context, data);
    } catch (e) {
      debugPrint("Save error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        title: Text(
          isEditMode ? "Edit Vessel" : "Register Vessel",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          if (!_isSaving)
            TextButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text(
                "Save",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Utility().getMaxScreenSize(),
                ),
                child: Column(
                  children: [
                    _buildHeaderPreview(),
                    const SizedBox(height: 20),

                    _buildFormSection(
                      title: "VESSEL IDENTITY",
                      children: [
                        _buildInputField(
                          label: "Vessel Name",
                          hint: "e.g. MV Princess of Gasan",
                          controller: _nameController,
                          icon: Icons.badge_outlined,
                          onChanged: (_) => setState(() {}),
                        ),
                        const Divider(height: 32, thickness: 0.5),
                        _buildInputField(
                          label: "IMO Number (Optional)",
                          hint: "Enter IMO number if available",
                          controller: _imoController,
                          icon: Icons.tag_outlined,
                          enabled: !isEditMode,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildFormSection(
                      title: "VESSEL CLASSIFICATION",
                      children: [
                        _buildDropdownField(
                          label: "Vessel Type",
                          value: _selectedVesselType,
                          icon: Icons.category_outlined,
                          items: VesselTypes().shipTypes,
                          onChanged: (val) =>
                              setState(() => _selectedVesselType = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_boat_filled,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  namePreview.isEmpty
                      ? "VESSEL NAME"
                      : namePreview.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _selectedVesselType ?? "Select Type Below",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text("•", style: TextStyle(color: Colors.white54)),
                    const SizedBox(width: 8),
                    const Text(
                      "STATUS SET WITH PHOTO PROOF",
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFormSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textSecondary.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.only(top: 10, left: 26),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: items
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
