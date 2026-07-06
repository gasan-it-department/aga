import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/GodMode/GodModeSellers/GodModeSellerOrders.dart';
import 'package:gasan_port_tracker/Activities/ViewShop.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GodModeSellerControl extends StatefulWidget {
  const GodModeSellerControl({super.key});

  @override
  State<GodModeSellerControl> createState() => _GodModeSellerControlState();
}

class _GodModeSellerControlState extends State<GodModeSellerControl> {
  static const _bg = Color(0xFFF8FAFC);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _primary = Color(0xFF0A2E5C);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFDC2626);
  static const _purple = Color(0xFF7C3AED);

  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _sellers = [];
  bool _loading = true;
  String _filter = 'pending';
  String _query = '';
  String? _busySellerId;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await _loadSellers();
  }

  Future<void> _loadSellers() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('sellers')
          .select()
          .order('seller_store_status', ascending: true)
          .order('seller_store_name', ascending: true);
      if (!mounted) return;
      setState(() {
        _sellers = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Unable to load sellers: $error', error: true);
    }
  }

  Future<void> _refreshAll() async {
    await _loadSellers();
  }

  String _statusOf(Map<String, dynamic> seller) {
    final status = seller['seller_store_status']
        ?.toString()
        .trim()
        .toLowerCase();
    if (status == null || status.isEmpty) return 'in_review';
    if (status == 'banned') return 'suspended';
    return status;
  }

  List<Map<String, dynamic>> get _filtered {
    return _sellers.where((seller) {
      final status = _statusOf(seller);
      final matchesStatus =
          _filter == 'all' ||
          (_filter == 'pending' && status == 'in_review') ||
          status == _filter;
      final haystack = [
        seller['seller_store_name'],
        seller['seller_user_id'],
        seller['seller_email_address'],
        seller['seller_contact_number'],
        seller['seller_store_type'],
        _addressText(seller['seller_store_address']),
      ].join(' ').toLowerCase();
      return matchesStatus && haystack.contains(_query.toLowerCase());
    }).toList();
  }

  int _count(String status) {
    if (status == 'pending') {
      return _sellers
          .where((seller) => _statusOf(seller) == 'in_review')
          .length;
    }
    return _sellers.where((seller) => _statusOf(seller) == status).length;
  }

  Future<void> _setStatus(
    Map<String, dynamic> seller,
    String status, {
    String? reason,
  }) async {
    final sellerId = seller['seller_id']?.toString();
    if (sellerId == null || sellerId.isEmpty) return;

    setState(() => _busySellerId = sellerId);
    try {
      final dbStatus = status == 'suspended' ? 'banned' : status;
      await _supabase
          .from('sellers')
          .update({'seller_store_status': dbStatus})
          .eq('seller_id', sellerId);

      await _notifySellerIfNeeded(seller, status: status, reason: reason);

      if (!mounted) return;
      setState(() {
        seller['seller_store_status'] = dbStatus;
        _busySellerId = null;
      });
      _toast(
        '${seller['seller_store_name'] ?? 'Shop'} set to ${_statusLabel(status).toLowerCase()}.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busySellerId = null);
      _toast('Unable to update seller: $error', error: true);
    }
  }

  Future<void> _notifySellerIfNeeded(
    Map<String, dynamic> seller, {
    required String status,
    String? reason,
  }) async {
    if (!['visible', 'rejected', 'suspended'].contains(status)) return;
    final userId = seller['seller_user_id']?.toString();
    if (userId == null || userId.isEmpty) return;

    final title = switch (status) {
      'visible' => 'Online shop approved',
      'rejected' => 'Shop application rejected',
      'suspended' => 'Shop suspended',
      _ => 'Shop status updated',
    };
    final shopName = seller['seller_store_name'] ?? 'Your shop';
    final message = switch (status) {
      'visible' =>
        '$shopName has been approved and is now visible to the public.',
      'rejected' =>
        '$shopName was rejected.\n\nReason: ${reason ?? 'No reason provided.'}',
      'suspended' =>
        '$shopName has been suspended and is no longer visible to the public.\n\nReason: ${reason ?? 'No reason provided.'}',
      _ => '$shopName status was updated.',
    };

    final row = await _supabase
        .from('user_data')
        .select('limited_notifications')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      throw Exception('The seller account could not be found.');
    }
    final notifications = <dynamic>[];
    final existing = row['limited_notifications'];
    if (existing is List) notifications.addAll(existing);
    notifications.insert(0, {
      'id': 'GOD_SHOP_${seller['seller_id']}_${Utility().generateUniqueID()}',
      'title': title,
      'message': message,
      'date_sent': Utility().getCurrentMSEpochTime(),
      'notification_type': 'marketplace_status',
      'seller_id': seller['seller_id'],
      'shop_status': status,
    });
    await _supabase
        .from('user_data')
        .update({'limited_notifications': notifications.take(1500).toList()})
        .eq('user_id', userId);
  }

  Future<void> _askReason(Map<String, dynamic> seller, String status) async {
    final controller = TextEditingController();
    String? validationMessage;
    final label = status == 'suspended' ? 'Suspend shop' : 'Reject shop';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(label),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 4,
            maxLines: 7,
            onChanged: (_) {
              if (validationMessage != null) {
                setDialogState(() => validationMessage = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Reason',
              hintText: 'Explain this action to the seller.',
              errorText: validationMessage,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(
                    () => validationMessage = 'A reason message is required.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: Text('$label and notify'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (reason != null) await _setStatus(seller, status, reason: reason);
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _red : _ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _addressText(dynamic address) {
    if (address is Map) {
      return [
            address['street'],
            address['barangay'],
            address['municipality'],
            address['province'],
          ]
          .where((part) => part != null && part.toString().trim().isNotEmpty)
          .join(', ');
    }
    return address?.toString() ?? 'No address';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 900 ? 28.0 : 14.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Seller Control',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 36),
          children: [
            _hero(),
            const SizedBox(height: 14),
            _summary(width),
            const SizedBox(height: 14),
            _controls(width),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: _primary),
                ),
              )
            else if (_filtered.isEmpty)
              _empty()
            else
              ..._filtered.map(_sellerCard),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.store_mall_directory_rounded, color: _amber, size: 34),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'God Mode Seller Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Review pending stores, expose hidden states, and take direct action across every seller.',
                  style: TextStyle(color: Color(0xFFE2E8F0), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(double width) {
    final columns = width >= 980
        ? 6
        : width >= 680
        ? 3
        : 2;
    final cardWidth =
        (width - (width >= 900 ? 56 : 28) - ((columns - 1) * 8)) / columns;
    final items = [
      ('All', _sellers.length, Icons.apps_rounded, _primary),
      ('Pending', _count('pending'), Icons.pending_actions_rounded, _amber),
      ('Visible', _count('visible'), Icons.visibility_rounded, _green),
      ('Hidden', _count('hidden'), Icons.visibility_off_rounded, _muted),
      ('Suspended', _count('suspended'), Icons.block_rounded, _red),
      ('Rejected', _count('rejected'), Icons.cancel_rounded, _purple),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return SizedBox(
          width: cardWidth.clamp(130, 220),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Icon(item.$3, color: item.$4),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.$2}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _controls(double width) {
    final search = TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim()),
      decoration: InputDecoration(
        hintText: 'Search seller, email, contact, type, address',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _line),
        ),
      ),
    );
    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'all',
            label: Text('All'),
            icon: Icon(Icons.apps_rounded),
          ),
          ButtonSegment(
            value: 'pending',
            label: Text('Pending'),
            icon: Icon(Icons.pending_actions_rounded),
          ),
          ButtonSegment(
            value: 'visible',
            label: Text('Visible'),
            icon: Icon(Icons.visibility_rounded),
          ),
          ButtonSegment(
            value: 'hidden',
            label: Text('Hidden'),
            icon: Icon(Icons.visibility_off_rounded),
          ),
          ButtonSegment(
            value: 'suspended',
            label: Text('Suspended'),
            icon: Icon(Icons.block_rounded),
          ),
          ButtonSegment(
            value: 'rejected',
            label: Text('Rejected'),
            icon: Icon(Icons.cancel_rounded),
          ),
        ],
        selected: {_filter},
        onSelectionChanged: (value) => setState(() => _filter = value.first),
      ),
    );
    if (width >= 900) {
      return Row(
        children: [
          Expanded(child: search),
          const SizedBox(width: 12),
          filters,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [search, const SizedBox(height: 10), filters],
    );
  }

  Widget _sellerCard(Map<String, dynamic> seller) {
    final status = _statusOf(seller);
    final sellerId = seller['seller_id']?.toString() ?? '';
    final busy = _busySellerId == sellerId;
    final logo = seller['seller_logo']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'in_review' ? _amber.withValues(alpha: 0.45) : _line,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 68,
                  height: 68,
                  color: _bg,
                  child: logo.isEmpty
                      ? const Icon(Icons.storefront_rounded, color: _muted)
                      : Image.network(
                          logo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.storefront_rounded,
                            color: _muted,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          seller['seller_store_name']?.toString() ??
                              'Unnamed shop',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _badge(status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      seller['seller_store_type']?.toString() ??
                          'Unspecified type',
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _addressText(seller['seller_store_address']),
                      style: const TextStyle(color: _muted, height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                            seller['seller_email_address'],
                            seller['seller_contact_number'],
                          ]
                          .where(
                            (part) =>
                                part != null &&
                                part.toString().trim().isNotEmpty,
                          )
                          .join(' · '),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = busy
              ? const SizedBox(
                  width: 150,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _actions(seller, status);
          if (constraints.maxWidth >= 840) {
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 14),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, const SizedBox(height: 14), actions],
          );
        },
      ),
    );
  }

  Widget _actions(Map<String, dynamic> seller, String status) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewShop(
                sellerId: seller['seller_id'].toString(),
                sellerData: seller,
              ),
            ),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('View'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            final sellerId = seller['seller_id']?.toString();
            if (sellerId == null || sellerId.isEmpty) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GodModeSellerOrders(initialSellerId: sellerId),
              ),
            );
          },
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text('Orders'),
        ),
        if (status != 'visible')
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => _setStatus(seller, 'visible'),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
          ),
        if (status != 'hidden')
          OutlinedButton.icon(
            onPressed: () => _setStatus(seller, 'hidden'),
            icon: const Icon(Icons.visibility_off_rounded, size: 18),
            label: const Text('Hide'),
          ),
        if (status != 'suspended')
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: _red),
            onPressed: () => _askReason(seller, 'suspended'),
            icon: const Icon(Icons.block_rounded, size: 18),
            label: const Text('Suspend'),
          ),
        if (status != 'rejected')
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: _purple),
            onPressed: () => _askReason(seller, 'rejected'),
            icon: const Icon(Icons.cancel_rounded, size: 18),
            label: const Text('Reject'),
          ),
      ],
    );
  }

  Widget _badge(String status) {
    final color = switch (status) {
      'visible' => _green,
      'hidden' => _muted,
      'suspended' => _red,
      'rejected' => _purple,
      _ => _amber,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'visible' => 'Visible',
      'hidden' => 'Hidden',
      'suspended' => 'Suspended',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };
  }

  Widget _empty() {
    return const Padding(
      padding: EdgeInsets.only(top: 90),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.storefront_outlined, color: _muted, size: 48),
            SizedBox(height: 10),
            Text(
              'No sellers found',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
