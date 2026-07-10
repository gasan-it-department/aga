import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../Dialogs/Bottomsheets/AddEditFare.dart';
import '../../../Dialogs/AddRouteDialog.dart';
import '../../../Maritime/MaritimeActivityLogger.dart';

class AddEditShippingLine extends StatefulWidget {
  final Map<String, dynamic>? shippingLine;
  final List<Map<String, dynamic>>? ports;

  const AddEditShippingLine({super.key, this.shippingLine, this.ports});

  @override
  State<AddEditShippingLine> createState() => _AddEditShippingLineState();
}

class _AddEditShippingLineState extends State<AddEditShippingLine> {
  final supabase = Supabase.instance.client;

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color accentColor = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _fares = [];

  bool _isSaving = false;
  bool get isEditMode => widget.shippingLine != null;

  SharedPreferences? _preferences; // --- NEW: Preferences variable ---

  @override
  void initState() {
    super.initState();
    _initPrefs(); // --- NEW: Initialize preferences ---

    if (isEditMode) {
      _nameController.text = widget.shippingLine!['shipping_line_name'] ?? '';
      _contactController.text =
          widget.shippingLine!['shipping_line_contact'] ?? '';
      _schedules = _parseJsonField(
        widget.shippingLine!['shipping_line_schedules'],
      );
      _fares = _parseJsonField(widget.shippingLine!['shipping_line_fares']);
    }

    Utility().printLog("Loaded port: ${widget.ports}");
  }

  // --- NEW: Load SharedPreferences ---
  Future<void> _initPrefs() async {
    _preferences = await SharedPreferences.getInstance();
  }

  List<Map<String, dynamic>> _parseJsonField(dynamic data) {
    if (data == null) return [];
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return List<Map<String, dynamic>>.from(decoded);
      } catch (e) {
        debugPrint("JSON Parse Error: $e");
        return [];
      }
    }
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Shipping Line Name is required")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final Map<String, dynamic> data = {
      'shipping_line_name': _nameController.text.trim(),
      'contact_number': _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      'is_active': true,
    };

    // --- NEW: Get admin info for logging ---
    String userName = _preferences?.getString("user_name") ?? "An Admin";
    String assignedPort =
        _preferences?.getString("assigned_port") ?? "Unknown Port";
    String lineName = _nameController.text.trim().toUpperCase();

    try {
      Map<String, dynamic> savedLine;
      if (isEditMode) {
        savedLine = Map<String, dynamic>.from(
          await supabase
              .from('shipping_lines')
              .update(data)
              .eq('shipping_line_id', widget.shippingLine!['shipping_line_id'])
              .select()
              .single(),
        );

        await MaritimeActivityLogger.createLog(
          title: "Shipping Line Updated",
          message: "$lineName was modified by [$assignedPort] - $userName.",
          creatorId: userName,
        );
      } else {
        savedLine = Map<String, dynamic>.from(
          await supabase.from('shipping_lines').insert(data).select().single(),
        );

        await MaritimeActivityLogger.createLog(
          title: "Shipping Line Added",
          message:
              "$lineName was added to the fleet database by [$assignedPort] - $userName.",
          creatorId: userName,
        );
      }

      final lineId = savedLine['shipping_line_id'];
      await supabase
          .from('shipping_line_route_profiles')
          .delete()
          .eq('shipping_line_id', lineId);
      final portIdsByName = {
        for (final port in widget.ports ?? const <Map<String, dynamic>>[])
          port['port_name'].toString(): port['port_id'].toString(),
      };

      for (final route in _schedules) {
        final routeText = route['route']?.toString() ?? '';
        final parts = routeText.split(' to ');
        final originId =
            route['origin_port_id']?.toString() ??
            (parts.isNotEmpty ? portIdsByName[parts.first] : null);
        final destinationId =
            route['destination_port_id']?.toString() ??
            (parts.length > 1 ? portIdsByName[parts.last] : null);
        if (originId == null || destinationId == null) continue;

        final profile = await supabase
            .from('shipping_line_route_profiles')
            .insert({
              'shipping_line_id': lineId,
              'origin_port_id': originId,
              'destination_port_id': destinationId,
              'vessel_type': route['shipType'] ?? 'All',
              'docked_min_minutes': 30,
              'docked_default_minutes': 45,
              'docked_max_minutes': 60,
            })
            .select()
            .single();

        if (_fares.isNotEmpty) {
          await supabase
              .from('shipping_line_fares')
              .insert(
                _fares
                    .map(
                      (fare) => {
                        'profile_id': profile['profile_id'],
                        'fare_category': fare['type'],
                        'amount':
                            double.tryParse(fare['price']?.toString() ?? '') ??
                            0,
                      },
                    )
                    .toList(),
              );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode ? "Updated successfully" : "Created successfully",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Save error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primaryColor,
          elevation: 0,
          title: Text(
            isEditMode ? "Edit" : "New",
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
            child: Column(
              children: [
                // 1. IDENTITY SECTION
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: outlineColor),
                    ),
                    child: Column(
                      children: [
                        _buildDashboardField(
                          label: "Shipping Line Name",
                          icon: Icons.business_center_rounded,
                          controller: _nameController,
                          hint: "e.g. Starhorse Shipping",
                        ),
                        const Divider(height: 32),
                        _buildDashboardField(
                          label: "Contact Number",
                          icon: Icons.phone_android_rounded,
                          controller: _contactController,
                          hint: "e.g. +63 912 345 6789",
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. TAB NAVIGATION
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: outlineColor),
                  ),
                  child: TabBar(
                    labelColor: primaryColor,
                    unselectedLabelColor: textSecondary,
                    indicatorColor: accentColor,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(text: "Routes"),
                      Tab(text: "Fares"),
                    ],
                  ),
                ),

                // 3. TAB VIEW
                Expanded(
                  child: TabBarView(
                    children: [_buildScheduleTab(), _buildFareTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "OPERATING ROUTES",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            IconButton(
              onPressed: _addNewRoute,
              icon: Icon(Icons.add_circle_outline, color: accentColor),
            ),
          ],
        ),
        if (_schedules.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("No routes added yet."),
            ),
          ),
        ..._schedules.asMap().entries.map(
          (entry) => _buildRouteCard(entry.key),
        ),
      ],
    );
  }

  Widget _buildRouteCard(int index) {
    final route = _schedules[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  route['route'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _editRoute(index),
                    icon: Icon(
                      Icons.edit_outlined,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _schedules.removeAt(index)),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Text(
                "Flexible departure",
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (route['shipType'] != null) ...[
                const SizedBox(width: 6),
                const Text(
                  "•",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.directions_boat_rounded,
                  size: 12,
                  color: textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  route['shipType'],
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "FARES APPLIED TO ALL ROUTES",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            IconButton(
              onPressed: _addNewFare,
              icon: Icon(Icons.add_circle_outline, color: accentColor),
            ),
          ],
        ),
        if (_fares.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("No fares added yet."),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: outlineColor),
            ),
            child: Column(
              children: List.generate(_fares.length, (index) {
                return ListTile(
                  onTap: () => _editFare(index),
                  title: Text(
                    _fares[index]['type'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    "₱${Utility().formatPrice(_fares[index]['price'])}",
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildDashboardField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
          ],
        ),
        TextField(
          controller: controller,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: outlineColor, fontSize: 14),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ],
    );
  }

  Future<void> _addNewRoute() async {
    final Map<String, dynamic>? data = await AddRouteDialog.show(
      context,
      widget.ports,
    );
    if (data != null) setState(() => _schedules.add(data));
  }

  Future<void> _addNewFare() async {
    final Map<String, String>? data = await AddEditFare.show(context);
    if (data != null) setState(() => _fares.add(data));
  }

  Future<void> _editFare(int index) async {
    final Map<String, String>? data = await AddEditFare.show(
      context,
      fare: _fares[index],
    );
    if (data != null) setState(() => _fares[index] = data);
  }

  Future<void> _editRoute(int index) async {
    final Map<String, dynamic>? updatedData = await AddRouteDialog.show(
      context,
      widget.ports,
      initialRoute: _schedules[index],
    );

    if (updatedData != null) {
      setState(() {
        updatedData['times'] = _schedules[index]['times'];
        _schedules[index] = updatedData;
      });
    }
  }
}
