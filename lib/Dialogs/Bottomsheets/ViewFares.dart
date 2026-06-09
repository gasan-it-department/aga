import 'package:flutter/material.dart';

class ViewFares {
  /// Opens a modern, strictly non-draggable, non-cancelable bottom sheet.
  static void showBottomSheet({
    required BuildContext context,
    required String shippingLineName,
    required List<dynamic> fares,
  }) {
    const Color bgColor = Color(0xFFF8FAFC);
    const Color primaryDark = Color(0xFF0A2E5C);
    const Color textPrimary = Color(0xFF1E293B);
    const Color textSecondary = Color(0xFF64748B);
    const Color outlineColor = Color(0xFFE2E8F0);
    const Color accentBlue = Color(0xFF3B82F6);

    // Using showGeneralDialog gives absolute control over dismissal and drag physics
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Strictly prevents tapping outside to close
      barrierColor: Colors.black.withValues(alpha: 0.5), // Dim the background
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            // Wrap in Material to ensure text and styles render correctly
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: const BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // --- HEADER ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Fare Information",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    color: primaryDark,
                                  ),
                                ),
                                Text(
                                  shippingLineName,
                                  style: const TextStyle(
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Removed the X icon here since we have a big button at the bottom
                        ],
                      ),
                    ),

                    const Divider(color: outlineColor, thickness: 1),

                    // --- FARES LIST ---
                    Expanded(
                      child: fares.isEmpty
                          ? _buildEmptyState(textSecondary, outlineColor)
                          : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        itemCount: fares.length,
                        itemBuilder: (context, index) {
                          final item = fares[index];
                          final String type = item['type']?.toString().toUpperCase() ?? 'PASSENGER';

                          final String rawPrice = item['price']?.toString() ?? item['amount']?.toString() ?? '0';
                          final double parsedPrice = double.tryParse(rawPrice) ?? 0.0;
                          final String formattedAmount = parsedPrice.toStringAsFixed(2);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: outlineColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryDark.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: accentBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getIconForFareType(type),
                                    color: accentBlue,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    type,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  "₱$formattedAmount",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: primaryDark,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // --- BOTTOM CLOSE BUTTON ---
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: textPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: outlineColor, width: 2),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Close Fares",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      // This builds the slide-up animation
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  static IconData _getIconForFareType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('student')) return Icons.school_rounded;
    if (lowerType.contains('senior') || lowerType.contains('pwd')) return Icons.elderly_rounded;
    if (lowerType.contains('child') || lowerType.contains('half')) return Icons.child_care_rounded;
    if (lowerType.contains('adult') || lowerType.contains('regular')) return Icons.person_rounded;
    if (lowerType.contains('vehicle') || lowerType.contains('car') || lowerType.contains('suv')) return Icons.directions_car_rounded;
    if (lowerType.contains('motorcycle') || lowerType.contains('bike')) return Icons.two_wheeler_rounded;
    if (lowerType.contains('cargo') || lowerType.contains('truck')) return Icons.local_shipping_rounded;
    return Icons.person_outline_rounded;
  }

  static Widget _buildEmptyState(Color textSecondary, Color outlineColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: outlineColor.withValues(alpha: 0.3),
                shape: BoxShape.circle
            ),
            child: Icon(Icons.payments_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Fares Available",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Fare information has not been\nprovided for this shipping line yet.",
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
