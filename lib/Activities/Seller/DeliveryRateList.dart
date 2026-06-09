import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Utility/Responsive.dart';
import '../../Utility/Utility.dart';
import '../../Dialogs/Bottomsheets/AddEditDeliveryRate.dart';
import '../../Dialogs/LoadingDialog.dart';

class DeliveryRateList extends StatefulWidget {
  final String sellerId;
  const DeliveryRateList({super.key, required this.sellerId});

  @override
  State<DeliveryRateList> createState() => _DeliveryRateListState();
}

class _DeliveryRateListState extends State<DeliveryRateList> {
  final _supabase = Supabase.instance.client;
  final _loadingDialog = LoadingDialog();

  final Color primaryDark = const Color(0xFF0F172A);
  final Color primaryBlue = const Color(0xFF2563EB);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color textSecondary = const Color(0xFF64748B);

  List<Map<String, dynamic>> _deliveryRates = [];
  num _minOrder = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    try {
      final res = await _supabase
          .from('sellers')
          .select('seller_delivery_rates, seller_preferences')
          .eq('seller_id', widget.sellerId)
          .maybeSingle();

      final prefs = res?['seller_preferences'];
      if (prefs is Map) {
        _minOrder = (prefs['delivery_min_order'] as num?)?.toDouble() ?? 0;
      }

      final raw = res?['seller_delivery_rates'];
      final List<Map<String, dynamic>> parsed = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      parsed.sort((a, b) {
        final ad = (a['rate_date_added'] as num?)?.toDouble() ?? 0;
        final bd = (b['rate_date_added'] as num?)?.toDouble() ?? 0;
        return bd.compareTo(ad);
      });

      if (mounted) {
        setState(() {
          _deliveryRates = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching rates: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _persistRates(List<Map<String, dynamic>> rates) async {
    await _supabase
        .from('sellers')
        .update({'seller_delivery_rates': rates})
        .eq('seller_id', widget.sellerId);
  }

  Future<void> _persistMinOrder(num value) async {
    final res = await _supabase
        .from('sellers')
        .select('seller_preferences')
        .eq('seller_id', widget.sellerId)
        .maybeSingle();
    final prev = res?['seller_preferences'];
    final Map<String, dynamic> merged =
        prev is Map ? Map<String, dynamic>.from(prev) : <String, dynamic>{};
    merged['delivery_min_order'] = value;
    await _supabase
        .from('sellers')
        .update({'seller_preferences': merged})
        .eq('seller_id', widget.sellerId);
  }

  void _editMinOrder() {
    final ctrl = TextEditingController(text: _minOrder > 0 ? Utility().formatPrice(_minOrder) : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        title: const Text("Minimum Order for Delivery", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Buyers must reach this subtotal to checkout with delivery. Set 0 to disable.",
                style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: "₱ ",
                hintText: "0.00",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              final v = num.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.pop(ctx);
              if (!mounted) return;
              _loadingDialog.showLoadingDialog(context);
              try {
                await _persistMinOrder(v);
                if (mounted) setState(() => _minOrder = v);
              } catch (e) {
                debugPrint("Error saving min order: $e");
              } finally {
                _loadingDialog.dismiss();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildMinOrderCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _editMinOrder,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shopping_bag_rounded, color: primaryBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Minimum Order for Delivery", style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    _minOrder > 0 ? "₱${Utility().formatPrice(_minOrder)} minimum subtotal" : "No minimum (tap to set)",
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, color: textSecondary, size: 18),
          ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddRateSheet({Map<String, dynamic>? rateItem}) {
    // Limit to 20 rates
    if (rateItem == null && _deliveryRates.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have reached the limit of 20 delivery rates.")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditDeliveryRate(
        sellerId: widget.sellerId,
        rateItem: rateItem,
        onSave: (data) async {
          try {
            final util = Utility();
            final updated = List<Map<String, dynamic>>.from(_deliveryRates);
            if (rateItem == null) {
              if (updated.length >= 20) return;
              final newItem = Map<String, dynamic>.from(data);
              newItem['rate_id'] = 'RATE_${util.generateUniqueID()}';
              newItem['rate_date_added'] = util.getCurrentMSEpochTime() / 1000;
              updated.add(newItem);
            } else {
              final idx = updated.indexWhere((r) => r['rate_id'] == rateItem['rate_id']);
              if (idx != -1) {
                final merged = Map<String, dynamic>.from(updated[idx]);
                merged.addAll(data);
                updated[idx] = merged;
              }
            }
            await _persistRates(updated);
            await _fetchRates();
          } catch (e) {
            debugPrint("Error saving rate: $e");
          }
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        title: const Text("Delivery Rates", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'add') {
                _showAddRateSheet();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add, color: Colors.black54),
                    SizedBox(width: 8),
                    Text("Add New Rate"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
        final bool isDesktop = Responsive.isDesktop(context);
        final bool isTablet = Responsive.isTablet(context);
        final double maxW = isDesktop ? 1000 : (isTablet ? 700 : 600);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Column(
              children: [
                _buildMinOrderCard(),
                Expanded(
                  child: _deliveryRates.isEmpty
                ? _buildEmptyState()
                : (isDesktop || isTablet)
                    ? GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 3 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 3,
                        ),
                        itemCount: _deliveryRates.length,
                        itemBuilder: (context, index) => _buildRateCard(_deliveryRates[index]),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _deliveryRates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildRateCard(_deliveryRates[index]),
                      ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryDark.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Icon(Icons.local_shipping_rounded, size: 72, color: primaryBlue.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 24),
                  Text("No Delivery Rates", style: TextStyle(color: primaryDark, fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    "Set your delivery fees for different areas to start accepting delivery orders.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildRateCard(Map<String, dynamic> item) {
    final util = Utility();
    final rawAdded = item['rate_date_added'];
    final int addedMs = rawAdded is num
        ? (rawAdded * 1000).toInt()
        : (num.tryParse(rawAdded?.toString() ?? '0')?.toInt() ?? 0) * 1000;
    final String dateLabel = util.formatEpochToTime(addedMs);
    final String timeAgo = util.getEpochTimeAgo(addedMs);
    final String price = util.formatPrice(item['rate_amount']);

    return InkWell(
      onTap: () => _showAddRateSheet(rateItem: item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.local_shipping_rounded, color: primaryBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item['rate_label'] ?? 'Unknown Location', style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark, fontSize: 16), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          timeAgo.isNotEmpty ? "Added $timeAgo • $dateLabel" : "Delivery Fee",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textSecondary, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₱$price", style: TextStyle(fontWeight: FontWeight.w900, color: primaryBlue, fontSize: 18)),
                Text("per delivery", style: TextStyle(color: textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
