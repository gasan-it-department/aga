import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/Seller/Checkout.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MultiShopCheckout extends StatefulWidget {
  const MultiShopCheckout({super.key, required this.selectedItems});

  final List<Map<String, dynamic>> selectedItems;

  @override
  State<MultiShopCheckout> createState() => _MultiShopCheckoutState();
}

class _MultiShopCheckoutState extends State<MultiShopCheckout> {
  final _supabase = Supabase.instance.client;

  static const _bg = Color(0xFFF8FAFC);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _orange = Color(0xFFEE4D2D);

  bool _loading = true;
  Map<String, Map<String, dynamic>> _sellers = {};
  Map<String, dynamic>? _defaultAddress;

  Map<String, List<Map<String, dynamic>>> get _groups {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final raw in widget.selectedItems) {
      final item = _itemOf(raw);
      final sellerId =
          item['item_seller_id']?.toString() ?? item['seller_id']?.toString();
      if (sellerId == null || sellerId.isEmpty) continue;
      groups.putIfAbsent(sellerId, () => []).add(raw);
    }
    return groups;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = _groups.keys.toList();
      final user = _supabase.auth.currentUser;
      final sellerRows = ids.isEmpty
          ? <dynamic>[]
          : await _supabase
                .from('sellers')
                .select(
                  'seller_id, seller_store_name, seller_logo, seller_delivery_rates, seller_preferences, seller_store_status',
                )
                .inFilter('seller_id', ids);
      final userData = user == null
          ? null
          : await _supabase
                .from('user_data')
                .select('user_delivery_address')
                .eq('user_id', user.id)
                .maybeSingle();
      final sellers = <String, Map<String, dynamic>>{};
      for (final raw in sellerRows) {
        final seller = Map<String, dynamic>.from(raw);
        sellers[seller['seller_id'].toString()] = seller;
      }
      Map<String, dynamic>? address;
      if (userData != null) {
        final raw = userData['user_delivery_address'];
        if (raw is List && raw.isNotEmpty) {
          final addresses = raw
              .whereType<Map>()
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
          if (addresses.isNotEmpty) {
            address = addresses.firstWhere(
              (a) => a['is_default'] == true,
              orElse: () => addresses.first,
            );
          }
        } else if (raw is Map) {
          address = Map<String, dynamic>.from(raw);
        }
      }
      if (mounted) {
        setState(() {
          _sellers = sellers;
          _defaultAddress = address;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to prepare checkout: $e')),
        );
      }
    }
  }

  Map<String, dynamic> _itemOf(Map<String, dynamic> raw) {
    final item = raw['store_items'];
    return item is Map
        ? Map<String, dynamic>.from(item)
        : Map<String, dynamic>.from(raw);
  }

  num _lineTotal(Map<String, dynamic> raw) {
    final item = _itemOf(raw);
    final variation = raw['cart_variation'];
    final price =
        num.tryParse(
          ((variation is Map ? variation['price'] : null) ??
                  item['item_price'] ??
                  0)
              .toString(),
        ) ??
        0;
    final quantity = num.tryParse(raw['cart_quantity']?.toString() ?? '1') ?? 1;
    return price * quantity;
  }

  num _subtotal(List<Map<String, dynamic>> items) =>
      items.fold<num>(0, (sum, item) => sum + _lineTotal(item));

  String _norm(dynamic value) => (value ?? '').toString().trim().toLowerCase();

  num? _deliveryFee(Map<String, dynamic> seller) {
    if (_defaultAddress == null) return null;
    final rawRates = seller['seller_delivery_rates'];
    if (rawRates is! List) return null;
    for (final raw in rawRates.whereType<Map>()) {
      if (_norm(raw['rate_municipality']) ==
              _norm(_defaultAddress!['municipality']) &&
          _norm(raw['rate_barangay']) == _norm(_defaultAddress!['barangay'])) {
        return num.tryParse(raw['rate_amount']?.toString() ?? '0') ?? 0;
      }
    }
    return null;
  }

  num get _selectedSubtotal =>
      _groups.values.fold<num>(0, (sum, items) => sum + _subtotal(items));

  num get _estimatedFees => _groups.entries.fold<num>(0, (sum, entry) {
    final seller = _sellers[entry.key];
    return sum + (seller == null ? 0 : (_deliveryFee(seller) ?? 0));
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checkout by Shop',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              'Each shop receives a separate order',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  _infoBanner(),
                  const SizedBox(height: 16),
                  ..._groups.entries.map(
                    (entry) => _shopCard(entry.key, entry.value),
                  ),
                  const SizedBox(height: 4),
                  _overallSummary(),
                ],
              ),
            ),
    );
  }

  Widget _infoBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      border: Border.all(color: const Color(0xFFBFDBFE)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Items from the same shop share one delivery fee. Items from different shops are checked out separately and each shop may charge its own delivery fee.',
            style: TextStyle(color: Color(0xFF1E3A8A), height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _shopCard(String sellerId, List<Map<String, dynamic>> items) {
    final seller = _sellers[sellerId] ?? <String, dynamic>{};
    final name = seller['seller_store_name']?.toString() ?? 'Unknown shop';
    final fee = _deliveryFee(seller);
    final subtotal = _subtotal(items);
    final visible = seller['seller_store_status']?.toString() == 'visible';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _bg,
                backgroundImage:
                    seller['seller_logo']?.toString().isNotEmpty == true
                    ? NetworkImage(seller['seller_logo'].toString())
                    : null,
                child: seller['seller_logo']?.toString().isNotEmpty == true
                    ? null
                    : const Icon(Icons.storefront_rounded, color: _muted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${items.length} item(s)',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          const Divider(height: 24),
          ...items.map((raw) {
            final item = _itemOf(raw);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item['item_name']?.toString() ?? 'Item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₱${Utility().formatPrice(_lineTotal(raw))}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 24),
          _row('Shop subtotal', subtotal),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('One delivery fee', style: TextStyle(color: _muted)),
              const Spacer(),
              Text(
                _defaultAddress == null
                    ? 'Choose during checkout'
                    : fee == null
                    ? 'Address not covered'
                    : '₱${Utility().formatPrice(fee)}',
                style: TextStyle(
                  color: fee == null ? _muted : _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: !visible
                ? null
                : () async {
                    final completed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Checkout(
                          selectedItems: items,
                          totalAmount: subtotal,
                          returnToPreviousAfterOrder: true,
                        ),
                      ),
                    );
                    if (completed == true && mounted) {
                      setState(() {
                        widget.selectedItems.removeWhere(
                          (raw) =>
                              items.any((item) => identical(item, raw)) ||
                              items.any(
                                (item) =>
                                    item['cart_id']?.toString() ==
                                    raw['cart_id']?.toString(),
                              ),
                        );
                      });
                      if (_groups.isEmpty) {
                        Navigator.pop(context, true);
                      } else {
                        await _load();
                      }
                    }
                  },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              visible ? 'Continue with $name' : 'Shop unavailable',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overallSummary() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        _row('Selected subtotal', _selectedSubtotal),
        const SizedBox(height: 8),
        _row('Estimated delivery fees', _estimatedFees),
        const SizedBox(height: 8),
        _row('Voucher discount', 0),
        const Divider(height: 24),
        _row(
          'Estimated total',
          _selectedSubtotal + _estimatedFees,
          strong: true,
        ),
      ],
    ),
  );

  Widget _row(String label, num value, {bool strong = false}) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: strong ? _ink : _muted,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
      Text(
        '₱${Utility().formatPrice(value)}',
        style: TextStyle(
          color: strong ? _orange : _ink,
          fontSize: strong ? 18 : 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}
