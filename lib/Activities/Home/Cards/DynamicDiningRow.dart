import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/Municipalities.dart';
import 'package:gasan_port_tracker/Activities/Seller/StoreItemDetails.dart';
import 'package:gasan_port_tracker/Activities/StoreItemsGallery.dart';

// --- DATA MODEL ---
class FoodItem {
  final String id;
  final String name;
  final String merchant;
  final String price;
  final String imageSource; // Can be URL or Hex
  final Map<String, dynamic> rawData; // Keep raw data for navigation

  FoodItem({
    required this.id,
    required this.name,
    required this.merchant,
    required this.price,
    required this.imageSource,
    required this.rawData,
  });

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    // Extract merchant name from joined 'sellers' table
    final seller = map['sellers'];
    final merchantName = seller != null ? seller['seller_store_name'] : "Unknown Merchant";

    // Handle images list (take first image)
    String img = "";
    final rawImages = map['item_images'];
    if (rawImages is List && rawImages.isNotEmpty) {
      img = rawImages[0].toString();
    } else if (rawImages is String) {
      img = rawImages;
    }

    return FoodItem(
      id: map['item_id']?.toString() ?? "",
      name: map['item_name']?.toString() ?? "Unnamed Item",
      merchant: merchantName.toString(),
      price: "₱${Utility().formatPrice(map['item_price'])}",
      imageSource: img,
      rawData: map,
    );
  }
}

class DynamicDiningRow extends StatefulWidget {
  final String municipality;
  final int municipalZipCode;

  const DynamicDiningRow({
    super.key,
    this.municipality = "Gasan",
    this.municipalZipCode = 0,
  });

  @override
  State<DynamicDiningRow> createState() => _DynamicDiningRowState();
}

class _DynamicDiningRowState extends State<DynamicDiningRow> {
  final _supabase = Supabase.instance.client;
  List<FoodItem> _allItems = [];
  List<FoodItem> _liveSlots = [];
  bool _isLoading = true;

  Timer? _timer;
  final Random _random = Random();
  int _fetchToken = 0;

  // Premium E-Commerce Palette
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color themeOrange = const Color(0xFFEA580C);
  final Color cardBorder = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _fetchFoodItems();
  }

  @override
  void didUpdateWidget(covariant DynamicDiningRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.municipalZipCode != widget.municipalZipCode) {
      _timer?.cancel();
      _isLoading = true;
      _fetchFoodItems();
    }
  }

  Future<void> _fetchFoodItems() async {
    final token = ++_fetchToken;
    _timer?.cancel();
    final zip = widget.municipalZipCode;
    debugPrint("Dining fetch zip=$zip token=$token");
    _allItems = [];
    if (mounted) setState(() => _liveSlots = []);

    try {
      var query = _supabase
          .from('store_items')
          .select('*, sellers(seller_store_name, seller_logo, seller_store_address)')
          .eq('item_type', 'food')
          .eq('item_available', true);

      final data = await query.limit(50);
      if (token != _fetchToken) {
        debugPrint("Dining fetch stale token=$token (current=$_fetchToken), discarding");
        return;
      }
      var rows = List<Map<String, dynamic>>.from(data);
      if (zip != 0) {
        rows = rows.where((item) {
          final origin = num.tryParse('${item['item_municipality_origin'] ?? ''}');
          if (origin != null && origin == zip) return true;
          final addr = item['sellers']?['seller_store_address'];
          if (addr is Map) {
            final sellerZip = num.tryParse('${addr['zip_code'] ?? ''}');
            if (sellerZip != null && sellerZip == zip) return true;
          }
          return false;
        }).toList();
      }
      debugPrint("Dining fetched ${rows.length} items for zip=$zip");

      _allItems = rows.map((item) => FoodItem.fromMap(item)).toList();
      _setupLiveSlots();
    } catch (e) {
      debugPrint("Error fetching food items: $e");
    } finally {
      if (token == _fetchToken && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupLiveSlots() {
    if (_allItems.isEmpty) return;

    // Grab items up to max 10
    int initialCount = min(10, _allItems.length);
    List<FoodItem> shuffledItems = List.from(_allItems)..shuffle(_random);
    
    setState(() {
      _liveSlots = shuffledItems.take(initialCount).toList();
    });

    _startRotationTimer();
  }

  void _startRotationTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (!mounted) return;
      if (_allItems.length <= _liveSlots.length) return;

      List<FoodItem> availableItems = _allItems.where((item) => !_liveSlots.any((slot) => slot.id == item.id)).toList();

      if (availableItems.isEmpty) return;

      setState(() {
        int randomSlotIndex = _random.nextInt(_liveSlots.length);
        FoodItem newItem = availableItems[_random.nextInt(availableItems.length)];
        _liveSlots[randomSlotIndex] = newItem;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_liveSlots.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              // Create the list of cards with a fixed width to prevent stretching
              List<Widget> rowChildren = [];
              for (int i = 0; i < _liveSlots.length; i++) {
                rowChildren.add(
                  SizedBox(
                    width: 140, // Fixed width like Shopee items
                    child: _buildECommerceCard(_liveSlots[i]),
                  ),
                );
                if (i < _liveSlots.length - 1) {
                  rowChildren.add(const SizedBox(width: 12)); // Consistent spacing
                }
              }

              return SizedBox(
                height: 220,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rowChildren,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "DISCOVER FOODS IN ${(Municipalities.getNameByZip(widget.municipalZipCode) ?? widget.municipality).toUpperCase()}",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 0.8),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreItemsGallery()),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Text(
                    "See More",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: themeOrange),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: themeOrange, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildECommerceCard(FoodItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10), // Smaller, more Shopee-like radius
        border: Border.all(color: cardBorder.withValues(alpha: 0.8), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            StoreItemDetails.open(context, item.rawData);
          },
          child: AnimatedSwitcher(

            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _buildInnerCardContent(item, key: ValueKey(item.id)),
          ),
        ),
      ),
    );
  }

  Widget _buildInnerCardContent(FoodItem item, {required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- TOP HALF: HERO IMAGE (Square-ish) ---
        Expanded(
          flex: 11,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            child: _buildImage(item.imageSource),
          ),
        ),

        // --- BOTTOM HALF: E-COMMERCE DETAILS ---
        Expanded(
          flex: 9,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: primaryDark, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.merchant,
                      style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),

                Text(
                  item.price,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: themeOrange),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String src) {
    if (src.isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: Icon(Icons.restaurant_rounded, color: textSecondary.withValues(alpha: 0.3), size: 32),
      );
    }

    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF1F5F9),
          child: Icon(Icons.restaurant_rounded, color: textSecondary.withValues(alpha: 0.3), size: 32),
        ),
      );
    }

    // Try hex decoding
    final bytes = Utility.decodeHexImage(src);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF1F5F9),
          child: Icon(Icons.restaurant_rounded, color: textSecondary.withValues(alpha: 0.3), size: 32),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Icon(Icons.restaurant_rounded, color: textSecondary.withValues(alpha: 0.3), size: 32),
    );
  }
}
