import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:latlong2/latlong.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../Map/MapLocationPicker.dart';
import '../../../Maritime/MaritimeActivityLogger.dart';

class AddEditPort extends StatefulWidget {
  final Map<String, dynamic>? port;

  const AddEditPort({super.key, this.port});

  @override
  State<AddEditPort> createState() => _AddEditPortState();
}

class _AddEditPortState extends State<AddEditPort> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _loadingDialog = LoadingDialog();
  final _classicDialog = ClassicDialog();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color accentColor = const Color(0xFF3B82F6);

  LatLng _selectedCoordinates = const LatLng(13.3225, 121.8433);

  bool _isOperational = true;

  SharedPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    _initPrefs();

    WidgetsBinding.instance.addPostFrameCallback((_){
      if (widget.port != null) {
        _nameController.text = widget.port!['port_name'] ?? '';
        _addressController.text = widget.port!['port_address'] ?? '';
        _descriptionController.text = widget.port!['port_description'] ?? '';
        _isOperational = widget.port!["port_status"] == "operational";

        Utility().printLog("Port data: ${widget.port}");

        if (widget.port!['port_latitude'] != null && widget.port!['port_longitude'] != null) {
          _selectedCoordinates = LatLng(
              widget.port!['port_latitude'],
              widget.port!['port_longitude']
          );
        }
      }
    });
  }

  Future<void> _initPrefs() async {
    _preferences = await SharedPreferences.getInstance();
  }

  Future<void> _savePort() async {
    if (!_formKey.currentState!.validate()) return;
    _loadingDialog.showLoadingDialog(context);

    try {
      final Map<String, dynamic> portData = {
        'port_name': _nameController.text.trim(),
        'port_address': _addressController.text.trim(),
        'port_description': _descriptionController.text.trim(),
        'port_latitude': _selectedCoordinates.latitude,
        'port_longitude': _selectedCoordinates.longitude,
        'port_status': _isOperational ? "operational" : "un_operational",
      };

      String userName = _preferences?.getString("user_name") ?? "An Admin";
      String assignedPort = _preferences?.getString("assigned_port") ?? "Unknown Port";
      String userId = _preferences?.getString("user_id") ?? "unknown_user_id";

      if (widget.port == null) {
        portData['port_id'] = DateTime.now().millisecondsSinceEpoch.toString();
        portData["port_added_date"] = Utility().getCurrentMSEpochTime();
        await supabase.from('ports').insert(portData);
        String logMessage = "${portData["port_name"].toString().toUpperCase()} has been added by [$assignedPort] - $userName.";
        await MaritimeActivityLogger.createLog(title: "Port Added", message: logMessage, creatorId: userId);
      } else {
        await supabase.from('ports').update(portData).eq('port_id', widget.port!['port_id']);
        String logMessage = "${portData["port_name"].toString().toUpperCase()} has been updated by [$assignedPort] - $userName.";
        await MaritimeActivityLogger.createLog(title: "Port Updated", message: logMessage, creatorId: userId);
      }

      _loadingDialog.dismiss();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _loadingDialog.dismiss();
      _classicDialog.setTitle("An error occurred!");
      _classicDialog.setMessage(error.toString());
      _classicDialog.setCancelable(false);
      _classicDialog.setPositiveMessage("Exit");
      if(mounted){
        _classicDialog.showOnButtonDialog(context, (){
          _classicDialog.dismissDialog();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primaryColor,
          elevation: 0,
          title: Text(widget.port == null ? "Add Port Facility" : "Edit Port Details",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel("PORT INFORMATION"),

                    // Port Name
                    _buildTextField(
                      controller: _nameController,
                      label: "Port Name",
                      icon: Icons.business,
                      hint: "e.g. Balanacan Port",
                      maxLines: 1,
                    ),
                    const SizedBox(height: 16),

                    // Port Address
                    _buildTextField(
                      controller: _addressController,
                      label: "Port Address",
                      icon: Icons.location_on_rounded,
                      hint: "Province, Municipality, Barangay",
                      maxLines: 1,
                    ),
                    const SizedBox(height: 16),

                    // Description box
                    _buildTextField(
                      controller: _descriptionController,
                      label: "Port Description",
                      icon: Icons.description_rounded,
                      hint: "Enter details, facilities, or contact info...",
                      maxLines: 3,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionLabel("GEOLOCATION"),

                    // --- NEW: Map Picker Button Widget ---
                    _buildLocationSelector(),

                    const SizedBox(height: 24),
                    _buildSectionLabel("PORT STATUS"),
                    _buildStatusToggle(),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _savePort,
                        child: const Text("SAVE PORT FACILITY",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
    );
  }

  // --- UI WIDGETS ---

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required int maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: controller,
        validator: (v) => v!.isEmpty ? "Required" : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? (maxLines * 10.0) : 0),
            child: Icon(icon, color: primaryColor),
          ),
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // --- NEW: Location Selector Card ---
  Widget _buildLocationSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.map_rounded, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Coordinates",
                  style: TextStyle(fontWeight: FontWeight.w800, color: primaryColor, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  "Lat: ${_selectedCoordinates.latitude.toStringAsFixed(5)}\nLon: ${_selectedCoordinates.longitude.toStringAsFixed(5)}",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              backgroundColor: accentColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              // Open the Map Screen and wait for the returned coordinates
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapLocationPicker(initialLocation: _selectedCoordinates),
                ),
              );

              // Update the UI if the user clicked Confirm
              if (result != null && result is LatLng) {
                setState(() {
                  _selectedCoordinates = result;
                });
              }
            },
            icon: const Icon(Icons.location_on, size: 16),
            label: const Text("PICK", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildStatusToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.power_settings_new_rounded, color: _isOperational ? Colors.green : Colors.red),
              const SizedBox(width: 12),
              const Text("Operational Status", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Switch(
            value: _isOperational,
            activeThumbColor: Colors.green,
            onChanged: (v) => setState(() => _isOperational = v),
          ),
        ],
      ),
    );
  }
}
