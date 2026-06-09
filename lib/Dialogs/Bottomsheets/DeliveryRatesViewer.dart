import 'package:flutter/material.dart';
import '../../Utility/Utility.dart';

class DeliveryRatesViewer extends StatelessWidget {
  final List<Map<String, dynamic>> rates;
  final String? merchant;

  const DeliveryRatesViewer({super.key, required this.rates, this.merchant});

  static const Color primaryDark = Color(0xFF0F172A);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color softBg = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF64748B);

  static Future<void> show(BuildContext context, {required List<Map<String, dynamic>> rates, String? merchant}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeliveryRatesViewer(rates: rates, merchant: merchant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final util = Utility();
    final sorted = [...rates]..sort((a, b) {
      final av = (a['rate_amount'] as num?)?.toDouble() ?? 0;
      final bv = (b['rate_amount'] as num?)?.toDouble() ?? 0;
      return av.compareTo(bv);
    });

    final double minRate = sorted.isEmpty ? 0 : (sorted.first['rate_amount'] as num).toDouble();
    final double maxRate = sorted.isEmpty ? 0 : (sorted.last['rate_amount'] as num).toDouble();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 44, height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryBlue, primaryBlue.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Delivery Rates",
                            style: TextStyle(color: primaryDark, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                          ),
                          Text(
                            merchant != null && merchant!.isNotEmpty
                                ? "from $merchant"
                                : "${sorted.length} delivery area${sorted.length == 1 ? '' : 's'}",
                            style: const TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: primaryDark),
                      style: IconButton.styleFrom(
                        backgroundColor: softBg,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              if (sorted.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(
                    children: [
                      Expanded(child: _summary("Cheapest", "₱${util.formatPrice(minRate)}", accentGreen, Icons.trending_down_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _summary("Highest", "₱${util.formatPrice(maxRate)}", const Color(0xFFEF4444), Icons.trending_up_rounded)),
                    ],
                  ),
                ),
              const Divider(height: 1, color: border),
              Expanded(
                child: sorted.isEmpty
                    ? _empty()
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildRateTile(sorted[i], i, util),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summary(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateTile(Map<String, dynamic> rate, int index, Utility util) {
    final amount = (rate['rate_amount'] as num?)?.toDouble() ?? 0;
    final label = rate['rate_label']?.toString() ?? 'Unknown Area';
    final isCheapest = index == 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCheapest ? accentGreen.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCheapest ? accentGreen.withValues(alpha: 0.35) : border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (isCheapest ? accentGreen : primaryBlue).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.place_rounded,
              color: isCheapest ? accentGreen : primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: primaryDark, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isCheapest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("BEST",
                          style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 11, color: textSecondary),
                    const SizedBox(width: 3),
                    Text("Standard delivery",
                      style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("₱${util.formatPrice(amount)}",
                style: TextStyle(
                  color: isCheapest ? accentGreen : primaryDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text("per delivery",
                style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined, size: 48, color: textSecondary),
            SizedBox(height: 12),
            Text("No delivery rates available",
              style: TextStyle(color: primaryDark, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
