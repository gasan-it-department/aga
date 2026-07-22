import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/ImageViewer.dart';
import 'package:gasan_port_tracker/Utility/ItemVariations.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'package:gasan_port_tracker/Utility/MasonryGrid.dart';
import 'package:gasan_port_tracker/Utility/ChatService.dart';
import 'package:gasan_port_tracker/Activities/Chat/ChatThread.dart';
import 'package:gasan_port_tracker/Dialogs/Bottomsheets/DeliveryRatesViewer.dart';
import 'package:gasan_port_tracker/Activities/MyCart.dart';
import 'package:gasan_port_tracker/Activities/ViewShop.dart';
import 'package:gasan_port_tracker/Activities/Seller/Checkout.dart';
import 'package:share_plus/share_plus.dart';

class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class StoreItemDetails extends StatefulWidget {
  final Map<String, dynamic> item;

  static final Set<String> openItems = <String>{};

  const StoreItemDetails({super.key, required this.item});

  static void open(BuildContext context, Map<String, dynamic> item) {
    final id = item['item_id']?.toString() ?? '';
    if (id.isNotEmpty && openItems.contains(id)) {
      Navigator.of(context).popUntil(
        (route) =>
            route.settings.name == 'StoreItemDetails:$id' || route.isFirst,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'StoreItemDetails:$id'),
        builder: (_) => StoreItemDetails(item: item),
      ),
    );
  }

  @override
  State<StoreItemDetails> createState() => _StoreItemDetailsState();
}

class _StoreItemDetailsState extends State<StoreItemDetails> {
  final _supabase = Supabase.instance.client;
  int _activeImage = 0;
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoadingRecs = true;
  bool? _isPaymentFirst;
  bool _isInStorePickup = false;

  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color themeOrange = const Color(0xFFEE4D2D);
  final Color bgColor = const Color(0xFFF1F5F9);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color successColor = const Color(0xFF10B981);
  final Color warningColor = const Color(0xFFF59E0B);

  List<Map<String, dynamic>> _deliveryRates = [];
  bool _isLoadingRates = true;
  int _cartCount = 0;

  // Variation state
  List<Map<String, dynamic>> _variations = [];
  Map<String, dynamic>? _selectedVariation;

  @override
  void initState() {
    super.initState();
    final id = widget.item['item_id']?.toString();
    if (id != null) StoreItemDetails.openItems.add(id);
    _variations = ItemVariations.parse(widget.item['item_variations']);
    _resolvePaymentFirst();
    _fetchRecommendations();
    _fetchDeliveryRates();
    _fetchCartCount();
  }

  @override
  void dispose() {
    final id = widget.item['item_id']?.toString();
    if (id != null) StoreItemDetails.openItems.remove(id);
    super.dispose();
  }

  bool _isCartBusy = false;
  String? _cartRowId;

  Future<void> _shareItem() async {
    final itemId = widget.item['item_id']?.toString().trim() ?? '';
    if (itemId.isEmpty) return;
    final itemName = widget.item['item_name']?.toString().trim();
    final link = Uri.parse(
      'https://aga-app.gasan.workers.dev/market/item/$itemId',
    );
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Check out ${itemName?.isNotEmpty == true ? itemName : 'this item'} on AGA:\n$link',
        title: itemName ?? 'AGA Market item',
      ),
    );
  }

  Future<void> _fetchCartCount() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      final itemId = widget.item['item_id']?.toString();
      final data = await _supabase
          .from('cart')
          .select('cart_id, cart_item_id')
          .eq('cart_user_id', uid);
      final list = List<Map<String, dynamic>>.from(data);
      String? existingId;
      for (final row in list) {
        if (row['cart_item_id']?.toString() == itemId) {
          existingId = row['cart_id']?.toString();
          break;
        }
      }
      if (mounted) {
        setState(() {
          _cartCount = list.length;
          _cartRowId = existingId;
        });
      }
    } catch (e) {
      debugPrint("Error fetching cart count: $e");
    }
  }

  Future<void> _addToCart() async {
    if (_isCartBusy) return;
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      _showSnack("Please sign in to add to cart.");
      return;
    }
    final itemId = widget.item['item_id']?.toString();
    if (itemId == null || itemId.isEmpty) return;
    if (_cartRowId != null) {
      _showSnack("Already in cart.");
      return;
    }
    if (_variations.isNotEmpty && _selectedVariation == null) {
      _showSnack("Please choose a variation first.");
      return;
    }
    setState(() => _isCartBusy = true);
    try {
      final util = Utility();
      final cartId = 'CART_${util.generateUniqueID()}';
      await _supabase.from('cart').insert({
        'cart_id': cartId,
        'cart_user_id': uid,
        'cart_item_id': itemId,
        'cart_date_added': util.getCurrentMSEpochTime() / 1000,
        if (_selectedVariation != null) 'cart_variation': _selectedVariation,
      });
      if (mounted) {
        setState(() {
          _cartRowId = cartId;
          _cartCount += 1;
        });
        _showSnack("Added to cart.");
      }
    } catch (e) {
      debugPrint("Add to cart error: $e");
      _showSnack("Failed to add to cart.");
    } finally {
      if (mounted) setState(() => _isCartBusy = false);
    }
  }

  Future<void> _removeFromCart() async {
    if (_isCartBusy || _cartRowId == null) return;
    setState(() => _isCartBusy = true);
    try {
      await _supabase.from('cart').delete().eq('cart_id', _cartRowId!);
      if (mounted) {
        setState(() {
          _cartRowId = null;
          if (_cartCount > 0) _cartCount -= 1;
        });
        _showSnack("Removed from cart.");
      }
    } catch (e) {
      debugPrint("Remove from cart error: $e");
      _showSnack("Failed to remove from cart.");
    } finally {
      if (mounted) setState(() => _isCartBusy = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildCartAction({Color iconColor = Colors.white, bool dark = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyCart()),
              );
              _fetchCartCount();
            },
            icon: dark
                ? Icon(Icons.shopping_cart_rounded, color: iconColor, size: 22)
                : CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    child: const Icon(
                      Icons.shopping_cart_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
          ),
          if (_cartCount > 0)
            Positioned(
              right: 4,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: themeOrange,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  _cartCount > 99 ? '99+' : '$_cartCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShareAction({
    Color iconColor = Colors.white,
    bool dark = false,
  }) {
    return IconButton(
      tooltip: 'Share item',
      onPressed: _shareItem,
      icon: dark
          ? Icon(Icons.share_rounded, color: iconColor, size: 22)
          : CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              child: const Icon(
                Icons.share_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
    );
  }

  Future<void> _fetchDeliveryRates() async {
    try {
      final String? sellerId =
          widget.item['item_seller_id']?.toString() ??
          widget.item['seller_id']?.toString();
      if (sellerId == null || sellerId.isEmpty) return;

      final res = await _supabase
          .from('sellers')
          .select('seller_delivery_rates')
          .eq('seller_id', sellerId)
          .maybeSingle();

      final raw = res?['seller_delivery_rates'];
      final List<Map<String, dynamic>> parsed = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      parsed.sort((a, b) {
        final av = (a['rate_amount'] as num?)?.toDouble() ?? 0;
        final bv = (b['rate_amount'] as num?)?.toDouble() ?? 0;
        return av.compareTo(bv);
      });

      if (mounted) {
        setState(() {
          _deliveryRates = parsed;
          _isLoadingRates = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching delivery rates: $e");
      if (mounted) setState(() => _isLoadingRates = false);
    }
  }

  void _resolvePaymentFirst() {
    final seller = widget.item['sellers'];
    if (seller is Map && seller['seller_payment_method'] != null) {
      _readPaymentMethods(seller['seller_payment_method']);
    }
    if (seller is Map && seller['seller_preferences'] != null) {
      _readPrefs(seller['seller_preferences']);
      if (seller['seller_payment_method'] != null) return;
    }
    _fetchSellerPrefs();
  }

  void _readPaymentMethods(dynamic pm) {
    // Pickup is no longer driven by payment_method; see _readPrefs (uses fulfillment).
  }

  void _readPrefs(dynamic prefs) {
    try {
      Map<String, dynamic> map = {};
      if (prefs is Map<String, dynamic>) {
        map = prefs;
      } else if (prefs is String) {
        map = jsonDecode(prefs);
      }
      final ff = map['fulfillment'];
      final hasDelivery = ff is List
          ? ff.map((e) => e.toString()).contains("Delivery")
          : true;
      final hasPickup = ff is List
          ? ff.map((e) => e.toString()).contains("In-Store Pickup")
          : false;
      if (mounted) {
        setState(() {
          _isPaymentFirst = map['is_payment_first'] == true;
          _isInStorePickup = hasPickup && !hasDelivery;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchSellerPrefs() async {
    try {
      final String? sellerId =
          widget.item['item_seller_id']?.toString() ??
          widget.item['seller_id']?.toString();
      if (sellerId == null || sellerId.isEmpty) return;
      final row = await _supabase
          .from('sellers')
          .select('seller_preferences, seller_payment_method')
          .eq('seller_id', sellerId)
          .maybeSingle();
      if (row != null) {
        _readPrefs(row['seller_preferences']);
        _readPaymentMethods(row['seller_payment_method']);
      }
    } catch (e) {
      debugPrint("Error fetching seller prefs: $e");
    }
  }

  Future<void> _fetchRecommendations() async {
    try {
      final String currentId = widget.item['item_id'] ?? '';

      final data = await _supabase
          .from('store_items')
          .select(
            '*, sellers!inner(seller_store_name, seller_logo, seller_store_status)',
          )
          .eq('item_available', true)
          .eq('sellers.seller_store_status', 'visible')
          .neq('item_id', currentId)
          .limit(60);

      final pool = List<Map<String, dynamic>>.from(data)..shuffle();

      setState(() {
        _recommendations = pool.take(10).toList();
      });
    } catch (e) {
      debugPrint("Error fetching recommendations: $e");
    } finally {
      if (mounted) setState(() => _isLoadingRecs = false);
    }
  }

  List<Map<String, dynamic>> _sellableVariationsFor(Map<String, dynamic> item) {
    final vars = item['item_variations'];
    final parsed = vars is List
        ? vars.whereType<Map>().map((v) => Map<String, dynamic>.from(v))
        : ItemVariations.parse(vars);
    return parsed.where((variation) {
      final stock = num.tryParse(variation['stock']?.toString() ?? '0') ?? 0;
      final price = num.tryParse(variation['price']?.toString() ?? '');
      return (stock < 0 || stock > 0) && price != null;
    }).toList();
  }

  num _displayPriceFor(Map<String, dynamic> item) {
    final variations = _sellableVariationsFor(item);
    if (variations.isNotEmpty) {
      variations.sort((a, b) {
        final aPrice = num.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final bPrice = num.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return aPrice.compareTo(bPrice);
      });
      return num.tryParse(variations.first['price']?.toString() ?? '0') ?? 0;
    }
    final rawPrice = item['item_price'];
    return rawPrice is num
        ? rawPrice
        : (num.tryParse(rawPrice?.toString() ?? '0') ?? 0);
  }

  Future<void> _openChat() async {
    final String? sellerId =
        widget.item['item_seller_id']?.toString() ??
        widget.item['seller_id']?.toString();
    if (sellerId == null || sellerId.isEmpty) return;
    final chat = ChatService();
    if (chat.currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please sign in to chat.")));
      return;
    }
    if (chat.currentUserId == sellerId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("This is your own store.")));
      return;
    }
    final sellersRaw = widget.item['sellers'];
    final String title =
        (sellersRaw is Map && sellersRaw['seller_store_name'] != null)
        ? sellersRaw['seller_store_name'].toString()
        : 'Store';
    try {
      final itemId = widget.item['item_id']?.toString();
      final convo = await chat.findConversation(sellerId: sellerId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThread(
            conversationId: convo?['conversation_id']?.toString(),
            sellerId: sellerId,
            itemId: itemId,
            title: title,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't open chat: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dynamic rawImgs = widget.item['item_images'];
    final List<String> images = rawImgs is List
        ? rawImgs.map((e) => e.toString()).toList()
        : (rawImgs is String && rawImgs.isNotEmpty ? [rawImgs] : <String>[]);
    final String name = (widget.item['item_name'] ?? 'Unnamed Item').toString();
    final num price = (widget.item['item_price'] is num)
        ? widget.item['item_price'] as num
        : num.tryParse(widget.item['item_price']?.toString() ?? '0') ?? 0;
    final String description =
        (widget.item['item_description'] ?? 'No description available.')
            .toString();
    final bool isAvailable = widget.item['item_available'] == true;
    final dynamic sellersRaw = widget.item['sellers'];
    final Map<String, dynamic> sellerMap = sellersRaw is Map<String, dynamic>
        ? sellersRaw
        : <String, dynamic>{};
    final String merchant = (sellerMap['seller_store_name'] ?? 'Local Merchant')
        .toString();
    final String? merchantLogo = sellerMap['seller_logo']?.toString();

    final bool isDesktop = Responsive.isDesktop(context);
    final bool isTablet = Responsive.isTablet(context);
    final bool isWide = isDesktop || isTablet;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isWide
          ? AppBar(
              backgroundColor: Colors.white,
              foregroundColor: primaryDark,
              elevation: 0,
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              actions: [
                _buildShareAction(iconColor: primaryDark, dark: true),
                _buildCartAction(iconColor: primaryDark, dark: true),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: cardBorder, height: 1),
              ),
            )
          : null,
      body: isWide
          ? _buildWideLayout(
              images,
              name,
              price,
              description,
              isAvailable,
              merchant,
              merchantLogo,
            )
          : _buildMobileLayout(
              images,
              name,
              price,
              description,
              isAvailable,
              merchant,
              merchantLogo,
            ),
      bottomNavigationBar: _buildStickyBottomBar(),
    );
  }

  Widget _buildMobileLayout(
    List<String> images,
    String name,
    num price,
    String description,
    bool isAvailable,
    String merchant,
    String? merchantLogo,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 400,
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: primaryDark,
          leading: IconButton(
            icon: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [_buildShareAction(), _buildCartAction()],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildImageCarousel(images),
          ),
        ),
        SliverToBoxAdapter(child: _buildMainInfo(name, price, isAvailable)),
        if (_variations.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              child: _buildVariationSelector(),
            ),
          ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            child: _buildShippingRow(),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            child: _buildMerchantCard(merchant, merchantLogo),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            child: _buildDescriptionCard(description),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              "YOU MAY ALSO LIKE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: textSecondary,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildRecommendationsList()),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildWideLayout(
    List<String> images,
    String name,
    num price,
    String description,
    bool isAvailable,
    String merchant,
    String? merchantLogo,
  ) {
    final bool isDesktop = Responsive.isDesktop(context);
    final double imgHeight = isDesktop ? 520 : 440;
    final double maxW = isDesktop ? 1280 : 1024;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 20,
            24,
            isDesktop ? 32 : 20,
            120,
          ),
          children: [
            SizedBox(
              height: imgHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.white,
                        child: _buildImageCarousel(images),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _buildMainInfo(name, price, isAvailable),
                          ),
                          if (_variations.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildVariationSelector(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _buildShippingRow(),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _buildMerchantCard(merchant, merchantLogo),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildDescriptionCard(description),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
              child: Text(
                "YOU MAY ALSO LIKE",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            _buildRecommendationsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfo(String name, num price, bool isAvailable) {
    final String priceText = _selectedVariation != null
        ? "₱${Utility().formatPrice(_selectedVariation!['price'] as num? ?? price)}"
        : ItemVariations.priceLabel(
            widget.item['item_variations'],
            price,
            (v) => Utility().formatPrice(v),
          );
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  priceText,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: themeOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isAvailable ? "Available" : "Not Available",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isAvailable ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariationSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "VARIATION",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              if (_selectedVariation != null)
                Expanded(
                  child: Text(
                    _selectedVariation!['label'].toString(),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: primaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _variations.map((v) {
              final selected =
                  _selectedVariation != null &&
                  _selectedVariation!['label'] == v['label'];
              final stock = v['stock'] as num? ?? 0;
              final outOfStock = stock == 0;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: outOfStock
                    ? null
                    : () => setState(() => _selectedVariation = v),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? themeOrange.withValues(alpha: 0.08)
                        : bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? themeOrange : cardBorder,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        v['label'].toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: outOfStock ? textSecondary : primaryDark,
                          decoration: outOfStock
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        outOfStock
                            ? "Out of stock"
                            : stock < 0
                            ? "₱${Utility().formatPrice(v['price'])}"
                            : "₱${Utility().formatPrice(v['price'])} • Stock $stock",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: outOfStock ? Colors.red : textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingRow() {
    if (_isInStorePickup) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.storefront_rounded,
              color: const Color(0xFF10B981),
              size: 20,
            ),
            const SizedBox(width: 12),
            const Text(
              "Pickup:",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "In-Store Pickup only",
                style: TextStyle(
                  color: primaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "NO DELIVERY",
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final String display = _isLoadingRates
        ? "Loading rates..."
        : (_deliveryRates.isEmpty
              ? "No delivery rates set"
              : "${_deliveryRates.length} delivery area(s)");

    return InkWell(
      onTap: () {
        if (_deliveryRates.isNotEmpty) {
          final sellerMap = widget.item['sellers'] is Map<String, dynamic>
              ? widget.item['sellers'] as Map<String, dynamic>
              : <String, dynamic>{};
          DeliveryRatesViewer.show(
            context,
            rates: _deliveryRates,
            merchant: sellerMap['seller_store_name']?.toString(),
          );
        }
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.local_shipping_outlined, color: textSecondary, size: 20),
            const SizedBox(width: 12),
            const Text(
              "Delivery:",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                display,
                style: TextStyle(
                  color: _deliveryRates.isEmpty ? Colors.red : primaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_deliveryRates.isNotEmpty)
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _buyNow() {
    if (_variations.isNotEmpty && _selectedVariation == null) {
      _showSnack("Please choose a variation first.");
      return;
    }
    final basePrice =
        num.tryParse(widget.item['item_price']?.toString() ?? '0') ?? 0;
    final price = _selectedVariation != null
        ? (_selectedVariation!['price'] as num? ?? basePrice)
        : basePrice;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Checkout(
          selectedItems: [
            {
              'store_items': widget.item,
              'cart_quantity': 1,
              if (_selectedVariation != null)
                'cart_variation': _selectedVariation,
            },
          ],
          totalAmount: price,
        ),
      ),
    );
  }

  Future<void> _openShop() async {
    final String? sellerId =
        widget.item['item_seller_id']?.toString() ??
        widget.item['seller_id']?.toString();
    if (sellerId == null || sellerId.isEmpty) return;

    // If a ViewShop for this seller is already in the stack, pop back to it
    if (ViewShop.openShops.contains(sellerId)) {
      Navigator.of(context).popUntil(
        (route) => route.settings.name == 'ViewShop:$sellerId' || route.isFirst,
      );
      return;
    }

    Map<String, dynamic> sellerData =
        (widget.item['sellers'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(widget.item['sellers'])
        : <String, dynamic>{};

    try {
      if (sellerData.isEmpty || sellerData['seller_store_name'] == null) {
        final row = await _supabase
            .from('sellers')
            .select()
            .eq('seller_id', sellerId)
            .maybeSingle();
        if (row != null) sellerData = Map<String, dynamic>.from(row);
      }
    } catch (e) {
      debugPrint("Fetch seller error: $e");
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'ViewShop:$sellerId'),
        builder: (_) => ViewShop(sellerId: sellerId, sellerData: sellerData),
      ),
    );
  }

  Widget _buildMerchantCard(String merchant, String? merchantLogo) {
    ImageProvider? logoProvider;
    if (merchantLogo != null && merchantLogo.isNotEmpty) {
      if (merchantLogo.startsWith('http')) {
        logoProvider = NetworkImage(merchantLogo);
      } else {
        final bytes = Utility.decodeHexImage(merchantLogo);
        if (bytes != null) logoProvider = MemoryImage(bytes);
      }
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openShop,
            child: CircleAvatar(
              radius: 26,
              backgroundColor: cardBorder,
              backgroundImage: logoProvider,
              child: logoProvider == null
                  ? Icon(Icons.storefront_rounded, color: textSecondary)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: _openShop,
              child: Text(
                merchant,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _openShop,
            style: OutlinedButton.styleFrom(
              foregroundColor: themeOrange,
              side: BorderSide(color: themeOrange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              "View Shop",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(String description) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PRODUCT DESCRIPTION",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: primaryDark.withValues(alpha: 0.8),
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    if (images.isEmpty) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: textSecondary.withValues(alpha: 0.2),
        ),
      );
    }
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: Stack(
        children: [
          PageView.builder(
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _activeImage = i),
            itemCount: images.length,
            itemBuilder: (_, i) {
              final String src = images[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ImageViewer(imageUrls: images, initialIndex: i),
                  ),
                ),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 2.5,
                  child: Hero(tag: 'hero_$src', child: _buildImage(src)),
                ),
              );
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${_activeImage + 1} / ${images.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String src, {BoxFit fit = BoxFit.cover}) {
    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
        ),
      );
    }
    final bytes = Utility.decodeHexImage(src);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
    );
  }

  Widget _buildStatBadge(String label, IconData? icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsList() {
    if (_isLoadingRecs) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_recommendations.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          "No recommendations yet",
          style: TextStyle(
            color: textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final double w = MediaQuery.of(context).size.width;
    final int cols = w >= 1100
        ? 5
        : w >= 800
        ? 4
        : w >= 600
        ? 3
        : 2;

    return MasonryGrid(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      crossAxisCount: cols,
      spacing: 8,
      children: [
        for (final item in _recommendations)
          Builder(
            builder: (context) {
              final String img =
                  (item['item_images'] as List?)?.first?.toString() ?? "";
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  StoreItemDetails.open(context, item);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: cardBorder, width: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: img.isNotEmpty
                              ? _buildImage(img)
                              : Container(
                                  color: bgColor,
                                  child: const Center(
                                    child: Icon(Icons.image_outlined),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['item_name'] ?? 'Item',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "₱${Utility().formatPrice(_displayPriceFor(item))}",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: themeOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStickyBottomBar() {
    final bool isWide =
        Responsive.isDesktop(context) || Responsive.isTablet(context);

    final Widget chatBtn = Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 12.0 : 0),
      child: _buildBottomIcon(
        Icons.chat_bubble_outline_rounded,
        "Chat",
        _openChat,
      ),
    );

    final Widget divider = Container(width: 0.5, height: 30, color: cardBorder);

    final bool inCart = _cartRowId != null;
    final Widget addToCartBtn = InkWell(
      onTap: _isCartBusy ? null : (inCart ? _removeFromCart : _addToCart),
      child: Container(
        height: 56,
        color: inCart
            ? themeOrange.withValues(alpha: 0.15)
            : const Color(0xFFFFF2EE),
        alignment: Alignment.center,
        child: _isCartBusy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: themeOrange,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    inCart
                        ? Icons.remove_shopping_cart_rounded
                        : Icons.add_shopping_cart_rounded,
                    color: themeOrange,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    inCart ? "Remove from Cart" : "Add to Cart",
                    style: TextStyle(
                      color: themeOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );

    final Widget buyNowBtn = InkWell(
      onTap: _buyNow,
      child: Container(
        height: 56,
        color: themeOrange,
        alignment: Alignment.center,
        child: const Text(
          "Buy Now",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
    );

    final Widget bar = Row(
      mainAxisAlignment: isWide
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        chatBtn,
        divider,
        if (isWide) ...[
          // Increased width from 200 to 280 for a more balanced look on wider screens
          SizedBox(width: 280, child: addToCartBtn),
          SizedBox(width: 280, child: buyNowBtn),
        ] else ...[
          Expanded(child: addToCartBtn),
          Expanded(child: buyNowBtn),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: cardBorder, width: 0.5)),
        boxShadow: isWide
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ]
            : null,
      ),
      child: SafeArea(child: bar),
    );
  }

  Widget _buildBottomIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 65,
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: themeOrange),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
