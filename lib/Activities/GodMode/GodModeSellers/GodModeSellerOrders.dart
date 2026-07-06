import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/GodMode/GodModeSellers/GodModeSellerOrdersPanel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GodModeSellerOrders extends StatefulWidget {
  const GodModeSellerOrders({
    super.key,
    this.initialSellerId,
  });

  final String? initialSellerId;

  @override
  State<GodModeSellerOrders> createState() => _GodModeSellerOrdersState();
}

class _GodModeSellerOrdersState extends State<GodModeSellerOrders> {
  static const _bg = Color(0xFFF8FAFC);
  static const _primary = Color(0xFF0A2E5C);
  static const _red = Color(0xFFDC2626);

  final _supabase = Supabase.instance.client;
  final _ordersKey = GlobalKey<GodModeSellerOrdersPanelState>();

  List<Map<String, dynamic>> _sellers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSellers();
  }

  Future<void> _loadSellers() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('sellers')
          .select()
          .order('seller_store_name', ascending: true);
      if (!mounted) return;
      setState(() {
        _sellers = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
      final sellerId = widget.initialSellerId;
      if (sellerId != null && sellerId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ordersKey.currentState?.showSeller(sellerId);
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Unable to load sellers: $error', error: true);
    }
  }

  Future<void> _refresh() async {
    await _loadSellers();
    await _ordersKey.currentState?.refresh();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _red : _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          'Seller Orders',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 36),
          children: [
            _hero(),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: _primary)),
              )
            else
              GodModeSellerOrdersPanel(
                key: _ordersKey,
                sellers: _sellers,
                onError: (message) => _toast(message, error: true),
              ),
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
          Icon(Icons.receipt_long_rounded, color: Color(0xFFF59E0B), size: 34),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'God Mode Seller Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Review marketplace orders separately from shop approval and seller status controls.',
                  style: TextStyle(color: Color(0xFFE2E8F0), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
