import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Dialogs/ClassicDialog.dart';
import '../../Dialogs/LoadingDialog.dart';
import '../../Utility/Utility.dart';
import 'SubActivities/AddEditMdrrmoPersonnel.dart';

class MdrrmoPersonnelList extends StatefulWidget {
  final int mdrrmoMunicipality;
  const MdrrmoPersonnelList({super.key, required this.mdrrmoMunicipality});

  @override
  State<MdrrmoPersonnelList> createState() => _MdrrmoPersonnelListState();
}

class _MdrrmoPersonnelListState extends State<MdrrmoPersonnelList> {
  final _supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();

  final Color bgColor = const Color(0xFFF4F7FA);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color emergencyRed = const Color(0xFFEF4444);

  final Color statusDuty = const Color(0xFF10B981);
  final Color statusLeave = const Color(0xFFF59E0B);
  final Color statusDismissed = const Color(0xFF94A3B8);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _allPersonnel = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPersonnel();
  }

  Future<void> _fetchPersonnel() async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('mdrrmo_personnels')
          .select()
          .eq('personnel_municipality', widget.mdrrmoMunicipality)
          .order('personnel_date_registered', ascending: false);

      if (mounted) {
        setState(() {
          _allPersonnel = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError("Failed to load personnel: $e");
    }
  }
  
  void _navigateToAddEdit([Map<String, dynamic>? personnel]) async {
    final bool? refresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditMdrrmoPersonnel(existingPersonnel: personnel, currentMunicipalZipCode: widget.mdrrmoMunicipality,),
      ),
    );

    // If the form screen returns true, refresh the list to show new data
    if (refresh == true) {
      _fetchPersonnel();
    }
  }

  // --- DELETE LOGIC ---
  Future<void> _deletePersonnel(String id, String userId) async {
    _classicDialog.setTitle("Remove Personnel");
    _classicDialog.setMessage("Are you sure you want to remove this personnel from the database? This cannot be undone.");
    _classicDialog.setPositiveMessage("Remove");
    _classicDialog.setNegativeMessage("Cancel");

    _classicDialog.showTwoButtonDialog(context, (negativeClick){
      _classicDialog.dismissDialog();

    }, (positiveClicked) async {
      _classicDialog.dismissDialog();
      _loadingDialog.showLoadingDialog(context);
      try {
        await _supabase.from("user_data").update({"user_access": null}).eq("user_id", userId);
        await _supabase.from('mdrrmo_personnels').delete().eq('personnel_id', id);
        if (mounted) _loadingDialog.dismiss();
        _fetchPersonnel();
      } catch (e) {
        if (mounted) _loadingDialog.dismiss();
        _showError("Delete failed: $e");
      }
    });
  }

  String _getMunicipalityName(dynamic zipCode) {
    final zip = zipCode.toString();
    switch (zip) {
      case "4900": return "Boac";
      case "4901": return "Mogpog";
      case "4902": return "Santa Cruz";
      case "4903": return "Torrijos";
      case "4904": return "Buenavista";
      case "4905": return "Gasan";
      case "0000": return "Provincial";
      default: return zip;
    }
  }

  // Helper to generate Avatar Initials
  String _getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    List<String> names = name.trim().split(" ");
    if (names.length >= 2) {
      return "${names.first[0]}${names.last[0]}".toUpperCase();
    }
    return names.first.substring(0, names.first.length > 1 ? 2 : 1).toUpperCase();
  }

  List<Map<String, dynamic>> get _filteredPersonnel {
    return _allPersonnel.where((emp) {
      final name = (emp['personnel_name'] ?? '').toLowerCase();
      final type = (emp['personnel_type'] ?? '').toLowerCase();

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || type.contains(_searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == 'All' || (emp['personnel_type'] ?? '') == _selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- OPTIONS BOTTOM SHEET ---
  void _showOptionsBottomSheet(Map<String, dynamic> emp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(2))
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  emp['personnel_name'] ?? "Options",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryDark, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 20),

              _buildSheetItem(
                  icon: Icons.edit_rounded,
                  label: "Edit Details",
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToAddEdit(emp);
                  }
              ),

              _buildSheetItem(
                  icon: Icons.delete_forever_rounded,
                  label: "Remove Personnel",
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _deletePersonnel(emp['personnel_id'].toString(), emp["personnel_user_id"].toString());
                  }
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetItem({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primaryDark),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        centerTitle: false,
        title: const Text(
          "MDRRMO PERSONNEL",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Material(
              color: emergencyRed.withValues(alpha: 0.1),
              shape: const CircleBorder(),
              child: IconButton(
                icon: Icon(Icons.person_add_rounded, color: emergencyRed, size: 24),
                onPressed: () => _navigateToAddEdit(), // Navigates to Add form
                tooltip: "Add Personnel",
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: cardBorder, height: 1.0),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.isDesktop(context) ? 1200 : 840),
          child: Column(
            children: [
              // --- SEARCH & FILTER BAR ---
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(fontWeight: FontWeight.w600, color: primaryDark),
                      decoration: InputDecoration(
                        hintText: "Search name or role...",
                        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
                        prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                        filled: true,
                        fillColor: bgColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: emergencyRed, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterChip('All'),
                          _buildFilterChip('Head'),
                          _buildFilterChip('Patrol'),
                          _buildFilterChip('Medics'),
                          _buildFilterChip('Driver'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- PERSONNEL LIST ---
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: emergencyRed))
                    : RefreshIndicator(
                  onRefresh: _fetchPersonnel,
                  color: emergencyRed,
                  backgroundColor: Colors.white,
                  child: _filteredPersonnel.isEmpty
                      ? _buildEmptyState()
                      : Responsive(
                    mobile: ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 40),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: _filteredPersonnel.length,
                      itemBuilder: (context, index) => _buildEmployeeCard(_filteredPersonnel[index]),
                    ),
                    tablet: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: _filteredPersonnel.length,
                      itemBuilder: (context, index) => _buildEmployeeCard(_filteredPersonnel[index]),
                    ),
                    desktop: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 2.0,
                      ),
                      itemCount: _filteredPersonnel.length,
                      itemBuilder: (context, index) => _buildEmployeeCard(_filteredPersonnel[index]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : textSecondary,
            fontSize: 13,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = label),
        backgroundColor: Colors.white,
        selectedColor: primaryDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // --- PREMIUM EMPLOYEE CARD ---
  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final String status = emp['personnel_status'] ?? 'Unknown';
    Color statusColor;
    IconData statusIcon;

    if (status.toLowerCase() == 'duty') {
      statusColor = statusDuty;
      statusIcon = Icons.verified_user_rounded;
    } else if (status.toLowerCase() == 'leave') {
      statusColor = statusLeave;
      statusIcon = Icons.flight_takeoff_rounded;
    } else {
      statusColor = statusDismissed;
      statusIcon = Icons.block_rounded;
    }

    final String name = emp['personnel_name'] ?? 'Unknown Name';
    final String type = emp['personnel_type'] ?? 'No Role';
    final String email = emp['personnel_email'] ?? 'No Email';
    final String municipality = _getMunicipalityName(emp['personnel_municipality']);

    return Container(
      margin: Responsive.isMobile(context) ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.0), // Clean, uniform border
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showOptionsBottomSheet(emp),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOP SECTION: Avatar, Name, Role & Status Pill ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Tinted Avatar based on status color
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.1),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(name),
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 1.0
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Main Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type.toUpperCase(),
                            style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Status Pill (Moved to top right)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // --- BOTTOM SECTION: Details inside subtle container ---
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor, // Soft gray background to separate info
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Details List
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.email_rounded, size: 14, color: textSecondary.withValues(alpha: 0.8)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 14, color: textSecondary.withValues(alpha: 0.8)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "MDRRMO $municipality",
                                    style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Options Button Cue
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                            ]
                        ),
                        child: Icon(Icons.more_horiz_rounded, color: primaryDark, size: 18),
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: primaryDark.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 10))]
            ),
            child: Icon(Icons.badge_rounded, size: 48, color: textSecondary.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            "No Personnel Found",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your search or filters.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    _classicDialog.setTitle("Something went wrong!");
    _classicDialog.setMessage(message);
    _classicDialog.setPositiveMessage("Close");
    if(mounted) _classicDialog.showOnButtonDialog(context, () => _classicDialog.dismissDialog());
  }
}
