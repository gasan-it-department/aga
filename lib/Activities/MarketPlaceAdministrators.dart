import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/MarketplaceAllOrders.dart';
import 'package:gasan_port_tracker/Activities/ViewShop.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketPlaceAdministrators extends StatefulWidget {
  const MarketPlaceAdministrators({super.key});

  @override
  State<MarketPlaceAdministrators> createState() =>
      _MarketPlaceAdministratorsState();
}

class _MarketPlaceAdministratorsState extends State<MarketPlaceAdministrators> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  static const _background = Color(0xFFF6F8FB);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF667085);
  static const _border = Color(0xFFE4E7EC);
  static const _blue = Color(0xFF2563EB);
  static const _green = Color(0xFF16A36A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFE5484D);

  List<Map<String, dynamic>> _shops = [];
  bool _loading = true;
  String _selectedStatus = 'all';
  String _query = '';
  String? _processingSellerId;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    if (mounted) setState(() => _loading = true);
    try {
      final response = await _supabase
          .from('sellers')
          .select()
          .order('seller_store_name', ascending: true);
      if (mounted) {
        setState(() {
          _shops = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage('Unable to load shops: $e', error: true);
      }
    }
  }

  String _statusOf(Map<String, dynamic> shop) {
    final status = shop['seller_store_status']?.toString().toLowerCase();
    if (status == 'visible' || status == 'rejected' || status == 'banned') {
      return status!;
    }
    return 'in_review';
  }

  List<Map<String, dynamic>> get _filteredShops {
    return _shops.where((shop) {
      final matchesStatus =
          _selectedStatus == 'all' ||
          _statusOf(shop) == _selectedStatus ||
          (_selectedStatus == 'rejected' && _statusOf(shop) == 'banned');
      final haystack = [
        shop['seller_store_name'],
        shop['seller_store_type'],
        shop['seller_email_address'],
        shop['seller_contact_number'],
        _addressText(shop['seller_store_address']),
      ].join(' ').toLowerCase();
      return matchesStatus && haystack.contains(_query.toLowerCase());
    }).toList();
  }

  int _count(String status) =>
      _shops.where((shop) => _statusOf(shop) == status).length;

  Future<void> _changeStatus(
    Map<String, dynamic> shop,
    String status, {
    String? rejectionReason,
  }) async {
    final sellerId = shop['seller_id']?.toString();
    if (sellerId == null) return;
    setState(() => _processingSellerId = sellerId);

    try {
      await _supabase
          .from('sellers')
          .update({'seller_store_status': status})
          .eq('seller_id', sellerId);

      if (status == 'visible') {
        await _sendStatusNotification(
          shop,
          status: status,
          title: 'Online shop approved',
          message:
              '${shop['seller_store_name'] ?? 'Your shop'} has been approved and is now visible to the public. Customers can now browse your shop and available items.',
        );
      } else if (status == 'rejected') {
        await _sendStatusNotification(
          shop,
          status: status,
          title: 'Shop application rejected',
          message:
              'Your application for ${shop['seller_store_name'] ?? 'your shop'} was rejected.\n\nReason: $rejectionReason\n\nPlease update the required details before submitting your shop again.',
        );
      } else if (status == 'banned') {
        await _sendStatusNotification(
          shop,
          status: status,
          title: 'Shop suspended',
          message:
              '${shop['seller_store_name'] ?? 'Your shop'} has been suspended and is no longer visible to the public.\n\nReason: $rejectionReason\n\nPlease contact the administrator or correct the issue before requesting another review.',
        );
      }

      if (mounted) {
        setState(() {
          shop['seller_store_status'] = status;
          _processingSellerId = null;
        });
        _showMessage(
          status == 'visible'
              ? '${shop['seller_store_name']} is now visible to the public.'
              : status == 'rejected'
              ? 'Application rejected and the seller was notified.'
              : status == 'banned'
              ? 'Shop suspended and the seller was notified.'
              : '${shop['seller_store_name']} is now hidden and in review.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingSellerId = null);
        _showMessage('Unable to update shop: $e', error: true);
      }
    }
  }

  Future<void> _sendStatusNotification(
    Map<String, dynamic> shop, {
    required String status,
    required String title,
    required String message,
  }) async {
    final userId = shop['seller_user_id']?.toString();
    if (userId == null || userId.isEmpty) {
      throw Exception('The shop has no linked seller account.');
    }

    final userData = await _supabase
        .from('user_data')
        .select('limited_notifications')
        .eq('user_id', userId)
        .maybeSingle();
    if (userData == null) {
      throw Exception('The seller account could not be found.');
    }

    final notifications = <dynamic>[];
    final existing = userData['limited_notifications'];
    if (existing is List) notifications.addAll(existing);

    final notificationId =
        'SHOP_${shop['seller_id']}_${status}_${Utility().generateUniqueID()}';
    notifications.insert(0, {
      'id': notificationId,
      'title': title,
      'message': message,
      'date_sent': Utility().getCurrentMSEpochTime(),
      'notification_type': 'marketplace_status',
      'seller_id': shop['seller_id'],
      'shop_status': status,
    });

    await _supabase
        .from('user_data')
        .update({'limited_notifications': notifications.take(1500).toList()})
        .eq('user_id', userId);
  }

  Future<void> _showRejectDialog(Map<String, dynamic> shop) async {
    final isSuspension = _statusOf(shop) == 'visible';
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isSuspension ? 'Suspend visible shop' : 'Reject shop application',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSuspension
                  ? 'Explain why this shop is being suspended. It will immediately become hidden and the seller will be notified.'
                  : 'Tell the seller exactly what needs to be corrected. This message will appear in their personal notifications.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Explain the issue clearly.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            icon: const Icon(Icons.close_rounded),
            label: Text(
              isSuspension ? 'Suspend and notify' : 'Reject and notify',
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && mounted) {
      await _changeStatus(
        shop,
        isSuspension ? 'banned' : 'rejected',
        rejectionReason: reason,
      );
    }
  }

  void _showMessage(String message, {bool error = false}) {
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
    return address?.toString() ?? 'No address provided';
  }

  String _verificationDocumentLabel(Map<String, dynamic> shop) {
    final prefs = shop['seller_preferences'];
    dynamic type;
    if (prefs is Map) {
      type = prefs['verification_document_type'];
    } else if (prefs is String && prefs.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(prefs);
        if (decoded is Map) type = decoded['verification_document_type'];
      } catch (_) {}
    }
    return type == 'valid_id' ? 'Valid ID' : 'Business Permit / DTI';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marketplace Administration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              'Review and manage local shops',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MarketplaceAllOrders()),
            ),
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('All Orders'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh shops',
            onPressed: _loading ? null : _loadShops,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadShops,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 900
                ? 32.0
                : constraints.maxWidth >= 600
                ? 24.0
                : 16.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 40),
              children: [
                _buildSummary(),
                const SizedBox(height: 20),
                _buildControls(),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filteredShops.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredShops.map(_buildShopCard),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 4
            : width >= 520
            ? 2
            : 1;
        final cardWidth = (width - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summaryCard(
              'All shops',
              _shops.length,
              Icons.storefront_rounded,
              _blue,
              cardWidth,
            ),
            _summaryCard(
              'Visible',
              _count('visible'),
              Icons.visibility_rounded,
              _green,
              cardWidth,
            ),
            _summaryCard(
              'In review',
              _count('in_review'),
              Icons.manage_search_rounded,
              _amber,
              cardWidth,
            ),
            _summaryCard(
              'Rejected / Suspended',
              _count('rejected') + _count('banned'),
              Icons.cancel_outlined,
              _red,
              cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
    String label,
    int count,
    IconData icon,
    Color color,
    double width,
  ) {
    return Container(
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 24,
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
        ],
      ),
    );
  }

  Widget _buildControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final search = TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search shops, owner email, type, or address',
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
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
          ),
        );
        final statuses = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'all',
                label: Text('All'),
                icon: Icon(Icons.apps_rounded),
              ),
              ButtonSegment(
                value: 'visible',
                label: Text('Visible'),
                icon: Icon(Icons.visibility_rounded),
              ),
              ButtonSegment(
                value: 'in_review',
                label: Text('In review'),
                icon: Icon(Icons.pending_actions_rounded),
              ),
              ButtonSegment(
                value: 'rejected',
                label: Text('Rejected'),
                icon: Icon(Icons.cancel_outlined),
              ),
            ],
            selected: {_selectedStatus},
            onSelectionChanged: (value) =>
                setState(() => _selectedStatus = value.first),
          ),
        );
        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              statuses,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [search, const SizedBox(height: 12), statuses],
        );
      },
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    final status = _statusOf(shop);
    final sellerId = shop['seller_id']?.toString() ?? '';
    final busy = _processingSellerId == sellerId;
    final logo = shop['seller_logo']?.toString();
    final name = shop['seller_store_name']?.toString() ?? 'Unnamed shop';
    final type =
        shop['seller_store_type']?.toString() ?? 'Unspecified shop type';

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
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 72,
                  height: 72,
                  color: _background,
                  child: logo == null || logo.isEmpty
                      ? const Icon(
                          Icons.storefront_rounded,
                          color: _muted,
                          size: 32,
                        )
                      : Image.network(
                          logo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.storefront_rounded,
                                color: _muted,
                              ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        _statusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type,
                      style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _addressText(shop['seller_store_address']),
                      style: const TextStyle(color: _muted, height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shop['seller_email_address']?.toString() ??
                          'No seller email provided',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoPill(
                          Icons.verified_user_rounded,
                          _verificationDocumentLabel(shop),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = _buildActions(shop, status, busy);
          if (constraints.maxWidth >= 760) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: details),
                const SizedBox(width: 18),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [details, const SizedBox(height: 16), actions],
          );
        },
      ),
    );
  }

  Widget _buildActions(Map<String, dynamic> shop, String status, bool busy) {
    if (busy) {
      return const SizedBox(
        width: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
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
                sellerId: shop['seller_id'].toString(),
                sellerData: shop,
              ),
            ),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('View'),
        ),
        if (status != 'visible')
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => _changeStatus(shop, 'visible'),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
          ),
        if (status == 'visible')
          OutlinedButton.icon(
            onPressed: () => _changeStatus(shop, 'in_review'),
            icon: const Icon(Icons.visibility_off_rounded, size: 18),
            label: const Text('Hide'),
          ),
        if (status != 'rejected' && status != 'banned')
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: _red),
            onPressed: () => _showRejectDialog(shop),
            icon: Icon(
              status == 'visible' ? Icons.block_rounded : Icons.close_rounded,
              size: 18,
            ),
            label: Text(status == 'visible' ? 'Suspend' : 'Reject'),
          ),
      ],
    );
  }

  Widget _infoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _blue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'visible'
        ? _green
        : status == 'rejected' || status == 'banned'
        ? _red
        : _amber;
    final label = status == 'visible'
        ? 'VISIBLE'
        : status == 'rejected'
        ? 'REJECTED'
        : status == 'banned'
        ? 'SUSPENDED'
        : 'IN REVIEW';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(Icons.storefront_outlined, size: 52, color: _muted),
          const SizedBox(height: 12),
          const Text(
            'No shops found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _query.isEmpty
                ? 'There are no shops in this status.'
                : 'Try a different search term.',
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }
}
