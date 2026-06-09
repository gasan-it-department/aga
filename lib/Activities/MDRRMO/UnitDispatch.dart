import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/TravelHistory.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/VehicleGasolineDashboard.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ModernBottomsheet/ModernBottomSheet.dart';
import 'SubActivities/AddEditVehicle.dart';

class UnitDispatch extends StatefulWidget {
  final int municipalZipCode;
  const UnitDispatch({required this.municipalZipCode, super.key});

  @override
  State<UnitDispatch> createState() => _UnitDispatchState();
}

class _UnitDispatchState extends State<UnitDispatch> {
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Medical', 'Rescue', 'Utility'];

  List<Map<String, dynamic>> _allUnits = [];
  SupabaseClient? _supabase;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _supabase = Supabase.instance.client;
      _fetchMunicipalVehicles();
    });
  }

  Future<void> _fetchMunicipalVehicles() async {
    try {
      _loadingDialog.showLoadingDialog(context);
      final response = await _supabase!
          .from('vehicles')
          .select()
          .eq('vehicle_municipal_owner', widget.municipalZipCode);

      final List<Map<String, dynamic>> fetchedUnits = (response as List).map((v) {
        return {
          'id': v['vehicle_id']?.toString() ?? '',
          'type': v['vehicle_type']?.toString() ?? 'Unknown',
          'model': v['vehicle_model']?.toString() ?? 'Unnamed Model',
          'status': v['vehicle_status']?.toString() ?? 'Unknown',
          'name': v["vehicle_name"]?.toString() ?? "Unknown Vehicle",
          'vehicle_plate_number': v["vehicle_plate_number"]?.toString() ?? "No plate number"
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allUnits = fetchedUnits;
          _loadingDialog.dismiss();
        });
      }
    } catch (e) {
      debugPrint("Error fetching vehicles: $e");
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, e.toString());
      }
    }
  }

  void _showVehicleOptions(Map<String, dynamic> vehicle) {
    ModernBottomSheet.show(
      context: context,
      title: vehicle['name'] ?? "Vehicle Options",
      subtitle: "Plate: ${vehicle['id']} • ${vehicle['type']}",
      options: [

        SheetOption(
          icon: Icons.edit_rounded,
          title: "Edit Details",
          onTap: () async {
            // EDIT LOGIC
            final bool? result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddEditVehicle(vehicle: vehicle, municipalZipCode: widget.municipalZipCode,)),
            );
            if (result == true) {
              if(mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Updated successfully");
              _fetchMunicipalVehicles();
            }
          },
        ),

        SheetOption(
          icon: Icons.location_on,
          title: "Travel History",
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TravelHistory(vehicleId: vehicle['id'].toString(), vehicleName: vehicle['name'].toString(), vehiclePlateNumber: vehicle['vehicle_plate_number'].toString(),)));
          },
        ),

        SheetOption(
          icon: Icons.local_gas_station_rounded,
          title: "Fuel History",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VehicleGasolineDashboard(
                  vehicleId: vehicle['id'].toString(),
                  vehicleName: vehicle['name'].toString(),
                ),
              ),
            );
          },
        ),

        SheetOption(
          icon: Icons.delete_forever_rounded,
          title: "Delete Permanently",
          isDestructive: true,
          onTap: () {
            // DELETE LOGIC
            _deleteVehicle(vehicle);
          },
        ),

      ],
    );
  }

  Future<void> _deleteVehicle(Map<String, dynamic> unit) async {
    _classicDialog.setTitle("Delete Vehicle?");
    _classicDialog.setMessage("Are you sure you want to delete this vehicle? All associated data, including fuel history, will be permanently deleted.");
    _classicDialog.setPositiveMessage("Delete");
    _classicDialog.setNegativeMessage("Cancel");

    _classicDialog.showTwoButtonDialog(context, (negative){
      _classicDialog.dismissDialog();

    }, (positiveClicked) async {
      _classicDialog.dismissDialog();
      try {
        _loadingDialog.showLoadingDialog(context);
        Utility().printLog("Deleting id: ${unit["id"].toString()}");

        await _supabase!
            .from('travel_history')
            .delete()
            .eq('vehicle_id', unit['id']);

        await _supabase!
            .from('gasoline')
            .delete()
            .eq('vehicle_id', unit['id']);

        await _supabase!
            .from('vehicles')
            .delete()
            .eq('vehicle_id', unit['id']);

        if (mounted) {
          _loadingDialog.dismiss();
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "${unit['name']} and its records were deleted.");
          _fetchMunicipalVehicles();
        }
      } catch (e) {
        if (mounted) {
          _loadingDialog.dismiss();
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error: $e");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayedUnits = _selectedFilter == 'All'
        ? _allUnits
        : _allUnits.where((u) => u['type'] == _selectedFilter).toList();

    return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primaryDark,
          elevation: 0,
          centerTitle: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Unit Dispatch", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
              Text("Command Center Overview", style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Register New Unit',
              onPressed: () async {
                final bool? result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddEditVehicle(municipalZipCode: widget.municipalZipCode,)),
                );

                if (result == true) {
                  _fetchMunicipalVehicles();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.isDesktop(context) ? 1200 : 840),
            child: Column(
              children: [
                _buildDashboardStats(),

                _buildFilters(),

                Expanded(
                  child: displayedUnits.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 48, color: borderColor),
                        const SizedBox(height: 16),
                        Text(
                          "No $_selectedFilter units found.",
                          style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                      : Responsive(
                    mobile: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      physics: const BouncingScrollPhysics(),
                      itemCount: displayedUnits.length,
                      itemBuilder: (context, index) {
                        return _buildUnitCard(displayedUnits[index]);
                      },
                    ),
                    tablet: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: displayedUnits.length,
                      itemBuilder: (context, index) {
                        return _buildUnitCard(displayedUnits[index]);
                      },
                    ),
                    desktop: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.8,
                      ),
                      itemCount: displayedUnits.length,
                      itemBuilder: (context, index) {
                        return _buildUnitCard(displayedUnits[index]);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
    );
  }

  Widget _buildDashboardStats() {
    int available = _allUnits.where((u) => u['status'] == 'Available' || u['status'] == 'Patrol').length;
    int dispatched = _allUnits.where((u) => u['status'] == 'Dispatched').length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          _buildStatCard("Total Units", _allUnits.length.toString(), primaryDark, Icons.local_shipping_rounded),
          const SizedBox(width: 12),
          _buildStatCard("Available", available.toString(), const Color(0xFF10B981), Icons.check_circle_rounded),
          const SizedBox(width: 12),
          _buildStatCard("Active", dispatched.toString(), const Color(0xFFF59E0B), Icons.emergency_share_rounded),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter, style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isSelected ? Colors.white : textSecondary,
              )),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedFilter = filter);
              },
              backgroundColor: Colors.white,
              selectedColor: primaryDark,
              side: BorderSide(color: isSelected ? primaryDark : borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnitCard(Map<String, dynamic> unit) {
    final Color typeColor = _getTypeColor(unit['type']);
    final IconData typeIcon = _getTypeIcon(unit['type']);
    final Color statusColor = _getStatusColor(unit['status']);

    return Container(
      margin: Responsive.isMobile(context) ? const EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: primaryDark.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))
          ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showVehicleOptions(unit),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular Type Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 16),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Vehicle Name & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              unit['name'],
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(unit['status'], statusColor),

                          // Options Dot Trigger
                          const SizedBox(width: 8),
                          Icon(Icons.more_vert_rounded, size: 20, color: textSecondary),
                        ],
                      ),

                      const SizedBox(height: 2),

                      Text(
                          "${unit['type']} Unit",
                          style: TextStyle(fontSize: 12, color: typeColor, fontWeight: FontWeight.w700, letterSpacing: 0.5)
                      ),

                      const SizedBox(height: 12),

                      // Redesigned Info Rows: Plate Number & Model
                      _buildInfoRow(Icons.branding_watermark_rounded, "Plate No: ${unit['vehicle_plate_number']}", textPrimary),
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.directions_car_rounded, "Model: ${unit['model']}", textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Medical': return const Color(0xFF0D9488);
      case 'Rescue': return const Color(0xFF2563EB);
      case 'Utility': return const Color(0xFFD97706);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Medical': return Icons.medical_services_rounded;
      case 'Rescue': return Icons.emergency_rounded;
      case 'Utility': return Icons.delete_rounded;
      default: return Icons.directions_car_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available':
      case 'Patrol': return const Color(0xFF10B981); // Green
      case 'Dispatched': return const Color(0xFFF59E0B); // Yellow/Orange
      case 'Maintenance': return const Color(0xFFEF4444); // Red
      default: return const Color(0xFF64748B); // Grey
    }
  }
}
