import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/Orders/OrderDetails.dart';
import '../../../Utility/BuyerScoreService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';

class SellerOrders extends StatefulWidget {
  final String sellerId;
  const SellerOrders({super.key, required this.sellerId});

  @override
  State<SellerOrders> createState() => _SellerOrdersState();
}

class _SellerOrdersState extends State<SellerOrders> {
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
  List<Map<String, dynamic>> _orders = []; // grouped by order_id
  String _filter = 'placed';
  String _searchQuery = '';
  Map<String, int> _statusCounts = {};
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  final ScrollController _scrollCtrl = ScrollController();

  static const List<Map<String, String>> _statuses = [
    {'key': 'all', 'label': 'All'},
    {'key': 'placed', 'label': 'Placed'},
    {'key': 'preparing', 'label': 'Preparing'},
    {'key': 'ready for pickup', 'label': 'Ready for Pickup'},
    {'key': 'out for delivery', 'label': 'Out for Delivery'},
    {'key': 'completed', 'label': 'Completed'},
    {'key': 'cancelled', 'label': 'Cancelled'},
  ];

  @override
  void initState() {
    super.initState();
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
      var query = _supabase
          .from('orders')
          .select()
          .eq('order_seller_id', widget.sellerId);
      if (_filter != 'all') {
        query = query.eq('order_status', _filter);
      }
      if (_searchQuery.isNotEmpty) {
        query = query.ilike('order_id', '%$_searchQuery%');
      }
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
      debugPrint("Fetch orders error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchCount() async {
    try {
      var q = _supabase
          .from('orders')
          .select('order_id')
          .eq('order_seller_id', widget.sellerId);
      if (_filter != 'all') q = q.eq('order_status', _filter);
      if (_searchQuery.isNotEmpty) q = q.ilike('order_id', '%$_searchQuery%');
      final res = await q.count(CountOption.exact);
      if (mounted) setState(() => _totalRowCount = res.count);
    } catch (e) {
      debugPrint("Count error: $e");
    }
  }

  Future<void> _fetchStatusCounts() async {
    try {
      final Map<String, int> counts = {};
      for (final s in _statuses) {
        var q = _supabase
            .from('orders')
            .select('order_id')
            .eq('order_seller_id', widget.sellerId);
        if (s['key'] != 'all') q = q.eq('order_status', s['key']!);
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
      var query = _supabase
          .from('orders')
          .select()
          .eq('order_seller_id', widget.sellerId);
      if (_filter != 'all') {
        query = query.eq('order_status', _filter);
      }
      if (_searchQuery.isNotEmpty) {
        query = query.ilike('order_id', '%$_searchQuery%');
      }
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
    if (itemIds.isNotEmpty) {
      final items = await _supabase
          .from('store_items')
          .select()
          .inFilter('item_id', itemIds);
      for (final it in items as List) {
        itemsById[it['item_id'].toString()] = Map<String, dynamic>.from(it);
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
          'order_seller_zipcode': r['order_seller_zipcode'],
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

  String _statusActionTitle(String status) {
    switch (status) {
      case 'preparing':
        return "Accept Order?";
      case 'ready for pickup':
        return "Mark as Ready for Pickup?";
      case 'out for delivery':
        return "Mark as Out for Delivery?";
      case 'completed':
        return "Mark as Completed?";
      case 'cancelled':
        return "Cancel this Order?";
      default:
        return "Update order status?";
    }
  }

  String _statusActionMessage(String status) {
    switch (status) {
      case 'preparing':
        return "You are accepting this order. The buyer will be notified that you're preparing it.";
      case 'ready for pickup':
        return "Mark this order ready for the buyer to pick up at the store.";
      case 'out for delivery':
        return "Confirm that this order has been handed off for delivery.";
      case 'completed':
        return "Mark this order as completed. This action cannot be undone.";
      case 'cancelled':
        return "Are you sure you want to cancel this order? This action cannot be undone.";
      default:
        return "Confirm this status change?";
    }
  }

  void _confirmUpdateStatus(
    String orderId,
    String status,
    List<String> rowIds,
  ) {
    final dialog = ClassicDialog();
    dialog.setTitle(_statusActionTitle(status));
    dialog.setMessage(_statusActionMessage(status));
    dialog.setPositiveMessage(
      status == 'cancelled' ? "Yes, Cancel" : "Confirm",
    );
    dialog.setNegativeMessage("Not Now");
    dialog.showTwoButtonDialog(
      context,
      (_) {
        dialog.dismissDialog();
      },
      (_) {
        dialog.dismissDialog();
        _updateStatus(orderId, status, rowIds);
      },
    );
  }

  Future<void> _updateStatus(
    String orderId,
    String status, [
    List<String> rowIds = const [],
  ]) async {
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
      if (status == 'cancelled') {
        await _supabase.rpc(
          'cancel_order_and_restore_stock',
          params: {'p_order_group_id': orderId},
        );
      } else if (rowIds.isNotEmpty) {
        await _supabase
            .from('orders')
            .update({'order_status': status})
            .inFilter('order_id', rowIds);
      } else {
        await _supabase
            .from('orders')
            .update({'order_status': status})
            .or('order_group_id.eq.$orderId,order_id.eq.$orderId');
      }
      if (order != null && order['order_status'] != status) {
        if (status == 'completed') {
          await BuyerScoreService(
            _supabase,
          ).adjustScore(order['order_user_id'].toString(), 2);
        } else if (status == 'cancelled' && order['order_status'] != 'placed') {
          await BuyerScoreService(
            _supabase,
          ).adjustScore(order['order_user_id'].toString(), -20);
        }
      }
      await _fetchOrders(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Order marked as $status.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Update failed: $e")));
      }
    }
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

  String _paymentChannel(dynamic pay) {
    if (pay is Map) return pay['channel']?.toString() ?? '';
    return pay?.toString() ?? '';
  }

  String? _proofUrl(dynamic pay) {
    if (pay is Map) {
      final url = pay['payment_proof_url']?.toString();
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  void _viewProof(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, prog) => prog == null
                      ? child
                      : Container(
                          color: Colors.black,
                          padding: const EdgeInsets.all(40),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black,
                    padding: const EdgeInsets.all(40),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Couldn't load proof image.",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.6),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Orders",
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
          Icon(Icons.inventory_2_rounded, size: 16, color: primaryBlue),
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
              "• $total total ${_filter == 'all' ? 'rows' : '$_filter rows'}",
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

  String? _itemImageUrl(Map si) {
    final imgs = si['item_images'];
    if (imgs is List && imgs.isNotEmpty) return imgs[0]?.toString();
    return null;
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
            "Orders from your customers will appear here.",
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _confirmAcceptEarly(String id, Duration elapsed, List<String> rowIds) {
    final remaining = const Duration(minutes: 5) - elapsed;
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    final dialog = ClassicDialog();
    dialog.setTitle("Early Acceptance");
    dialog.setMessage(
      "It's been less than 5 minutes since this order was placed. The buyer can still cancel within ${mins}m ${secs}s.\n\nIt's recommended to wait the 5-minute window before accepting. Continue anyway?",
    );
    dialog.setPositiveMessage("Accept Anyway");
    dialog.setNegativeMessage("Wait");
    dialog.showTwoButtonDialog(
      context,
      (_) {
        dialog.dismissDialog();
      },
      (_) {
        dialog.dismissDialog();
        _updateStatus(id, 'preparing', rowIds);
      },
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final id = order['order_id']?.toString() ?? '';
    final status = (order['order_status'] ?? 'placed').toString();
    final total = order['_total'];
    final subtotal = order['_subtotal'] ?? total;
    final deliveryFee = order['_delivery_fee'] is num
        ? order['_delivery_fee'] as num
        : (num.tryParse(order['_delivery_fee']?.toString() ?? '0') ?? 0);
    final addr = _addressLine(order['order_delivery_address']);
    final pay = _paymentChannel(order['order_payment_details']);
    final note = order['order_notes']?.toString() ?? '';
    final items = List<Map<String, dynamic>>.from(order['_items'] ?? []);
    final rowIds = (order['order_row_ids'] as List? ?? const [])
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final elapsed = _elapsed(id);
    final withinWindow =
        elapsed != null && elapsed < const Duration(minutes: 5);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: primaryDark,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (elapsed != null)
                      Text(
                        _elapsedLabel(elapsed),
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _deliveryPill(_deliveryType(order['order_delivery_address'])),
                ],
              ),
            ],
          ),
          if (status == 'placed' && withinWindow) ...[
            const SizedBox(height: 10),
            Container(
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
                    child: Text(
                      "Buyer can still cancel for ${(const Duration(minutes: 5) - elapsed).inMinutes}m ${(const Duration(minutes: 5) - elapsed).inSeconds % 60}s. Recommended to accept after the 5-minute window.",
                      style: TextStyle(
                        color: const Color(0xFFB45309),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...items.map((it) => _itemTile(it)),
          const Divider(height: 18),
          _buildBuyerInfo(order['order_delivery_address']),
          _kv(Icons.location_on_rounded, "Address", addr),
          _kv(Icons.payments_rounded, "Payment", pay),
          if (note.isNotEmpty) _kv(Icons.edit_note_rounded, "Note", note),
          if (_proofUrl(order['order_payment_details']) != null) ...[
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () =>
                  _viewProof(_proofUrl(order['order_payment_details'])!),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        _proofUrl(order['order_payment_details'])!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: cardBorder,
                          child: Icon(
                            Icons.receipt_rounded,
                            color: textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Payment Proof",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: primaryDark,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            "Tap to view receipt",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: primaryBlue,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (deliveryFee > 0) ...[
            Row(
              children: [
                Text(
                  "Items subtotal",
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                Text(
                  "₱${Utility().formatPrice(subtotal)}",
                  style: TextStyle(
                    color: primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  "Shipping fee",
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                Text(
                  "₱${Utility().formatPrice(deliveryFee)}",
                  style: TextStyle(
                    color: primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Text(
                "Voucher discount",
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              Text(
                "\u20B10.00",
                style: TextStyle(
                  color: primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                "Total",
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              Text(
                "₱${Utility().formatPrice(total)}",
                style: TextStyle(
                  color: themeOrange,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetails(order: order, sellerView: true),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('View Order Details'),
            ),
          ),
          const SizedBox(height: 8),
          _actions(
            id,
            status,
            _deliveryType(order['order_delivery_address']) == "Pickup",
            withinWindow,
            elapsed,
            rowIds,
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: textSecondary),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(
    String id,
    String status,
    bool isPickup,
    bool withinWindow,
    Duration? elapsed,
    List<String> rowIds,
  ) {
    final List<Map<String, String>> nextOptions;
    switch (status) {
      case 'placed':
        nextOptions = [
          {'key': 'preparing', 'label': 'Accept'},
          {'key': 'cancelled', 'label': 'Cancel'},
        ];
        break;
      case 'preparing':
        nextOptions = isPickup
            ? [
                {'key': 'ready for pickup', 'label': 'Ready for Pickup'},
                {'key': 'cancelled', 'label': 'Cancel'},
              ]
            : [
                {'key': 'out for delivery', 'label': 'Out for Delivery'},
                {'key': 'cancelled', 'label': 'Cancel'},
              ];
        break;
      case 'ready for pickup':
      case 'out for delivery':
        nextOptions = [
          {'key': 'completed', 'label': 'Mark Completed'},
        ];
        break;
      default:
        return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: nextOptions.map((opt) {
        final destructive = opt['key'] == 'cancelled';
        final isAcceptEarly =
            status == 'placed' &&
            opt['key'] == 'preparing' &&
            withinWindow &&
            elapsed != null;
        return ElevatedButton.icon(
          onPressed: () {
            if (isAcceptEarly) {
              _confirmAcceptEarly(id, elapsed, rowIds);
            } else {
              _confirmUpdateStatus(id, opt['key']!, rowIds);
            }
          },
          icon: Icon(
            destructive
                ? Icons.close_rounded
                : (isAcceptEarly
                      ? Icons.schedule_rounded
                      : Icons.check_rounded),
            size: 16,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive
                ? const Color(0xFFEF4444)
                : (isAcceptEarly ? const Color(0xFFF59E0B) : primaryBlue),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          label: Text(opt['label']!),
        );
      }).toList(),
    );
  }
}
