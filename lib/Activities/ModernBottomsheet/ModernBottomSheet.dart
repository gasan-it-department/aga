import 'package:flutter/material.dart';

class SheetOption {
  final IconData icon;
  final String title;
  final Color primaryColor;
  final VoidCallback onTap;
  final bool isDestructive;

  SheetOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.primaryColor = const Color(0xFF0A2E5C),
    this.isDestructive = false,
  });
}

class ModernBottomSheet {
  /// Displays a highly polished, reusable bottom sheet.
  /// Can display a list of [options] OR a custom [content] widget (like a form).
  static void show({
    required BuildContext context,
    required String title,
    String? subtitle,
    List<SheetOption>? options,
    Widget? content, // <-- NEW: Allows us to pass Forms!
  }) {
    // --- Theme Colors ---
    const Color outlineColor = Color(0xFFE2E8F0);
    const Color textPrimary = Color(0xFF1E293B);
    const Color textSecondary = Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Crucial for forms so it can expand
      builder: (sheetContext) {
        return Padding(
          // Automatically pushes the sheet up when the keyboard opens
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.only(top: 20, bottom: 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Grab Handle ---
                Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(color: outlineColor, borderRadius: BorderRadius.circular(2))
                ),
                const SizedBox(height: 24),

                // --- Dynamic Header ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textPrimary, letterSpacing: -0.5)
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500)
                        ),
                      ]
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(color: outlineColor, height: 1),

                // --- Custom Content (Forms, etc.) ---
                if (content != null) ...[
                  const SizedBox(height: 16),
                  content,
                ],

                // --- Options List ---
                if (options != null && options.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...options.map((option) {
                    final Color activeColor = option.isDestructive ? const Color(0xFFEF4444) : option.primaryColor;
                    final Color textColor = option.isDestructive ? const Color(0xFFEF4444) : textPrimary;

                    return InkWell(
                      onTap: () {
                        Navigator.pop(sheetContext); // Close sheet
                        option.onTap();              // Execute callback
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: activeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(option.icon, color: activeColor, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(option.title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 15)),
                            ),
                            Icon(Icons.chevron_right_rounded, color: textSecondary.withValues(alpha: 0.5), size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
