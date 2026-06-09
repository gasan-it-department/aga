import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/Municipalities.dart';
import 'package:gasan_port_tracker/Map/BorderWelcome.dart';

class ChangeBorderPreferences {
  static Future<void> show(BuildContext context, VoidCallback onSaved) async {
    final prefs = await SharedPreferences.getInstance();

    int savedZip = prefs.getInt('current_zip_code') ?? 0;
    String initialName = 'Auto-Detect';

    if (prefs.getBool("isBorderChangeAuto") == false) {
      try {
        initialName = Municipalities.list.firstWhere((m) => int.parse(m['zip'].toString()) == savedZip)['name']!;
      } catch (_) {
        initialName = 'Auto-Detect';
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
    _towns = ['Auto-Detect', ...Municipalities.getNames()];
  }

  Future<void> _savePreference() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String previousMuni = prefs.getString('current_municipality') ?? '';

      int zipToSave = 0;
      String municipalNameToSave = "";
      bool isAuto = false;
      if (_selectedTown != 'Auto-Detect') {
        zipToSave = int.parse(Municipalities.list.firstWhere((m) => m['name'] == _selectedTown)['zip']!);
        municipalNameToSave = Municipalities.list.firstWhere((m) => m['name'] == _selectedTown)['name']!;
        await prefs.setBool("isBorderChangeAuto", false);
      }else{
        isAuto = true;
        await prefs.setBool("isBorderChangeAuto", true);
      }

      if (isAuto) {
        // Wipe so Home auto-detect re-evaluates as a new border.
        await prefs.setInt('current_zip_code', 0);
        await prefs.setString('current_municipality', '');
      } else {
        await prefs.setInt('current_zip_code', zipToSave);
        await prefs.setString('current_municipality', municipalNameToSave);
      }

      Utility().printLog("Saved zip code: $zipToSave");
      Utility().printLog("Municipal name to save: $municipalNameToSave");

      if (mounted) {
        widget.onSaved();
        SnackbarMessenger().showSnackbar(
            context,
            SnackbarMessenger.success,
            "Preference saved!"
        );
        final rootNav = Navigator.of(context, rootNavigator: true);
        Navigator.pop(context);

        if (!isAuto && municipalNameToSave.isNotEmpty && municipalNameToSave != previousMuni) {
          rootNav.push(
            MaterialPageRoute(
              builder: (welcomeCtx) => BorderWelcome(
                municipalityName: municipalNameToSave,
                onProceed: () => Navigator.of(welcomeCtx).pop(),
              ),
            ),
          );
        }
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
                Icon(Icons.map, color: accentBlue, size: 24),
                const SizedBox(width: 16),
                const Text("Change Border", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
                if (town != 'Auto-Detect') {
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
