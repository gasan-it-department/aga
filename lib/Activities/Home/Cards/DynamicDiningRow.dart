import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Activities/MainNavigation.dart';
import 'package:gasan_port_tracker/Activities/Home/Cards/LiveTouristCard.dart';
import 'package:gasan_port_tracker/Activities/MarketplaceShops.dart';
import 'package:gasan_port_tracker/Activities/Seller/SellerProfile.dart';
import 'package:gasan_port_tracker/Activities/ViewShop.dart';
import 'package:gasan_port_tracker/Utility/Municipalities.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class DynamicDiningRow extends StatefulWidget {
  final String municipality;
  final int municipalZipCode;
  final List<Map<String, dynamic>> touristSpots;

  const DynamicDiningRow({
    super.key,
    this.municipality = "Gasan",
    this.municipalZipCode = 0,
    this.touristSpots = const [],
  });

  @override
  State<DynamicDiningRow> createState() => _DynamicDiningRowState();
}

class _DynamicDiningRowState extends State<DynamicDiningRow> {
  final _supabase = Supabase.instance.client;
  final _random = Random();
  List<Map<String, dynamic>> _shops = [];
  bool _loading = true;

  static const primaryDark = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const cardBorder = Color(0xFFE2E8F0);
  static const accent = Color(0xFF2563EB);
  static const placeAccent = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  @override
  void didUpdateWidget(covariant DynamicDiningRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.municipalZipCode != widget.municipalZipCode) {
      _fetchShops();
    }
  }

  Future<void> _fetchShops() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('sellers')
          .select()
          .eq('seller_store_status', 'visible')
          .limit(50);
      var shops = List<Map<String, dynamic>>.from(data);
      if (widget.municipalZipCode != 0) {
        shops = shops.where((shop) {
          final address = shop['seller_store_address'];
          if (address is! Map) return false;
          return num.tryParse('${address['zip_code'] ?? ''}') ==
              widget.municipalZipCode;
        }).toList();
      }
      shops.shuffle(_random);
      if (mounted) setState(() => _shops = shops.take(12).toList());
    } catch (error) {
      debugPrint('Discover shops fetch failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _shops.isEmpty) return const SizedBox.shrink();
    final municipality =
        Municipalities.getNameByZip(widget.municipalZipCode) ??
        widget.municipality;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.storefront_rounded,
            title: "Local Shops",
            subtitle: "Handpicked stores around $municipality",
            count: "${_shops.length}",
            color: accent,
            actionLabel: "Marketplace",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MarketplaceShops()),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 20),
              itemCount: _shops.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (_, index) => _shopCard(_shops[index]),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: _sellerCtaCard(),
          ),
          if (widget.touristSpots.isNotEmpty) ...[
            const SizedBox(height: 30),
            _sectionTitle(
              icon: Icons.travel_explore_rounded,
              title: "Places to Explore",
              subtitle: "Scenic spots and tourist favorites",
              count: "${widget.touristSpots.length}",
              color: placeAccent,
              actionLabel: "Map",
              onPressed: () => MainNavigation.selectedTab.value = 1,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(right: 20),
                itemCount: widget.touristSpots.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (_, index) => TourismView(
                  key: ValueKey(widget.touristSpots[index]['spot_id']),
                  spot: widget.touristSpots[index],
                  performanceMode: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
    required String count,
    required Color color,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.16)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: primaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(
              actionLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sellerCtaCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 350;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SellerProfile()),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE6F8F9), Color(0xFFDFF7F2)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBEFF0)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -12,
                    bottom: -12,
                    child: Icon(
                      Icons.water_rounded,
                      size: narrow ? 76 : 94,
                      color: const Color(0xFF0E9EA7).withValues(alpha: 0.13),
                    ),
                  ),
                  Positioned(
                    right: narrow ? 10 : 18,
                    top: 10,
                    child: Icon(
                      Icons.spa_rounded,
                      size: narrow ? 18 : 22,
                      color: const Color(0xFF159B87).withValues(alpha: 0.2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      narrow ? 12 : 16,
                      narrow ? 13 : 16,
                      narrow ? 12 : 16,
                      narrow ? 13 : 16,
                    ),
                    child: narrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  _businessIllustration(compact: true),
                                  const SizedBox(width: 11),
                                  const Expanded(child: _BusinessCtaText()),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _businessActionButton(),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              _businessIllustration(compact: false),
                              const SizedBox(width: 15),
                              const Expanded(child: _BusinessCtaText()),
                              const SizedBox(width: 12),
                              _businessActionButton(),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _businessIllustration({required bool compact}) {
    final size = compact ? 54.0 : 66.0;
    return SizedBox(
      width: size,
      height: compact ? 52 : 58,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            bottom: 3,
            child: Icon(
              Icons.eco_rounded,
              size: compact ? 22 : 26,
              color: const Color(0xFF22C55E).withValues(alpha: 0.42),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 3,
            child: Icon(
              Icons.eco_rounded,
              size: compact ? 19 : 23,
              color: const Color(0xFF16A34A).withValues(alpha: 0.34),
            ),
          ),
          Container(
            width: compact ? 42 : 50,
            height: compact ? 40 : 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  child: Container(
                    width: compact ? 36 : 44,
                    height: compact ? 13 : 15,
                    decoration: const BoxDecoration(
                      color: Color(0xFF14B8A6),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(7),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: compact ? 7 : 8,
                  child: Container(
                    width: compact ? 40 : 48,
                    height: compact ? 10 : 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF67E8F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 7,
                  child: Container(
                    width: compact ? 22 : 26,
                    height: compact ? 17 : 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF0F766E),
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessActionButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5A8), Color(0xFF0891B2)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0891B2).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Explore Tools",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
        ],
      ),
    );
  }

  Widget _shopCard(Map<String, dynamic> shop) {
    final name = (shop['seller_store_name'] ?? 'Local Shop').toString();
    final logo = shop['seller_logo']?.toString() ?? '';
    final address = shop['seller_store_address'];
    final location = address is Map
        ? [address['barangay'], address['municipality']]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join(', ')
        : '';

    return SizedBox(
      width: 162,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewShop(
                sellerId: shop['seller_id'].toString(),
                sellerData: shop,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _shopImage(logo),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.46),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Text(
                          "LOCAL",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: primaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location.isEmpty
                                ? 'Local marketplace seller'
                                : location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shopImage(String source) {
    if (source.startsWith('http')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        cacheWidth: 360,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    final bytes = Utility.decodeHexImage(source);
    return bytes == null
        ? _placeholder()
        : Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: 360,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
          );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(Icons.storefront_rounded, color: accent, size: 38),
    );
  }
}

class _BusinessCtaText extends StatelessWidget {
  const _BusinessCtaText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "For Business Owners",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "Grow your business with AGA.\nList your products and reach more customers.",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF52627A),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
