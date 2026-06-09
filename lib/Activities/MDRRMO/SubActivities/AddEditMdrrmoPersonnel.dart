import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../Dialogs/ClassicDialog.dart';
import '../../../Dialogs/LoadingDialog.dart';
import '../../../Utility/Utility.dart';

class AddEditMdrrmoPersonnel extends StatefulWidget {
  final Map<String, dynamic>? existingPersonnel;
  final int currentMunicipalZipCode;

  const AddEditMdrrmoPersonnel({super.key, this.existingPersonnel, required this.currentMunicipalZipCode});

  @override
  State<AddEditMdrrmoPersonnel> createState() => _AddEditMdrrmoPersonnelState();
}

class _AddEditMdrrmoPersonnelState extends State<AddEditMdrrmoPersonnel> {
  final _supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color emergencyRed = const Color(0xFFEF4444);

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  String _selectedRole = 'Patrol';
  String _selectedStatus = 'Duty';

  final List<String> _roleOptions = ['Head', 'Patrol', 'Medics', 'Driver', 'Communications', 'Logistics', 'Others'];
  final List<String> _statusOptions = ['Duty', 'Leave', 'Dismissed'];

  @override
  void initState() {
    super.initState();

    final isEditing = widget.existingPersonnel != null;
    final emp = widget.existingPersonnel;

    _nameController = TextEditingController(text: isEditing ? emp!['personnel_name'] : '');
    _emailController = TextEditingController(text: isEditing ? emp!['personnel_email'] : '');

    if (isEditing) {
      if (_roleOptions.contains(emp!['personnel_type'])) {
        _selectedRole = emp['personnel_type'];
      }
      if (_statusOptions.contains(emp['personnel_status'])) {
        _selectedStatus = emp['personnel_status'];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<bool> _isAlreadyRegistered(String emailAddress) async {
    if (widget.existingPersonnel != null) {
      final String currentEmail = widget.existingPersonnel!['personnel_email'] ?? '';
      if (emailAddress.trim() == currentEmail) return false;
    }

    try {
      var response = await _supabase
          .from('mdrrmo_personnels')
          .select('personnel_id')
          .eq('personnel_email', emailAddress)
          .limit(1);
      return response.isNotEmpty;
    } catch (error) {
      Utility().printLog("Error checking personnel existence: $error");
      return false;
    }
  }

  Future<void> _savePersonnel() async {
    if (_nameController.text.trim().isEmpty) {
      _showError("Personnel name is required.");
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showError("Email address is required.");
      return;
    }

    _loadingDialog.showLoadingDialog(context);
    final targetEmail = _emailController.text.trim();

    final userData = await _supabase
        .from('user_data')
        .select('user_id, limited_notifications, user_access')
        .eq('user_account', targetEmail)
        .maybeSingle();

    if (userData == null) {
      _loadingDialog.dismiss();
      _showError("Account for $targetEmail not found. Personnel must register an account first.");
      return;
    }

    final dynamic rawAccess = userData["user_access"];
    Utility().printLog("User access raw data: $rawAccess");

    if (rawAccess != null && rawAccess is Map) {
      if (rawAccess["access"] != null && rawAccess["access"] is List) {
        List<String> userAccessList = List<String>.from(rawAccess["access"]);
        Utility().printLog("Extracted Access List: $userAccessList");
        if(userAccessList.contains("mdrrmo")){
          _loadingDialog.dismiss();
          _classicDialog.setTitle("Oops!");
          _classicDialog.setMessage("$targetEmail is already an MDRRMO administrator.");
          _classicDialog.setCancelable(false);
          _classicDialog.setPositiveMessage("Close");
          if(mounted){
            _classicDialog.showOnButtonDialog(context, (){
              _classicDialog.dismissDialog();

            });
          }
          return;
        }
      } else {
        Utility().printLog("No access list found inside user_access.");
      }

      String userType = rawAccess["user_type"]?.toString() ?? "";
      Utility().printLog("User Type: $userType");
    }

    _loadingDialog.dismiss();
    _classicDialog.setTitle("Confirm");
    _classicDialog.setMessage("Are you sure you want to register $targetEmail as a MDRRMO personnel?");
    _classicDialog.setCancelable(false);
    _classicDialog.setPositiveMessage("Register");
    _classicDialog.setNegativeMessage("Cancel");
    if(mounted){
      _classicDialog.showTwoButtonDialog(context, (negativeClick){
        _classicDialog.dismissDialog();

      }, (positiveClicked) async {
        _classicDialog.dismissDialog();

        _loadingDialog.showLoadingDialog(context);
        if (await _isAlreadyRegistered(targetEmail)) {
          _loadingDialog.dismiss();
          _showError("$targetEmail is already registered as an MDRRMO personnel.");
        return;
        }

        final isEditing = widget.existingPersonnel != null;
        final Map<String, dynamic> personnelData = {
          'personnel_name': _nameController.text.trim(),
          'personnel_email': targetEmail,
          'personnel_type': _selectedRole,
          'personnel_status': _selectedStatus,
        };

        try {
          if (isEditing) {
            await _supabase
                .from('mdrrmo_personnels')
                .update(personnelData)
                .eq('personnel_id', widget.existingPersonnel!['personnel_id']);
          } else {
            personnelData['personnel_id'] = Utility().generateUniqueID();
            personnelData['personnel_date_registered'] = Utility().getCurrentMSEpochTime();
            personnelData['personnel_municipality'] = widget.currentMunicipalZipCode;
            personnelData["personnel_user_id"] = userData["user_id"].toString();

            await _supabase.from('mdrrmo_personnels').insert(personnelData);

            List<String> access = ["mdrrmo_personnel"];
            final Map<String, dynamic> userAccess = {
              "access": access,
              "municipality_zip_code": widget.currentMunicipalZipCode,
            };

            await _supabase.from("user_data").update({"user_access": userAccess}).eq("user_id", userData["user_id"].toString());
          }

          final String targetUserId = userData['user_id'];
          final rawNotification = userData["limited_notifications"];
          Utility().printLog("Raw personal notifications: $rawNotification");

          List personalNotificationList = [];
          if(rawNotification != null){
            personalNotificationList = rawNotification;
          }

          Map<String, dynamic> newNotification = {
            'id': Utility().generateUniqueID(),
            'title': isEditing ? 'Personnel Profile Updated' : 'Registered as Personnel',
            'message': isEditing
                ? 'Your MDRRMO profile has been updated to $_selectedRole.'
                : 'You have been registered as an active $_selectedRole for the MDRRMO.',
            'date_sent': Utility().getCurrentMSEpochTime(),
          };

          personalNotificationList.insert(0, newNotification);

          if (personalNotificationList.length > 1500) {
            personalNotificationList = personalNotificationList.sublist(0, 1500);
          }

          await _supabase
              .from('user_data')
              .update({'limited_notifications': personalNotificationList})
              .eq('user_id', targetUserId);

          if (mounted) {
            _loadingDialog.dismiss();
            Navigator.pop(context, true);
          }

        } catch (e) {
          if (mounted) _loadingDialog.dismiss();
          _showError("Failed to save personnel: $e");
        }
      });
    }
  }

  void _showError(String message) {
    Utility().printLog("Error: $message");
    _classicDialog.setTitle("Error");
    _classicDialog.setMessage(message);
    _classicDialog.setCancelable(false);
    _classicDialog.setPositiveMessage("Close");
    if (mounted) {
      _classicDialog.showOnButtonDialog(context, () {
        _classicDialog.dismissDialog();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPersonnel != null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
            isEditing ? "EDIT PERSONNEL" : "ADD PERSONNEL",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5)
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: cardBorder, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: primaryDark.withValues(alpha: 0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Form Header ---
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: emergencyRed.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(isEditing ? Icons.manage_accounts_rounded : Icons.person_add_rounded, color: emergencyRed, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    isEditing ? "Update Records" : "Register Personnel",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5)
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    "Manage MDRRMO database details.",
                                    style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      ),

                      // --- Section: Personal Info ---
                      _buildSectionTitle(Icons.badge_rounded, "PERSONAL INFORMATION"),
                      const SizedBox(height: 16),

                      _buildTextField(_nameController, "Full Name", Icons.person_rounded),
                      const SizedBox(height: 12),
                      _buildTextField(_emailController, "Email Address", Icons.email_rounded, keyboardType: TextInputType.emailAddress),

                      const SizedBox(height: 28),

                      // --- Section: Assignment Details ---
                      _buildSectionTitle(Icons.work_rounded, "ASSIGNMENT DETAILS"),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown<String>(
                              label: "Role",
                              icon: Icons.shield_rounded,
                              value: _selectedRole,
                              items: _roleOptions.map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r, style: TextStyle(fontWeight: FontWeight.w600, color: primaryDark, fontSize: 13))
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedRole = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown<String>(
                              label: "Status",
                              icon: Icons.health_and_safety_rounded,
                              value: _selectedStatus,
                              items: _statusOptions.map((s) {
                                Color statusColor = s == 'Duty' ? const Color(0xFF10B981) : s == 'Leave' ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8);
                                return DropdownMenuItem(
                                  value: s,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Flexible(child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: primaryDark, fontSize: 13))),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedStatus = val);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // --- Save Button ---
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: emergencyRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: _savePersonnel,
                          icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                          label: Text(
                              isEditing ? "SAVE CHANGES" : "REGISTER PERSONNEL",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                          ),
                        ),
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

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: textSecondary.withValues(alpha: 0.7)),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: emergencyRed, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildDropdown<T>({required String label, required IconData icon, required T value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged}) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: textSecondary),
      isExpanded: true,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: textSecondary.withValues(alpha: 0.7)),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: emergencyRed, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
