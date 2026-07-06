import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceAllOrders extends StatefulWidget {
  const MarketplaceAllOrders({super.key});

  @override
  State<MarketplaceAllOrders> createState() => _MarketplaceAllOrdersState();
}

class _MarketplaceAllOrdersState extends State<MarketplaceAllOrders> {
  final _supabase = Supabase.instance.client;
  final _search = TextEditingController();

  static const _bg = Color(0xFFF6F8FB);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE4E7EC);
  static const _blue = Color(0xFF2563EB);

  bool _loading = true;
  String _status = 'all';
  String _query = '';
  List<Map<String, dynamic>> _orders = [];

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
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _supabase.from('orders').select().order('order_id', ascending: false),
        _supabase
            .from('sellers')
            .select('seller_id, seller_store_name, seller_logo'),
        _supabase.from('user_data').select('user_id, user_name'),
      ]);
      final sellers = {
        for (final row in results[1] as List)
          row['seller_id'].toString(): Map<String, dynamic>.from(row),
      };
      final users = {
        for (final row in results[2] as List)
          row['user_id'].toString(): Map<String, dynamic>.from(row),
      };
      final grouped = <String, Map<String, dynamic>>{};
      for (final raw in results[0] as List) {
        final row = Map<String, dynamic>.from(raw);
        final id = _groupOrderId(row);
        if (id.isEmpty) continue;
        final entry = grouped.putIfAbsent(id, () {
          final sellerId = row['order_seller_id']?.toString() ?? '';
          final buyerId = row['order_user_id']?.toString() ?? '';
          return {
            ...row,
            '_seller': sellers[sellerId] ?? <String, dynamic>{},
            '_buyer': users[buyerId] ?? <String, dynamic>{},
            '_subtotal': 0.0,
            '_delivery_fee': _deliveryFee(row),
            '_total': 0.0,
            '_quantity': 0.0,
            '_lines': 0,
          };
        });
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
      if (mounted) {
        setState(() {
          _orders = grouped.values.toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load marketplace orders: $e')),
        );
      }
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

  List<Map<String, dynamic>> get _filtered => _orders.where((order) {
    final status = order['order_status']?.toString().toLowerCase() ?? 'placed';
    final seller = order['_seller'] as Map<String, dynamic>;
    final buyer = order['_buyer'] as Map<String, dynamic>;
    final text = [
      order['order_id'],
      seller['seller_store_name'],
      buyer['user_name'],
    ].join(' ').toLowerCase();
    return (_status == 'all' || status == _status) &&
        text.contains(_query.toLowerCase());
  }).toList();

  int _count(String status) => _orders
      .where((o) => o['order_status']?.toString().toLowerCase() == status)
      .length;

  num get _completedSales => _orders
      .where((o) => o['order_status']?.toString().toLowerCase() == 'completed')
      .fold<num>(0, (sum, order) => sum + (order['_total'] as num));

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
              'All Marketplace Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              'Orders across every local shop',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 900 ? 32.0 : 16.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 40),
              children: [
                _summary(),
                const SizedBox(height: 20),
                _controls(),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('No matching orders found.')),
                  )
                else
                  ..._filtered.map(_orderCard),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summary() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 850
          ? 4
          : constraints.maxWidth >= 500
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metric(
            'All orders',
            '${_orders.length}',
            Icons.receipt_long_rounded,
            _blue,
            width,
          ),
          _metric(
            'Needs action',
            '${_count('placed')}',
            Icons.new_releases_outlined,
            const Color(0xFFF59E0B),
            width,
          ),
          _metric(
            'Completed',
            '${_count('completed')}',
            Icons.task_alt_rounded,
            const Color(0xFF16A36A),
            width,
          ),
          _metric(
            'Completed sales',
            'PHP ${_money(_completedSales)}',
            Icons.payments_outlined,
            const Color(0xFF7C3AED),
            width,
          ),
        ],
      );
    },
  );

  Widget _metric(
    String label,
    String value,
    IconData icon,
    Color color,
    double width,
  ) => Container(
    width: width,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _controls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _search,
        onChanged: (value) => setState(() => _query = value.trim()),
        decoration: InputDecoration(
          hintText: 'Search order ID, buyer, or shop',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: _statuses
              .map((s) => ButtonSegment(value: s, label: Text(_label(s))))
              .toList(),
          selected: {_status},
          onSelectionChanged: (value) => setState(() => _status = value.first),
        ),
      ),
    ],
  );

  Widget _orderCard(Map<String, dynamic> order) {
    final seller = order['_seller'] as Map<String, dynamic>;
    final buyer = order['_buyer'] as Map<String, dynamic>;
    final status = order['order_status']?.toString().toLowerCase() ?? 'placed';
    final date = _orderDate(order['order_id']?.toString() ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    order['order_id']?.toString() ?? 'Unknown order',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  _badge(status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                seller['seller_store_name']?.toString() ?? 'Unknown shop',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Buyer: ${buyer['user_name'] ?? 'Unknown buyer'}',
                style: const TextStyle(color: _muted),
              ),
              if (date != null)
                Text(date, style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          );
          final totals = Column(
            crossAxisAlignment: constraints.maxWidth >= 650
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                'PHP ${_money(order['_total'] as num)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              Text(
                '${_number(order['_quantity'] as num)} item(s) across ${order['_lines']} line(s)',
                style: const TextStyle(color: _muted),
              ),
            ],
          );
          return constraints.maxWidth >= 650
              ? Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    totals,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [info, const Divider(height: 28), totals],
                );
        },
      ),
    );
  }

  Widget _badge(String status) {
    final color = status == 'completed'
        ? const Color(0xFF16A36A)
        : status == 'cancelled'
        ? const Color(0xFFE5484D)
        : status == 'placed'
        ? const Color(0xFFF59E0B)
        : _blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _label(String value) => value
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
  String _money(num value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
  String _number(num value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  String? _orderDate(String id) {
    final micros = int.tryParse(id.replaceFirst('ORDER_', ''));
    if (micros == null) return null;
    final date = DateTime.fromMicrosecondsSinceEpoch(micros);
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.month}/${date.day}/${date.year} at $hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}
