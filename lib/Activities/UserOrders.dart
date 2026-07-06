import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../Utility/BuyerScoreService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Activities/Orders/OrderDetails.dart';

class UserOrders extends StatefulWidget {
  final String initialFilter;

  const UserOrders({super.key, this.initialFilter = 'placed'});

  @override
  State<UserOrders> createState() => _UserOrdersState();
}

class _UserOrdersState extends State<UserOrders> {
  final _supabase = Supabase.instance.client;
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color primaryBlue = const Color(0xFF2563EB);
  final Color themeOrange = const Color(0xFFEE4D2D);
  final Color bgColor = const Color(0xFFF8FAFC);

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _from = 0;
  static const int _pageSize = 40;
  int? _totalRowCount;
  final Map<String, Map<String, dynamic>> _groupedById = {};
  List<Map<String, dynamic>> _orders = [];
  late String _filter;
  String _searchQuery = '';
  Map<String, int> _statusCounts = {};
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  final ScrollController _scrollCtrl = ScrollController();

  static const List<Map<String, String>> _statuses = [
    {'key': 'all', 'label': 'All'},
    {'key': 'placed', 'label': 'Placed'},
    {'key': 'preparing', 'label': 'Preparing'},
    {'key': 'delivery_pickup', 'label': 'Delivery/Pickup'},
    {'key': 'completed', 'label': 'Completed'},
    {'key': 'cancelled', 'label': 'Cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _filter = _statuses.any((status) => status['key'] == widget.initialFilter)
        ? widget.initialFilter
        : 'placed';
    _scrollCtrl.addListener(_onScroll);
    _fetchOrders(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _fetchOrders({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _from = 0;
        _hasMore = true;
        _groupedById.clear();
        _orders = [];
      });
      _fetchCount();
      _fetchStatusCounts();
    }
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }
      var query = _supabase.from('orders').select().eq('order_user_id', uid);
      if (_filter == 'delivery_pickup') {
        query = query.inFilter('order_status', const [
          'ready for pickup',
          'out for delivery',
        ]);
      } else if (_filter != 'all') {
        query = query.eq('order_status', _filter);
      }
      if (_searchQuery.isNotEmpty)
        query = query.ilike('order_id', '%$_searchQuery%');
      final rows = await query
          .order('order_id', ascending: false)
          .range(_from, _from + _pageSize - 1);
      await _mergeRows(rows as List);
      if (mounted) {
        setState(() {
          _from += (rows.length as int);
          _hasMore = (rows.length as int) >= _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch user orders error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchCount() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      var q = _supabase
          .from('orders')
          .select('order_id')
          .eq('order_user_id', uid);
      if (_filter == 'delivery_pickup') {
        q = q.inFilter('order_status', const [
          'ready for pickup',
          'out for delivery',
        ]);
      } else if (_filter != 'all') {
        q = q.eq('order_status', _filter);
      }
      if (_searchQuery.isNotEmpty) q = q.ilike('order_id', '%$_searchQuery%');
      final res = await q.count(CountOption.exact);
      if (mounted) setState(() => _totalRowCount = res.count);
    } catch (e) {
      debugPrint("Count error: $e");
    }
  }

  Future<void> _fetchStatusCounts() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      final Map<String, int> counts = {};
      for (final s in _statuses) {
        var q = _supabase
            .from('orders')
            .select('order_id')
            .eq('order_user_id', uid);
        if (s['key'] == 'delivery_pickup') {
          q = q.inFilter('order_status', const [
            'ready for pickup',
            'out for delivery',
          ]);
        } else if (s['key'] != 'all') {
          q = q.eq('order_status', s['key']!);
        }
        if (_searchQuery.isNotEmpty) q = q.ilike('order_id', '%$_searchQuery%');
        final res = await q.count(CountOption.exact);
        counts[s['key']!] = res.count;
      }
      if (mounted) setState(() => _statusCounts = counts);
    } catch (e) {
      debugPrint("Status counts error: $e");
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      var query = _supabase.from('orders').select().eq('order_user_id', uid);
      if (_filter == 'delivery_pickup') {
        query = query.inFilter('order_status', const [
          'ready for pickup',
          'out for delivery',
        ]);
      } else if (_filter != 'all') {
        query = query.eq('order_status', _filter);
      }
      if (_searchQuery.isNotEmpty)
        query = query.ilike('order_id', '%$_searchQuery%');
      final rows = await query
          .order('order_id', ascending: false)
          .range(_from, _from + _pageSize - 1);
      await _mergeRows(rows as List);
      if (mounted) {
        setState(() {
          _from += (rows.length as int);
          _hasMore = (rows.length as int) >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Load more error: $e");
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _mergeRows(List rows) async {
    if (rows.isEmpty) return;
    final itemIds = rows
        .map((r) => r['order_item_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    Map<String, Map<String, dynamic>> itemsById = {};
    Map<String, Map<String, dynamic>> sellersById = {};
    if (itemIds.isNotEmpty) {
      final items = await _supabase
          .from('store_items')
          .select('*, sellers(seller_id, seller_store_name, seller_logo)')
          .inFilter('item_id', itemIds);
      for (final it in items as List) {
        itemsById[it['item_id'].toString()] = Map<String, dynamic>.from(it);
        if (it['sellers'] is Map) {
          final s = Map<String, dynamic>.from(it['sellers']);
          sellersById[s['seller_id'].toString()] = s;
        }
      }
    }
    for (final row in rows) {
      final r = Map<String, dynamic>.from(row);
      final rowId = r['order_id']?.toString() ?? '';
      final oid = _groupOrderId(r);
      if (oid.isEmpty) continue;
      _groupedById.putIfAbsent(
        oid,
        () => {
          'order_id': oid,
          'order_status': r['order_status'],
          'order_delivery_address': r['order_delivery_address'],
          'order_notes': r['order_notes'],
          'order_payment_details': r['order_payment_details'],
          'order_seller_id': r['order_seller_id'],
          'order_row_ids': <String>[],
          '_items': <Map<String, dynamic>>[],
          '_subtotal': 0 as num,
          '_delivery_fee': _deliveryFee(r),
          '_total': 0 as num,
        },
      );
      final entry = _groupedById[oid]!;
      (entry['order_row_ids'] as List).add(rowId);
      final qty = r['order_quantity'] ?? 1;
      final total =
          num.tryParse(r['order_total_price']?.toString() ?? '0') ?? 0;
      final deliveryFee = _deliveryFee(r);
      if (deliveryFee > 0) entry['_delivery_fee'] = deliveryFee;
      entry['_subtotal'] = (entry['_subtotal'] as num) + total;
      entry['_total'] =
          (entry['_subtotal'] as num) + (entry['_delivery_fee'] as num);
      (entry['_items'] as List).add({
        ...r,
        'order_row_id': rowId,
        'store_item': itemsById[r['order_item_id']?.toString()] ?? {},
        'qty': qty,
        'line_total': total,
        'variation': r['order_variation'],
      });
      entry['_seller'] = sellersById[r['order_seller_id']?.toString()];
    }
    _orders = _groupedById.values.toList()
      ..sort((a, b) {
        final ap = (a['order_status']?.toString() == 'placed') ? 0 : 1;
        final bp = (b['order_status']?.toString() == 'placed') ? 0 : 1;
        if (ap != bp) return ap - bp;
        return (b['order_id'] ?? '').toString().compareTo(
          (a['order_id'] ?? '').toString(),
        );
      });
  }

  List<Map<String, dynamic>> get _filtered => _orders;

  String _groupOrderId(Map<String, dynamic> row) {
    final groupId = row['order_group_id']?.toString().trim();
    if (groupId != null && groupId.isNotEmpty) return groupId;
    return (row['order_id']?.toString() ?? '').replaceFirst(
      RegExp(r'_\d+$'),
      '',
    );
  }

  num _deliveryFee(Map<String, dynamic> row) {
    final metaFee = _feeFromPayload(row['order_meta_data']);
    if (metaFee > 0) return metaFee;
    return _feeFromPayload(row['order_delivery_address']);
  }

  num _feeFromPayload(dynamic raw) {
    dynamic value;
    if (raw is Map) {
      value =
          raw['delivery_fee'] ??
          raw['shipping_fee'] ??
          raw['fee'] ??
          raw['rate_amount'];
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          value =
              decoded['delivery_fee'] ??
              decoded['shipping_fee'] ??
              decoded['fee'] ??
              decoded['rate_amount'];
        }
      } catch (_) {}
    }
    return value is num ? value : (num.tryParse(value?.toString() ?? '0') ?? 0);
  }

  int? _orderEpochMs(String orderId) {
    final m = RegExp(r'ORDER_(\d+)').firstMatch(orderId);
    if (m == null) return null;
    final micros = int.tryParse(m.group(1)!);
    if (micros == null) return null;
    return (micros / 1000).round();
  }

  Duration? _elapsed(String orderId) {
    final ms = _orderEpochMs(orderId);
    if (ms == null) return null;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  String _elapsedLabel(Duration d) {
    if (d.inMinutes < 1) return "${d.inSeconds}s ago";
    if (d.inHours < 1) return "${d.inMinutes}m ago";
    if (d.inDays < 1) return "${d.inHours}h ago";
    return "${d.inDays}d ago";
  }

  bool _canCancel(String orderId, String status) {
    if (status == 'placed') return true;
    if (status == 'preparing') {
      final e = _elapsed(orderId);
      return e != null && e < const Duration(minutes: 5);
    }
    return false;
  }

  void _cancelOrder(String orderId, List<String> rowIds) async {
    var deduction = 5;
    try {
      final rows = rowIds.isNotEmpty
          ? await _supabase
                .from('orders')
                .select('order_status')
                .inFilter('order_id', rowIds)
                .limit(1)
          : await _supabase
                .from('orders')
                .select('order_status')
                .or('order_group_id.eq.$orderId,order_id.eq.$orderId')
                .limit(1);
      if (rows.isNotEmpty && rows.first['order_status'] != 'placed') {
        deduction = 20;
      }
    } catch (_) {}
    if (!mounted) return;

    final dialog = ClassicDialog();
    dialog.setTitle("Cancel Order?");
    dialog.setMessage(
      "Cancelling this order will reduce your buying score by $deduction points. "
      "A lower score can disable Cash on Delivery or prevent you from placing new orders.\n\n"
      "Are you sure you want to continue?",
    );
    dialog.setPositiveMessage("Yes, Cancel");
    dialog.setNegativeMessage("Keep Order");
    dialog.showTwoButtonDialog(
      context,
      (_) {
        dialog.dismissDialog();
      },
      (_) async {
        dialog.dismissDialog();
        try {
          final rows = rowIds.isNotEmpty
              ? await _supabase
                    .from('orders')
                    .select('order_user_id, order_status')
                    .inFilter('order_id', rowIds)
                    .limit(1)
              : await _supabase
                    .from('orders')
                    .select('order_user_id, order_status')
                    .or('order_group_id.eq.$orderId,order_id.eq.$orderId')
                    .limit(1);
          final order = rows.isNotEmpty ? rows.first : null;
          await _supabase.rpc(
            'cancel_order_and_restore_stock',
            params: {'p_order_group_id': orderId},
          );
          if (order != null && order['order_status'] != 'cancelled') {
            await BuyerScoreService(_supabase).adjustScore(
              order['order_user_id'].toString(),
              order['order_status'] == 'placed' ? -5 : -20,
            );
          }
          await _fetchOrders(reset: true);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Order cancelled.")));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Cancel failed: $e")));
          }
        }
      },
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'placed':
        return const Color(0xFFF59E0B);
      case 'preparing':
        return const Color(0xFF3B82F6);
      case 'ready for pickup':
        return const Color(0xFF8B5CF6);
      case 'out for delivery':
        return const Color(0xFF06B6D4);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return textSecondary;
    }
  }

  String _addressLine(dynamic addr) {
    if (addr is Map) {
      return [
        addr['street'],
        addr['barangay'],
        addr['municipality'],
        addr['province'],
      ].where((s) => s != null && s.toString().isNotEmpty).join(", ");
    }
    return addr?.toString() ?? '';
  }

  String _deliveryType(dynamic addr) {
    if (addr is Map && addr['delivery_type'] != null)
      return addr['delivery_type'].toString();
    final line = _addressLine(addr);
    if (line.toLowerCase().startsWith("pickup")) return "Pickup";
    return "Delivery";
  }

  Widget _deliveryPill(String type) {
    final isPickup = type == "Pickup";
    final color = isPickup ? const Color(0xFF8B5CF6) : const Color(0xFF06B6D4);
    final icon = isPickup
        ? Icons.storefront_rounded
        : Icons.local_shipping_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            type.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 9.5,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _paymentChannel(dynamic pay) {
    if (pay is Map) return pay['channel']?.toString() ?? '';
    return pay?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "My Orders",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((s) {
                  final active = _filter == s['key'];
                  final count = _statusCounts[s['key']] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s['label']!,
                            style: TextStyle(
                              color: active ? Colors.white : primaryDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(minWidth: 18),
                              decoration: BoxDecoration(
                                color: active ? Colors.white : primaryBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: active ? primaryBlue : Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: active,
                      selectedColor: primaryBlue,
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: active ? primaryBlue : cardBorder,
                      ),
                      onSelected: (_) {
                        setState(() => _filter = s['key']!);
                        _fetchOrders(reset: true);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          _buildTotalBanner(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? _empty()
                : RefreshIndicator(
                    onRefresh: () => _fetchOrders(reset: true),
                    child: ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: _filtered.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i >= _filtered.length)
                          return _buildLoadMoreFooter();
                        return _orderCard(_filtered[i]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 400), () {
              if (_searchQuery == v.trim()) return;
              setState(() => _searchQuery = v.trim());
              _fetchOrders(reset: true);
            });
          },
          decoration: InputDecoration(
            isDense: true,
            hintText: "Search by order ID...",
            hintStyle: TextStyle(color: textSecondary, fontSize: 13),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: primaryBlue,
              size: 20,
            ),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                      _fetchOrders(reset: true);
                    },
                  ),
            filled: true,
            fillColor: bgColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryBlue, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalBanner() {
    final loaded = _orders.length;
    final total = _totalRowCount;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, size: 16, color: primaryBlue),
          const SizedBox(width: 8),
          Text(
            "$loaded loaded",
            style: TextStyle(
              color: primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          if (total != null) ...[
            const SizedBox(width: 6),
            Text(
              "· $total total ${_filter == 'all' ? 'rows' : '$_filter rows'}",
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          const Spacer(),
          if (_loadingMore)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore && _orders.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            "— End of list —",
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 32);
  }

  Widget _empty() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.receipt_long_outlined,
          size: 64,
          color: textSecondary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            "No orders yet",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: primaryDark,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            "Your purchases will show up here.",
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  ImageProvider? _sellerLogoProvider(Map seller) {
    final logo = seller['seller_logo']?.toString();
    if (logo == null || logo.isEmpty) return null;
    if (logo.startsWith('http')) return NetworkImage(logo);
    final bytes = Utility.decodeHexImage(logo);
    if (bytes != null) return MemoryImage(bytes);
    return null;
  }

  String? _itemImageUrl(Map si) {
    final imgs = si['item_images'];
    if (imgs is List && imgs.isNotEmpty) return imgs[0]?.toString();
    return null;
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final id = order['order_id']?.toString() ?? '';
    final status = (order['order_status'] ?? 'placed').toString();
    final total = order['_total'];
    final addr = _addressLine(order['order_delivery_address']);
    final pay = _paymentChannel(order['order_payment_details']);
    final note = order['order_notes']?.toString() ?? '';
    final items = List<Map<String, dynamic>>.from(order['_items'] ?? []);
    final rowIds = (order['order_row_ids'] as List? ?? const [])
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final seller = order['_seller'] is Map ? order['_seller'] as Map : {};
    final sellerName = seller['seller_store_name']?.toString() ?? 'Shop';
    final sellerLogo = _sellerLogoProvider(seller);
    final itemCount = items.fold<num>(
      0,
      (s, it) => s + (it['qty'] as num? ?? 0),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- HEADER: order-first, shop demoted to a small line below ---
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue.withValues(alpha: 0.06), Colors.white],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status + delivery pill on top — these are what the buyer cares about.
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _statusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _deliveryPill(
                      _deliveryType(order['order_delivery_address']),
                    ),
                    const Spacer(),
                    if (_elapsed(id) != null) ...[
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _elapsedLabel(_elapsed(id)!),
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Order id is the dominant element of the card now.
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      color: primaryBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Text(
                      "${itemCount.toInt()} item${itemCount == 1 ? '' : 's'}",
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Compact shop chip — small avatar + name, no border ring, no large text.
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: primaryBlue.withValues(alpha: 0.1),
                      backgroundImage: sellerLogo,
                      child: sellerLogo == null
                          ? Icon(
                              Icons.storefront_rounded,
                              size: 10,
                              color: primaryBlue,
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "from",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: cardBorder),

          if (_canCancel(id, status)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(
                        builder: (_) {
                          final e = _elapsed(id);
                          if (status == 'placed') {
                            return Text(
                              e != null && e < const Duration(minutes: 5)
                                  ? "You can cancel within the next ${(const Duration(minutes: 5) - e).inMinutes}m ${(const Duration(minutes: 5) - e).inSeconds % 60}s."
                                  : "You can cancel this order while it's still pending.",
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            );
                          }
                          final rem = const Duration(minutes: 5) - e!;
                          return Text(
                            "Seller accepted early. You can still cancel within ${rem.inMinutes}m ${rem.inSeconds % 60}s.",
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // --- ITEMS ---
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(children: items.map((it) => _itemTile(it)).toList()),
          ),

          // --- DIVIDER + DETAILS ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            height: 1,
            color: cardBorder,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _buildBuyerInfo(order['order_delivery_address']),
                _kv(Icons.location_on_rounded, "Address", addr),
                _kv(Icons.payments_rounded, "Payment", pay),
                if (note.isNotEmpty) _kv(Icons.edit_note_rounded, "Note", note),
              ],
            ),
          ),

          // --- TOTAL ---
          Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: themeOrange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeOrange.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Text(
                  "ORDER TOTAL",
                  style: TextStyle(
                    color: themeOrange.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  "₱${Utility().formatPrice(total)}",
                  style: TextStyle(
                    color: themeOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          if (_canCancel(id, status)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelOrder(id, rowIds),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text(
                    "Cancel Order",
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetails(order: order)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('View Order Details'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(Map<String, dynamic> it) {
    final si = it['store_item'] is Map ? it['store_item'] as Map : {};
    final name =
        si['item_name']?.toString() ??
        (it['order_item_id']?.toString() ?? 'Item');
    final qty = it['qty'];
    final lineTotal = it['line_total'];
    final variation = it['variation'] is Map
        ? Map<String, dynamic>.from(it['variation'])
        : null;
    final unitPrice = variation != null
        ? (num.tryParse(variation['price']?.toString() ?? '0') ?? 0)
        : (num.tryParse(si['item_price']?.toString() ?? '0') ?? 0);
    final imgUrl = _itemImageUrl(si);
    final category = si['item_category']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: imgUrl != null
                  ? Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _itemImgFallback(),
                    )
                  : _itemImgFallback(),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: primaryDark,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (variation != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      "Variant: ${variation['label']}",
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
                if (category != null && category.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    category,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: themeOrange.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "×$qty",
                        style: TextStyle(
                          color: themeOrange,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "@ ₱${Utility().formatPrice(unitPrice)}",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Line total
          Text(
            "₱${Utility().formatPrice(lineTotal)}",
            style: TextStyle(
              color: primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemImgFallback() {
    return Container(
      color: bgColor,
      child: Icon(
        Icons.image_outlined,
        color: textSecondary.withValues(alpha: 0.5),
        size: 24,
      ),
    );
  }

  Widget _buildBuyerInfo(dynamic raw) {
    Map<String, dynamic>? a;
    if (raw is Map) a = Map<String, dynamic>.from(raw);
    if (a == null) return const SizedBox.shrink();
    final first = (a['first_name'] ?? '').toString().trim();
    final middle = (a['middle_name'] ?? '').toString().trim();
    final last = (a['last_name'] ?? '').toString().trim();
    final name = [first, middle, last].where((s) => s.isNotEmpty).join(' ');
    final contact = (a['contact_number'] ?? '').toString().trim();
    final email = (a['email'] ?? '').toString().trim();
    if (name.isEmpty && contact.isEmpty && email.isEmpty)
      return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, color: primaryBlue, size: 14),
              const SizedBox(width: 6),
              Text(
                "BUYER INFORMATION",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (name.isNotEmpty) _kv(Icons.badge_outlined, "Name", name),
          if (contact.isNotEmpty) _kv(Icons.call_rounded, "Contact", contact),
          if (email.isNotEmpty)
            _kv(Icons.alternate_email_rounded, "Email", email),
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: primaryBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    color: primaryDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
