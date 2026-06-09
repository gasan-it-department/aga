import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class AddEditMdrrmoNotification {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isEditMode = false;
  bool _isSubmitting = false;

  void showBottomSheet(
      BuildContext mainContext,
      Map<String, dynamic>? editNotificationData,
      String userName,
      String userId,
      String assignedPort,
      int originZipCode,
      VoidCallback onSuccess) {

    if (editNotificationData != null) {
      _isEditMode = true;
      _titleController.text = editNotificationData["notification_title"].toString();
      _messageController.text = editNotificationData["notification_message"].toString();
    } else {
      _isEditMode = false;
      _titleController.text = "";
      _messageController.text = "";
    }

    _isSubmitting = false;

    // --- UPDATED: MDRRMO Theme Colors ---
    final Color bgColor = const Color(0xFFF8FAFC);
    final Color outlineColor = const Color(0xFFE2E8F0);
    final Color emergencyRed = const Color(0xFFDC2626); // Swapped to MDRRMO Red

    Utility().printLog("User name: $userName");
    Utility().printLog("User id: $userId");
    Utility().printLog("User assigned port: $assignedPort");

    showModalBottomSheet(
      useSafeArea: true,
      isDismissible: false,
      enableDrag: true,
      isScrollControlled: true,
      context: mainContext,
      backgroundColor: Colors.transparent,
      builder: (BuildContext dialogContext) { // Explicitly named dialogContext

        return PopScope(
          canPop: !_isSubmitting,
          child: StatefulBuilder(builder: (stateContext, setState) { // Explicitly named stateContext
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(stateContext).viewInsets.bottom),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- DRAG HANDLE ---
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 5,
                                  margin: const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    color: outlineColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),

                              // --- HEADER ---
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: emergencyRed.withValues(alpha: 0.1),
                                        shape: BoxShape.circle
                                    ),
                                    child: Icon(Icons.campaign_rounded, color: emergencyRed),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    _isEditMode ? "Edit Broadcast" : "New Broadcast",
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              const Text("Headline", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _titleController,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  hintText: "e.g., EMERGENCY ALERT",
                                  filled: true,
                                  fillColor: bgColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: outlineColor)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: emergencyRed)),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                              ),
                              const SizedBox(height: 20),

                              const Text("Message Body", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _messageController,
                                maxLines: 5,
                                style: const TextStyle(fontSize: 14, height: 1.4),
                                decoration: InputDecoration(
                                  hintText: "Enter the full details here...",
                                  filled: true,
                                  fillColor: bgColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: outlineColor)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: emergencyRed)),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                              ),

                              const SizedBox(height: 32),

                              // --- EQUAL SIZED ACTION BUTTONS ---
                              Row(
                                children: [
                                  // --- CANCEL BUTTON ---
                                  Expanded(
                                    child: InkWell(
                                      onTap: _isSubmitting ? null : () => Navigator.pop(stateContext),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: outlineColor)
                                        ),
                                        child: const Text(
                                          "Cancel",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // --- SAVE/BROADCAST BUTTON ---
                                  Expanded(
                                    child: InkWell(
                                      onTap: _isSubmitting ? null : () async {
                                        if (!_formKey.currentState!.validate()) return;

                                        setState(() => _isSubmitting = true);

                                        try {
                                          final supabase = Supabase.instance.client;
                                          final Map<String, dynamic> payload = {
                                            'notification_title': _titleController.text.trim(),
                                            'notification_message': _messageController.text.trim(),
                                          };

                                          if (_isEditMode) {
                                            await supabase
                                                .from('global_notification')
                                                .update(payload)
                                                .eq('notification_id', editNotificationData!['notification_id']);


                                            if (stateContext.mounted) SnackbarMessenger().showSnackbar(stateContext, SnackbarMessenger.success, "Alert Updated!");
                                          } else {
                                            payload["notification_source"] = "mdrrmo";
                                            payload["notification_id"] = Utility().generateUniqueID();
                                            payload["notification_date"] = Utility().getCurrentMSEpochTime();
                                            payload["notification_origin_zipcode"] = originZipCode;

                                            await supabase.from('global_notification').insert(payload);

                                            if (stateContext.mounted) SnackbarMessenger().showSnackbar(stateContext, SnackbarMessenger.success, "Alert Broadcasted!");
                                          }

                                          // FIX: Safe dismissal and callback using the local dialog context
                                          if (stateContext.mounted) {
                                            onSuccess();
                                            Navigator.pop(stateContext);
                                          }
                                        } catch (e) {
                                          Utility().printLog("Error processing mdrrmo notification: $e");
                                          if (stateContext.mounted) SnackbarMessenger().showSnackbar(stateContext, SnackbarMessenger.failed, "Error: $e");
                                        } finally {
                                          if (stateContext.mounted) {
                                            setState(() => _isSubmitting = false);
                                          }
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                            color: emergencyRed, // Use Red for MDRRMO button
                                            borderRadius: BorderRadius.circular(16)
                                        ),
                                        child: _isSubmitting
                                            ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                                            : Text(
                                          _isEditMode ? "Save Changes" : "Broadcast",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
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
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
