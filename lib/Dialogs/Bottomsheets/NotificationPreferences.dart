import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/Municipalities.dart';

class NotificationPreferences {
  static Future<void> show(BuildContext context, VoidCallback onSaved) async {
    final prefs = await SharedPreferences.getInstance();

    String savedZip = prefs.getString('preferred_notification_municipality_zipcode') ?? '0000';
    String initialName = 'All Towns';

    if (savedZip != '0000') {
      try {
        initialName = Municipalities.list.firstWhere((m) => m['zip'] == savedZip)['name']!;
      } catch (_) {
        initialName = 'All Towns';
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PreferencesSheetContent(
        initialTown: initialName,
        onSaved: onSaved, // Pass the callback down
      ),
    );
  }
}

class _PreferencesSheetContent extends StatefulWidget {
  final String initialTown;
  final VoidCallback onSaved; // Added callback here
  const _PreferencesSheetContent({required this.initialTown, required this.onSaved});

  @override
  State<_PreferencesSheetContent> createState() => _PreferencesSheetContentState();
}

class _PreferencesSheetContentState extends State<_PreferencesSheetContent> {
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color accentBlue = const Color(0xFF3B82F6);

  late List<String> _towns;
  late String _selectedTown;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedTown = widget.initialTown;
    _towns = ['All Towns', ...Municipalities.getNames()];
  }

  Future<void> _savePreference() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      String zipToSave = "0000";
      if (_selectedTown != 'All Towns') {
        zipToSave = Municipalities.list.firstWhere((m) => m['name'] == _selectedTown)['zip']!;
      }

      await prefs.setString('preferred_notification_municipality_zipcode', zipToSave);

      if (mounted) {
        widget.onSaved();
        SnackbarMessenger().showSnackbar(
            context,
            SnackbarMessenger.success,
            "Preference saved!"
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error saving preference.");
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8, maxWidth: Utility().getMaxScreenSize()),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(color: outlineColor, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: accentBlue, size: 24),
                const SizedBox(width: 16),
                const Text("Location Alerts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: outlineColor),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shrinkWrap: true,
              itemCount: _towns.length,
              itemBuilder: (context, index) {
                final town = _towns[index];
                final isSelected = _selectedTown == town;

                String? zipDisplay;
                if (town != 'All Towns') {
                  zipDisplay = Municipalities.list.firstWhere((m) => m['name'] == town)['zip'];
                }

                return InkWell(
                  onTap: () => setState(() => _selectedTown = town),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? accentBlue.withValues(alpha: 0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? accentBlue : outlineColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(town, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                              if (zipDisplay != null)
                                Text("ZIP Code: $zipDisplay", style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (isSelected) Icon(Icons.check_circle_rounded, color: accentBlue, size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _isSaving ? null : _savePreference,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Save Preferences", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
