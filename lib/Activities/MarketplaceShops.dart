import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/MyCart.dart';
import 'package:gasan_port_tracker/Activities/ViewShop.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceShops extends StatefulWidget {
  const MarketplaceShops({super.key, this.isTab = false});

  final bool isTab;

  @override
  State<MarketplaceShops> createState() => _MarketplaceShopsState();
}

class _MarketplaceShopsState extends State<MarketplaceShops> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  final Color _primary = const Color(0xFF0A2E5C);
  final Color _accent = const Color(0xFF0D9488);
  final Color _muted = const Color(0xFF64748B);
  final Color _border = const Color(0xFFE2E8F0);

  bool _loading = true;
  String _query = '';
  List<Map<String, dynamic>> _shops = [];

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
      final data = await _supabase
          .from('sellers')
          .select(
            'seller_id, seller_store_name, seller_store_description, seller_store_type, seller_logo, seller_cover_image, seller_store_address, seller_store_status, seller_last_active, seller_operating_hours, seller_store_coordinates, seller_contact_number, seller_email_address, seller_messenger_link, seller_payment_method, seller_preferences, seller_delivery_rates',
          )
          .eq('seller_store_status', 'visible')
          .order('seller_store_name', ascending: true);
      if (mounted) _shops = List<Map<String, dynamic>>.from(data);
    } catch (error) {
      debugPrint('MarketplaceShops load error: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to load shops.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredShops {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _shops;
    return _shops.where((shop) {
      return [
        shop['seller_store_name'],
        shop['seller_store_type'],
        shop['seller_store_description'],
        _addressText(shop['seller_store_address']),
      ].whereType<Object>().any((value) {
        return value.toString().toLowerCase().contains(q);
      });
    }).toList();
  }

  String _addressText(dynamic raw) {
    if (raw is! Map) return '';
    final parts = [
      raw['barangay'],
      raw['municipality'],
      raw['province'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty);
    return parts.join(', ');
  }

  ImageProvider? _shopImage(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.startsWith('http')) return NetworkImage(value);
    final bytes = Utility.decodeHexImage(value);
    return bytes == null ? null : MemoryImage(bytes);
  }

  void _openShop(Map<String, dynamic> shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'ViewShop:${shop['seller_id']}'),
        builder: (_) =>
            ViewShop(sellerId: shop['seller_id'].toString(), sellerData: shop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _loadShops,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _searchBox()),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredShops.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _emptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: _filteredShops.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _shopCard(_filteredShops[index]),
              ),
            ),
        ],
      ),
    );

    if (widget.isTab) {
      return SafeArea(top: false, child: body);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        title: const Text(
          'Local Shops',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyCart()),
            ),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: body,
    );
  }

  Widget _searchBox() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, widget.isTab ? 16 : 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        decoration: const InputDecoration(
          hintText: 'Search shops, category, location...',
          hintStyle: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _shopCard(Map<String, dynamic> shop) {
    final name = shop['seller_store_name']?.toString() ?? 'Local Shop';
    final type = shop['seller_store_type']?.toString() ?? 'Local seller';
    final address = _addressText(shop['seller_store_address']);
    final logo = _shopImage(shop['seller_logo']?.toString());
    final cover = _shopImage(shop['seller_cover_image']?.toString());
    final hours = _operatingHours(shop['seller_operating_hours']);
    final today = _todayName();
    final todayHours = hours[today];
    final status = _hoursStatus(todayHours);
    final statusColor = status.isOpen
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openShop(shop),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Cover Banner
                SizedBox(
                  height: 115,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cover != null)
                        Image(image: cover, fit: BoxFit.cover)
                      else
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFEFF6FF), Color(0xFFE2F1F8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      // Soft darkening gradient overlay for depth
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Open/Closed status badge on cover
                      if (hours.isNotEmpty)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 190),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status.isOpen
                                      ? Icons.check_circle_rounded
                                      : Icons.access_time_filled_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  status.isOpen ? status.range : 'Closed today',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Shop Details Section with Logo alignment
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular Shop Logo
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: _accent.withValues(alpha: 0.08),
                            backgroundImage: logo,
                            child: logo == null
                                ? Icon(
                                    Icons.storefront_rounded,
                                    color: _accent,
                                    size: 24,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Core details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _primary,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            // Category Tag & Location
                            Row(
                              children: [
                                // Category Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: _accent,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                if (address.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Visit button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Visit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Operating Hours expandable section
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _dayOfWeekLabel(int weekday) => _days[weekday - 1];

  String _todayName() => _dayOfWeekLabel(DateTime.now().weekday);

  Map<String, Map<String, dynamic>> _operatingHours(dynamic raw) {
    Map source = {};
    if (raw is Map) {
      source = raw;
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) source = decoded;
      } catch (_) {
        return {};
      }
    }

    return {
      for (final day in _days)
        if (source[day] is Map) day: Map<String, dynamic>.from(source[day]),
    };
  }

  int? _minutesOf(String? value) {
    if (value == null || !value.contains(':')) return null;
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  String _format12Hour(String? value) {
    final minutes = _minutesOf(value);
    if (minutes == null) return '--';
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  bool _isOpenNow(Map<String, dynamic> hours) {
    if (hours['closed'] == true) return false;
    final open = _minutesOf(hours['open']?.toString());
    final close = _minutesOf(hours['close']?.toString());
    if (open == null || close == null) return false;
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    if (close < open) return current >= open || current <= close;
    return current >= open && current <= close;
  }

  _ShopHoursStatus _hoursStatus(Map<String, dynamic>? hours) {
    if (hours == null || hours['closed'] == true) {
      return const _ShopHoursStatus(false, 'Closed today', 'Closed');
    }
    final range =
        '${_format12Hour(hours['open']?.toString())} - '
        '${_format12Hour(hours['close']?.toString())}';
    final openNow = _isOpenNow(hours);
    return _ShopHoursStatus(
      openNow,
      openNow ? 'Open now' : 'Closed now',
      range,
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, color: _muted, size: 42),
            const SizedBox(height: 12),
            Text(
              'No shops found',
              style: TextStyle(
                color: _primary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another keyword or refresh the list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopHoursStatus {
  const _ShopHoursStatus(this.isOpen, this.label, this.range);

  final bool isOpen;
  final String label;
  final String range;
}
