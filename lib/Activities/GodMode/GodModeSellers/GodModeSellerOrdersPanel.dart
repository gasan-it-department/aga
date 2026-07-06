import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GodModeSellerOrdersPanel extends StatefulWidget {
  const GodModeSellerOrdersPanel({
    super.key,
    required this.sellers,
    required this.onError,
  });

  final List<Map<String, dynamic>> sellers;
  final ValueChanged<String> onError;

  @override
  State<GodModeSellerOrdersPanel> createState() => GodModeSellerOrdersPanelState();
}

class GodModeSellerOrdersPanelState extends State<GodModeSellerOrdersPanel> {
  static const _bg = Color(0xFFF8FAFC);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _primary = Color(0xFF0A2E5C);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFDC2626);

  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _scrollKey = GlobalKey();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _query = '';
  String _status = 'all';
  String? _sellerId;
  int _page = 0;

  static const int _ordersPerPage = 8;
  static const _statuses = [
    'all',
    'placed',
    'preparing',
    'ready for pickup',
    'out for delivery',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _supabase.from('orders').select().order('order_id', ascending: false),
        _supabase.from('user_data').select('user_id, user_name, user_account'),
      ]);
      final buyers = {
        for (final row in results[1] as List)
          row['user_id'].toString(): Map<String, dynamic>.from(row),
      };
      final sellers = {
        for (final seller in widget.sellers)
          seller['seller_id'].toString(): Map<String, dynamic>.from(seller),
      };
      final grouped = <String, Map<String, dynamic>>{};
      final seenRows = <String>{};
      for (final raw in results[0] as List) {
        final row = Map<String, dynamic>.from(raw);
        final rowId = row['order_id']?.toString() ?? '';
        if (rowId.isEmpty || !seenRows.add(rowId)) continue;
        final id = _groupOrderId(row);
        if (id.isEmpty) continue;
        final entry = grouped.putIfAbsent(id, () {
          final sellerId = row['order_seller_id']?.toString() ?? '';
          final buyerId = row['order_user_id']?.toString() ?? '';
          return {
            ...row,
            'order_id': id,
            'order_row_ids': <String>[],
            '_seller': sellers[sellerId] ?? <String, dynamic>{},
            '_buyer': buyers[buyerId] ?? <String, dynamic>{},
            '_subtotal': 0.0,
            '_delivery_fee': _deliveryFee(row),
            '_total': 0.0,
            '_quantity': 0.0,
            '_lines': 0,
          };
        });
        (entry['order_row_ids'] as List).add(rowId);
        final lineTotal = num.tryParse(row['order_total_price']?.toString() ?? '0') ?? 0;
        final deliveryFee = _deliveryFee(row);
        if (deliveryFee > 0) entry['_delivery_fee'] = deliveryFee;
        entry['_subtotal'] = (entry['_subtotal'] as num) + lineTotal;
        entry['_total'] = (entry['_subtotal'] as num) + (entry['_delivery_fee'] as num);
        entry['_quantity'] =
            (entry['_quantity'] as num) +
            (num.tryParse(row['order_quantity']?.toString() ?? '1') ?? 1);
        entry['_lines'] = (entry['_lines'] as int) + 1;
      }
      if (!mounted) return;
      setState(() {
        _orders = grouped.values.toList()
          ..sort(
            (a, b) => (b['order_id'] ?? '')
                .toString()
                .compareTo((a['order_id'] ?? '').toString()),
          );
        _loading = false;
        _page = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onError('Unable to load orders: $error');
    }
  }

  String _groupOrderId(Map<String, dynamic> row) {
    final groupId = row['order_group_id']?.toString().trim();
    if (groupId != null && groupId.isNotEmpty) return groupId;
    return (row['order_id']?.toString() ?? '').replaceFirst(RegExp(r'_\d+$'), '');
  }

  num _deliveryFee(Map<String, dynamic> row) {
    final metaFee = _feeFromPayload(row['order_meta_data']);
    if (metaFee > 0) return metaFee;
    return _feeFromPayload(row['order_delivery_address']);
  }

  num _feeFromPayload(dynamic raw) {
    dynamic value;
    if (raw is Map) {
      value = raw['delivery_fee'] ?? raw['shipping_fee'] ?? raw['fee'] ?? raw['rate_amount'];
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          value = decoded['delivery_fee'] ?? decoded['shipping_fee'] ?? decoded['fee'] ?? decoded['rate_amount'];
        }
      } catch (_) {}
    }
    return value is num ? value : (num.tryParse(value?.toString() ?? '0') ?? 0);
  }

  void showSeller(String sellerId) {
    setState(() {
      _sellerId = sellerId;
      _page = 0;
    });
    final context = _scrollKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.08,
      );
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _orders.where((order) {
      final status = order['order_status']?.toString().toLowerCase() ?? 'placed';
      final seller = order['_seller'] as Map<String, dynamic>? ?? {};
      final buyer = order['_buyer'] as Map<String, dynamic>? ?? {};
      final matchesSeller = _sellerId == null || order['order_seller_id']?.toString() == _sellerId;
      final text = [
        order['order_id'],
        order['order_item_name'],
        seller['seller_store_name'],
        buyer['user_name'],
        buyer['user_account'],
      ].join(' ').toLowerCase();
      return matchesSeller && (_status == 'all' || status == _status) && text.contains(_query.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> get _paged {
    final start = _page * _ordersPerPage;
    final end = (start + _ordersPerPage).clamp(0, _filtered.length);
    if (start >= _filtered.length) return const [];
    return _filtered.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final selectedSeller = _sellerId == null
        ? null
        : widget.sellers.where((seller) => seller['seller_id'].toString() == _sellerId).toList();
    final sellerName = selectedSeller == null || selectedSeller.isEmpty
        ? null
        : selectedSeller.first['seller_store_name']?.toString();
    final totalPages = (_filtered.length / _ordersPerPage).ceil().clamp(1, 9999);
    if (_page >= totalPages) _page = totalPages - 1;

    return Container(
      key: _scrollKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Orders',
                    style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sellerName == null
                        ? 'All marketplace orders, grouped by order card.'
                        : 'Showing orders for $sellerName.',
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
              if (_sellerId != null)
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _sellerId = null;
                    _page = 0;
                  }),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: const Text('Show all sellers'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _controls(width),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 46),
              child: Center(child: CircularProgressIndicator(color: _primary)),
            )
          else if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 46),
              child: Center(child: Text('No orders found.', style: TextStyle(color: _muted))),
            )
          else ...[
            ..._paged.map(_orderCard),
            _pagination(totalPages),
          ],
        ],
      ),
    );
  }

  Widget _controls(double width) {
    final search = TextField(
      controller: _searchController,
      onChanged: (value) => setState(() {
        _query = value.trim();
        _page = 0;
      }),
      decoration: InputDecoration(
        hintText: 'Search order id, item, buyer, shop',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _query = '';
                    _page = 0;
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
      ),
    );
    final statuses = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        segments: _statuses
            .map((status) => ButtonSegment(value: status, label: Text(_label(status))))
            .toList(),
        selected: {_status},
        onSelectionChanged: (value) => setState(() {
          _status = value.first;
          _page = 0;
        }),
      ),
    );
    if (width >= 900) {
      return Row(children: [Expanded(child: search), const SizedBox(width: 12), statuses]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [search, const SizedBox(height: 10), statuses]);
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final seller = order['_seller'] as Map<String, dynamic>? ?? {};
    final buyer = order['_buyer'] as Map<String, dynamic>? ?? {};
    final status = order['order_status']?.toString().toLowerCase() ?? 'placed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    order['order_id']?.toString() ?? 'Unknown order',
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
                  ),
                  _badge(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                seller['seller_store_name']?.toString() ?? 'Unknown shop',
                style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Buyer: ${buyer['user_name'] ?? buyer['user_account'] ?? 'Unknown buyer'}',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 4),
              Text(
                '${order['_lines']} line(s) - ${_number(order['_quantity'] as num)} item(s)',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          );
          final total = Column(
            crossAxisAlignment: constraints.maxWidth >= 680
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                'PHP ${_money(order['_total'] as num)}',
                style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w900),
              ),
              Text(
                order['order_payment_method']?.toString() ?? 'Payment not set',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          );
          return constraints.maxWidth >= 680
              ? Row(children: [Expanded(child: info), const SizedBox(width: 14), total])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const Divider(height: 24), total]);
        },
      ),
    );
  }

  Widget _badge(String status) {
    final color = status == 'completed'
        ? _green
        : status == 'cancelled'
        ? _red
        : status == 'placed'
        ? _amber
        : _primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(status).toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _pagination(int totalPages) {
    return Row(
      children: [
        Text(
          'Page ${_page + 1} of $totalPages - ${_filtered.length} order(s)',
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Previous page',
          onPressed: _page <= 0 ? null : () => setState(() => _page--),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: _page >= totalPages - 1 ? null : () => setState(() => _page++),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  String _label(String value) => value
      .split(' ')
      .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  String _money(num value) => value.toStringAsFixed(2);

  String _number(num value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}
