import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/VesselTypes.dart';

class AddRouteDialog extends StatefulWidget {
  final List<Map<String, dynamic>>? ports;
  final Map<String, dynamic>? initialRoute; // 1. Added initialRoute

  const AddRouteDialog({super.key, this.ports, this.initialRoute});

  // 2. Updated the show method to accept optional initialRoute
  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    List<Map<String, dynamic>>? portList, {
    Map<String, dynamic>? initialRoute,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          AddRouteDialog(ports: portList, initialRoute: initialRoute),
    );
  }

  @override
  State<AddRouteDialog> createState() => _AddRouteDialogState();
}

class _AddRouteDialogState extends State<AddRouteDialog> {
  // Selection states
  String? _selectedOrigin;
  String? _selectedDestination;
  String? _selectedShipType;
  String _scheduleStatus = "Flexible";

  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color outlineColor = const Color(0xFFCBD5E1);

  // 3. Pre-fill data if we are in Edit Mode
  @override
  void initState() {
    super.initState();
    if (widget.initialRoute != null) {
      final routeString = widget.initialRoute!['route'] as String?;
      if (routeString != null) {
        final parts = routeString.split(' to ');
        if (parts.length == 2) {
          _selectedOrigin = parts[0];
          _selectedDestination = parts[1];
        }
      }

      _selectedShipType = widget.initialRoute!['shipType'];
      _scheduleStatus = "Flexible";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract names from the ports list provided by the parent
    final List<String> availablePorts =
        widget.ports?.map((e) => e['port_name'].toString()).toList() ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.initialRoute != null ? "Edit Route Details" : "Route Details",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      contentPadding: const EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Origin Dropdown ---
              const Text(
                "ORIGIN",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              _buildDropdown(
                hint: "Select Origin Port",
                value: _selectedOrigin,
                items: availablePorts,
                onChanged: (val) => setState(() => _selectedOrigin = val),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                  child: Text(
                    "TO",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

              // --- Destination Dropdown ---
              const Text(
                "DESTINATION",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              _buildDropdown(
                hint: "Select Destination Port",
                value: _selectedDestination,
                items: availablePorts,
                onChanged: (val) => setState(() => _selectedDestination = val),
              ),

              const SizedBox(height: 24),

              // --- Ship Type Dropdown ---
              const Text(
                "VESSEL TYPE",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              _buildDropdown(
                hint: "Select Ship Type",
                value: _selectedShipType,
                items: VesselTypes().shipTypes,
                onChanged: (val) => setState(() => _selectedShipType = val),
              ),

              const SizedBox(height: 24),

              // --- Schedule Status ---
              const Text(
                "SCHEDULE STATUS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: _scheduleStatus,
                items: ["Flexible"].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _scheduleStatus = val);
                },
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: outlineColor),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "CANCEL",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        if (_selectedOrigin == null ||
                            _selectedDestination == null ||
                            _selectedShipType == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please fill in all fields!"),
                            ),
                          );
                          return;
                        }

                        if (_selectedOrigin == _selectedDestination) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Origin and Destination cannot be the same!",
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context, {
                          'route': "$_selectedOrigin to $_selectedDestination",
                          'status': _scheduleStatus,
                          'shipType': _selectedShipType,
                          // 4. Preserve the existing times if editing!
                          'times': widget.initialRoute?['times'] ?? <String>[],
                        });
                      },
                      // 5. Dynamic button text
                      child: Text(
                        widget.initialRoute != null
                            ? "SAVE CHANGES"
                            : "ADD ROUTE",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outlineColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 14)),
          value: value,
          items: items.map((String itemName) {
            return DropdownMenuItem<String>(
              value: itemName,
              child: Text(itemName),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
