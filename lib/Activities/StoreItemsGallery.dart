import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/MarketCategories.dart';
import 'package:gasan_port_tracker/Utility/ItemPreferenceTracker.dart';
import 'Seller/StoreItemDetails.dart';
import 'ViewShop.dart';
import 'MyCart.dart';
import 'UserOrders.dart';
import 'package:gasan_port_tracker/Utility/ChatService.dart';
import 'package:gasan_port_tracker/Activities/Chat/ChatInbox.dart';

class StoreItemsGallery extends StatefulWidget {
  final bool isTab;
  const StoreItemsGallery({super.key, this.isTab = false});

  @override
  State<StoreItemsGallery> createState() => _StoreItemsGalleryState();
}

class _StoreItemsGalleryState extends State<StoreItemsGallery> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _searchFocus = FocusNode();

  final Color bgColor = const Color(0xFFF1F5F9);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color themeOrange = const Color(0xFFEE4D2D);
  final Color themeOrangeDark = const Color(0xFFD23F1F);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color textSecondary = const Color(0xFF64748B);
  final Color accentEmerald = const Color(0xFF10B981);

  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _shops = [];
  int _cartCount = 0;
  int _msgCount = 0;
  String _query = '';
  static const int _pageSize = 12;
  int _visibleCount = _pageSize;
  String _activeCategory = 'All';
  int _municipalZipCode = 0;

  static final List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'icon': Icons.apps_rounded},
    ...MarketCategories.categories,
  ];

  RealtimeChannel? _msgChannel;

  @override
  void initState() {
    super.initState();
    _init();
    _searchFocus.addListener(() => setState(() {}));
    _scrollCtrl.addListener(_onScroll);
    final uid = _supabase.auth.currentUser?.id;
    _msgChannel = ChatService().subscribeAllMessages((row) {
      if (row['message_sender_id']?.toString() != uid) _fetchMsgCount();
    });
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _municipalZipCode = prefs.getInt('current_zip_code') ?? 0;
    await _fetchItems();
    _fetchShops();
    _fetchCartCount();
    _fetchMsgCount();
  }

  Future<void> _fetchMsgCount() async {
    try {
      final count = await ChatService().buyerUnreadTotal();
      if (mounted) setState(() => _msgCount = count);
    } catch (e) {
      debugPrint("Msg count error: $e");
    }
  }

  Future<void> _fetchShops() async {
    try {
      final data = await _supabase
          .from('sellers')
          .select('seller_id, seller_store_name, seller_logo, seller_store_address')
          .limit(40);
      final shops = List<Map<String, dynamic>>.from(data)..shuffle();
      if (mounted) setState(() => _shops = shops.take(10).toList());
    } catch (e) {
      debugPrint("Error fetching shops: $e");
    }
  }

  @override
  void dispose() {
    if (_msgChannel != null) _supabase.removeChannel(_msgChannel!);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _isItemOutOfStock(Map<String, dynamic> item) {
    final vars = item['item_variations'];
    if (vars is List && vars.isNotEmpty) {
      for (final v in vars) {
        if (v is Map) {
          final s = num.tryParse(v['stock']?.toString() ?? '0') ?? 0;
          if (s > 0) return false;
        }
      }
      return true;
    }
    final raw = item['item_stocks'];
    if (raw == null) return false;
    final s = raw is int ? raw : int.tryParse(raw.toString());
    return s != null && s <= 0;
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      debugPrint("Gallery filter zip=$_municipalZipCode category=$_activeCategory query=$_query");
      var query = _supabase
          .from('store_items')
          .select('*, sellers(seller_store_name, seller_logo, seller_store_address)')
          .eq('item_available', true);
      if (_activeCategory != 'All') {
        query = query.ilike('item_category', _activeCategory);
      }
      final data = await query;
      var items = List<Map<String, dynamic>>.from(data);
      items = items.where((item) => !_isItemOutOfStock(item)).toList();
      if (_municipalZipCode != 0) {
        items = items.where((item) {
          final origin = num.tryParse('${item['item_municipality_origin'] ?? ''}');
          if (origin != null && origin == _municipalZipCode) return true;
          final addr = item['sellers']?['seller_store_address'];
          if (addr is Map) {
            final sellerZip = num.tryParse('${addr['zip_code'] ?? ''}');
            if (sellerZip != null && sellerZip == _municipalZipCode) return true;
          }
          return false;
        }).toList();
      }
      debugPrint("Gallery fetched ${items.length} items for zip=$_municipalZipCode");
      final weights = await ItemPreferenceTracker.typeWeights();
      items = ItemPreferenceTracker.personalize(items, weights);
      if (mounted) {
        setState(() {
          _items = items;
          _visibleCount = _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching items: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _runSearch() {
    _searchFocus.unfocus();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      if (_visibleCount < _filtered.length) {
        setState(() => _visibleCount = (_visibleCount + _pageSize).clamp(0, _filtered.length));
      }
    }
  }

  Future<void> _fetchCartCount() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      final data = await _supabase.from('cart').select('cart_id').eq('cart_user_id', uid);
      if (mounted) setState(() => _cartCount = (data as List).length);
    } catch (e) {
      debugPrint("Cart count error: $e");
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((item) {
      final name = (item['item_name'] ?? '').toString().toLowerCase();
      final cat = (item['item_category'] ?? '').toString().toLowerCase();
      final shop = (item['sellers']?['seller_store_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || cat.contains(q) || shop.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleItems {
    final f = _filtered;
    return f.length <= _visibleCount ? f : f.sublist(0, _visibleCount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: LayoutBuilder(builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final int crossAxis = w >= 1600
            ? 6
            : w >= 1200
                ? 5
                : w >= 900
                    ? 4
                    : w >= 600
                        ? 3
                        : 2;
        final bool isDesktop = w >= 1100;
        final bool isTablet = w >= 700 && w < 1100;
        final double maxContent = isDesktop ? 1400 : (isTablet ? 1000 : double.infinity);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContent),
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetchItems();
                await _fetchCartCount();
              },
              color: themeOrange,
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _buildHeader(isDesktop, isTablet),
                  SliverToBoxAdapter(child: _buildPromoBanner(isDesktop || isTablet)),
                  SliverToBoxAdapter(child: _buildCategoryStrip()),
                  SliverToBoxAdapter(child: _buildShopsStrip()),
                  SliverToBoxAdapter(child: _buildSectionHeader()),
                  _isLoading
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()))
                      : _filtered.isEmpty
                          ? SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
                          : _buildGrid(crossAxis),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeader(bool isDesktop, bool isTablet) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: themeOrange,
      foregroundColor: Colors.white,
      toolbarHeight: 60,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [themeOrange, themeOrangeDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : (isTablet ? 16 : 8)),
        child: Row(
          children: [
            if (!widget.isTab) ...[
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.maybePop(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(child: _buildSearchField()),
            const SizedBox(width: 4),
            if (_searchFocus.hasFocus || _query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ElevatedButton(
                  onPressed: _runSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: themeOrange,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Search", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                ),
              ),
            _buildOrdersIcon(),
            _buildMessagesIcon(),
            _buildCartIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: (v) => setState(() {
          _query = v;
          _visibleCount = _pageSize;
        }),
        onSubmitted: (_) => _runSearch(),
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(color: primaryDark, fontSize: 13.5, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          hintText: "Search items, stores...",
          hintStyle: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Icon(Icons.search_rounded, color: themeOrange, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: _query.isEmpty
              ? null
              : InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _searchCtrl.clear();
                    _searchFocus.unfocus();
                    setState(() {
                      _query = '';
                      _visibleCount = _pageSize;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildOrdersIcon() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserOrders())),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.receipt_long_outlined, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildMessagesIcon() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatInbox()));
        _fetchMsgCount();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24),
            if (_msgCount > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeOrange, width: 1.5),
                  ),
                  child: Text(
                    _msgCount > 99 ? '99+' : '$_msgCount',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: themeOrange, fontSize: 9.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartIcon() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCart()));
        _fetchCartCount();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 24),
            if (_cartCount > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeOrange, width: 1.5),
                  ),
                  child: Text(
                    _cartCount > 99 ? '99+' : '$_cartCount',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: themeOrange, fontSize: 9.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanner(bool isWide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 24 : 14, 12, isWide ? 24 : 14, 4),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFFFE0B2), const Color(0xFFFFCCBC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: themeOrange.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10, bottom: -10,
              child: Icon(Icons.local_offer_rounded, size: 110, color: themeOrange.withValues(alpha: 0.15)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: themeOrange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text("MARKETPLACE",
                      style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                  ),
                  const SizedBox(height: 8),
                  Text("Shop Local. Support Marinduque.",
                    style: TextStyle(color: primaryDark, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                  const SizedBox(height: 2),
                  Text("Hand-picked items from trusted local sellers.",
                    style: TextStyle(color: primaryDark.withValues(alpha: 0.65), fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.white,
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (_, i) {
            final c = _categories[i];
            final label = c['label'] as String;
            final active = label == _activeCategory;
            return GestureDetector(
              onTap: () {
                setState(() => _activeCategory = label);
                _fetchItems();
              },
              child: SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: active ? themeOrange : themeOrange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: active
                            ? [BoxShadow(color: themeOrange.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                            : null,
                      ),
                      child: Icon(c['icon'] as IconData, color: active ? Colors.white : themeOrange, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? themeOrange : primaryDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ImageProvider? _shopLogo(Map<String, dynamic> shop) {
    final logo = shop['seller_logo']?.toString();
    if (logo == null || logo.isEmpty) return null;
    if (logo.startsWith('http')) return NetworkImage(logo);
    final bytes = Utility.decodeHexImage(logo);
    return bytes != null ? MemoryImage(bytes) : null;
  }

  Widget _buildShopsStrip() {
    if (_shops.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text("Discover Shops",
                style: TextStyle(color: primaryDark, fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _shops.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final shop = _shops[i];
                final name = (shop['seller_store_name'] ?? 'Shop').toString();
                final logo = _shopLogo(shop);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: RouteSettings(name: 'ViewShop:${shop['seller_id']}'),
                      builder: (_) => ViewShop(sellerId: shop['seller_id'].toString(), sellerData: shop),
                    ),
                  ),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: themeOrange.withValues(alpha: 0.4), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: themeOrange.withValues(alpha: 0.1),
                            backgroundImage: logo,
                            child: logo == null
                                ? Icon(Icons.storefront_rounded, color: themeOrange, size: 26)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: primaryDark, fontSize: 10, fontWeight: FontWeight.w700, height: 1.15)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: themeOrange, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text("Trending Now",
            style: TextStyle(color: primaryDark, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const Spacer(),
          Icon(Icons.local_fire_department_rounded, color: themeOrange, size: 18),
          const SizedBox(width: 4),
          Text("${_filtered.length} items",
            style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(int crossAxis) {
    final items = _visibleItems;
    final bool hasMore = _visibleCount < _filtered.length;
    final columns = List.generate(crossAxis, (_) => <Widget>[]);
    for (int i = 0; i < items.length; i++) {
      columns[i % crossAxis].add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildItemCard(items[i]),
      ));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int c = 0; c < crossAxis; c++) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: columns[c],
                    ),
                  ),
                  if (c < crossAxis - 1) const SizedBox(width: 8),
                ],
              ],
            ),
            if (hasMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final String name = (item['item_name'] ?? 'Item').toString();
    final dynamic rawPrice = item['item_price'];
    final num price = rawPrice is num ? rawPrice : (num.tryParse(rawPrice?.toString() ?? '0') ?? 0);
    final dynamic rawImgs = item['item_images'];
    final List imgs = rawImgs is List ? rawImgs : (rawImgs is String && rawImgs.isNotEmpty ? [rawImgs] : []);
    final String img = imgs.isNotEmpty ? imgs.first.toString() : "";
    final Map<String, dynamic> sellerMap = item['sellers'] is Map<String, dynamic> ? item['sellers'] as Map<String, dynamic> : <String, dynamic>{};
    final String merchant = (sellerMap['seller_store_name'] ?? 'Local Merchant').toString();
    final int stocks = item['item_stocks'] is int ? item['item_stocks'] : (int.tryParse(item['item_stocks']?.toString() ?? '0') ?? 0);
    final String category = (item['item_category'] ?? '').toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          ItemPreferenceTracker.recordView(item['item_type']);
          StoreItemDetails.open(context, item);
          _fetchCartCount();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cardBorder, width: 0.7),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      child: img.isNotEmpty
                          ? Image.network(img, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: bgColor, child: Icon(Icons.broken_image_rounded, color: textSecondary.withValues(alpha: 0.4))),
                            )
                          : Container(color: bgColor, child: const Icon(Icons.shopping_bag_outlined, size: 40)),
                    ),
                    if (category.isNotEmpty)
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(category.toUpperCase(),
                            style: TextStyle(color: primaryDark, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                        ),
                      ),
                    if (stocks == 0)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.75),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryDark,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text("OUT OF STOCK",
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: primaryDark, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 10, color: textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(merchant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("₱", style: TextStyle(color: themeOrange, fontSize: 11, fontWeight: FontWeight.w800)),
                        Flexible(
                          child: Text(Utility().formatPrice(price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: themeOrange, fontSize: 16, fontWeight: FontWeight.w900, height: 1),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (stocks > 0 && stocks <= 5)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: accentEmerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text("$stocks left",
                              style: TextStyle(color: accentEmerald, fontSize: 9, fontWeight: FontWeight.w900),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: themeOrange.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 5)],
            ),
            child: Icon(Icons.storefront_outlined, size: 56, color: themeOrange.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 20),
          Text(
            _query.isEmpty && _activeCategory == 'All' ? "No items yet" : "No items match your filter",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          Text(
            "Try a different keyword or category.",
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
