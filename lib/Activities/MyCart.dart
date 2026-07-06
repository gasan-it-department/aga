import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import '../Dialogs/LoadingDialog.dart';
import '../FloatingMessages/SnackbarMessenger.dart';
import 'Seller/Checkout.dart';
import 'Seller/MultiShopCheckout.dart';
import 'Seller/StoreItemDetails.dart';

class MyCart extends StatefulWidget {
  const MyCart({super.key});

  @override
  State<MyCart> createState() => _MyCartState();
}

class _MyCartState extends State<MyCart> {
  final _supabase = Supabase.instance.client;
  final _loadingDialog = LoadingDialog();

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color govBlue = const Color(0xFF1565C0);
  final Color themeOrange = const Color(0xFFEE4D2D);
  final Color accentEmerald = const Color(0xFF10B981);
  final Color rosePink = const Color(0xFFEF4444);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);

  bool _isLoading = true;
  List<Map<String, dynamic>> _cartItems = [];
  final Set<String> _selectedCartIds = {};

  @override
  void initState() {
    super.initState();
    _fetchCartItems();
  }

  Future<void> _fetchCartItems() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted)
          setState(() {
            _cartItems = [];
            _isLoading = false;
          });
        return;
      }

      final cartRows = await _supabase
          .from('cart')
          .select()
          .eq('cart_user_id', user.id)
          .order('cart_date_added', ascending: false);

      final cartList = List<Map<String, dynamic>>.from(cartRows);
      final itemIds = cartList
          .map((e) => e['cart_item_id']?.toString())
          .whereType<String>()
          .toList();

      Map<String, Map<String, dynamic>> itemMap = {};
      if (itemIds.isNotEmpty) {
        final items = await _supabase
            .from('store_items')
            .select(
              '*, sellers!inner(seller_store_name, seller_logo, seller_store_status)',
            )
            .eq('sellers.seller_store_status', 'visible')
            .inFilter('item_id', itemIds);
        for (final row in List<Map<String, dynamic>>.from(items)) {
          itemMap[row['item_id'].toString()] = row;
        }
      }

      final merged = <Map<String, dynamic>>[];
      for (final row in cartList) {
        final id = row['cart_item_id']?.toString();
        if (id != null && itemMap.containsKey(id)) {
          merged.add({...row, 'store_items': itemMap[id]});
        } else {
          merged.add({...row, 'store_items': null});
        }
      }

      if (mounted) {
        setState(() {
          _cartItems = merged;
          _selectedCartIds.removeWhere(
            (id) => !merged.any((row) => row['cart_id']?.toString() == id),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching cart: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.failed,
          "Failed to load cart.",
        );
      }
    }
  }

  Future<void> _removeCartItem(String cartId) async {
    _loadingDialog.showLoadingDialog(context);
    try {
      await _supabase.from('cart').delete().eq('cart_id', cartId);
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.success,
          "Removed from cart.",
        );
        setState(
          () =>
              _cartItems.removeWhere((e) => e['cart_id']?.toString() == cartId),
        );
      }
    } catch (e) {
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.failed,
          "Failed to remove item.",
        );
      }
    }
  }

  void _navigateToItem(Map<String, dynamic> storeItem) {
    StoreItemDetails.open(context, storeItem);
    _fetchCartItems();
  }

  List<Map<String, dynamic>> get _selectedItems => _cartItems
      .where(
        (row) =>
            _selectedCartIds.contains(row['cart_id']?.toString()) &&
            row['store_items'] is Map<String, dynamic>,
      )
      .toList();

  num _lineTotal(Map<String, dynamic> row) {
    final item = row['store_items'] as Map<String, dynamic>;
    final variation = row['cart_variation'] is Map
        ? Map<String, dynamic>.from(row['cart_variation'])
        : null;
    final price =
        num.tryParse(
          (variation?['price'] ?? item['item_price'] ?? 0).toString(),
        ) ??
        0;
    final quantity = num.tryParse(row['cart_quantity']?.toString() ?? '1') ?? 1;
    return price * quantity;
  }

  void _checkoutSelected() {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    final subtotal = selected.fold<num>(
      0,
      (total, row) => total + _lineTotal(row),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => shopCount(selected) > 1
            ? MultiShopCheckout(selectedItems: selected)
            : Checkout(selectedItems: selected, totalAmount: subtotal),
      ),
    ).then((_) => _fetchCartItems());
  }

  int shopCount(List<Map<String, dynamic>> items) => items
      .map(
        (row) => (row['store_items'] as Map<String, dynamic>)['item_seller_id']
            ?.toString(),
      )
      .whereType<String>()
      .toSet()
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        centerTitle: false,
        title: const Text(
          "My Cart",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: themeOrange,
                strokeWidth: 3,
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchCartItems,
              color: themeOrange,
              backgroundColor: Colors.white,
              child: _cartItems.isEmpty
                  ? _buildEmptyState()
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: Responsive.isDesktop(context) ? 1280 : 920,
                        ),
                        child: _buildGrid(),
                      ),
                    ),
            ),
      bottomNavigationBar: _cartItems.isEmpty || _isLoading
          ? null
          : _buildCheckoutBar(),
    );
  }

  Widget _buildCheckoutBar() {
    final selectable = _cartItems
        .where((row) => row['store_items'] is Map<String, dynamic>)
        .toList();
    final allSelected =
        selectable.isNotEmpty &&
        selectable.every(
          (row) => _selectedCartIds.contains(row['cart_id']?.toString()),
        );
    final selected = _selectedItems;
    final subtotal = selected.fold<num>(
      0,
      (total, row) => total + _lineTotal(row),
    );
    final shopCount = selected
        .map(
          (row) =>
              (row['store_items'] as Map<String, dynamic>)['item_seller_id']
                  ?.toString(),
        )
        .whereType<String>()
        .toSet()
        .length;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: cardBorder)),
        ),
        child: Row(
          children: [
            Checkbox(
              value: allSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedCartIds.addAll(
                      selectable.map((row) => row['cart_id'].toString()),
                    );
                  } else {
                    _selectedCartIds.clear();
                  }
                });
              },
            ),
            const Text('All', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₱${Utility().formatPrice(subtotal)}",
                    style: TextStyle(
                      color: themeOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    '${selected.length} item(s) · $shopCount shop(s)',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: themeOrange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              onPressed: selected.isEmpty ? null : _checkoutSelected,
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text(
                'Checkout',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    int crossAxis;
    double extent;
    EdgeInsets pad;
    if (Responsive.isDesktop(context)) {
      crossAxis = 4;
      extent = 320;
      pad = const EdgeInsets.fromLTRB(24, 20, 24, 28);
    } else if (Responsive.isTablet(context)) {
      crossAxis = 3;
      extent = 310;
      pad = const EdgeInsets.fromLTRB(18, 18, 18, 24);
    } else {
      crossAxis = 2;
      extent = 300;
      pad = const EdgeInsets.fromLTRB(14, 14, 14, 24);
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: pad,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxis,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: extent,
      ),
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final row = _cartItems[index];
        final s = row['store_items'];
        if (s is! Map<String, dynamic>) {
          return _buildMissingCard(row['cart_id']?.toString() ?? '');
        }
        return _buildCartCard(row, s);
      },
    );
  }

  Widget _buildCartCard(
    Map<String, dynamic> cartRow,
    Map<String, dynamic> item,
  ) {
    final String cartId = cartRow['cart_id']?.toString() ?? '';
    final selected = _selectedCartIds.contains(cartId);
    final String name = (item['item_name'] ?? 'Item').toString();
    final variation = cartRow['cart_variation'] is Map
        ? Map<String, dynamic>.from(cartRow['cart_variation'])
        : null;
    final dynamic rawPrice = variation?['price'] ?? item['item_price'];
    final num price = rawPrice is num
        ? rawPrice
        : (num.tryParse(rawPrice?.toString() ?? '0') ?? 0);
    final dynamic rawImgs = item['item_images'];
    final List imgs = rawImgs is List
        ? rawImgs
        : (rawImgs is String && rawImgs.isNotEmpty ? [rawImgs] : []);
    final String img = imgs.isNotEmpty ? imgs.first.toString() : "";
    final int imageCount = imgs.length;
    final bool isAvailable = item['item_available'] == true;
    final int stocks = item['item_stocks'] is int
        ? item['item_stocks']
        : (int.tryParse(item['item_stocks']?.toString() ?? '0') ?? 0);

    final sellers = item['sellers'];
    final Map<String, dynamic> sellerMap = sellers is Map<String, dynamic>
        ? sellers
        : <String, dynamic>{};
    final String store = (sellerMap['seller_store_name'] ?? 'Local Store')
        .toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToItem(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      img.isNotEmpty
                          ? Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: bgColor,
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: textSecondary.withValues(alpha: 0.4),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    themeOrange.withValues(alpha: 0.8),
                                    govBlue.withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.shopping_bag_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: Checkbox(
                            value: selected,
                            visualDensity: VisualDensity.compact,
                            onChanged: (value) => setState(() {
                              if (value == true) {
                                _selectedCartIds.add(cartId);
                              } else {
                                _selectedCartIds.remove(cartId);
                              }
                            }),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isAvailable && stocks != 0
                                        ? accentEmerald
                                        : rosePink)
                                    .withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isAvailable && stocks != 0
                                ? "IN STOCK"
                                : "UNAVAILABLE",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _removeCartItem(cartId),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Icon(
                                Icons.delete_rounded,
                                color: rosePink,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (imageCount > 1)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.white,
                                  size: 10,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "$imageCount",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (variation != null) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: govBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              "Variant: ${variation['label']}",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: govBlue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 11,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                store,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: themeOrange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeOrange.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "₱${Utility().formatPrice(price)}",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: themeOrange,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: themeOrange,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingCard(String cartId) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: rosePink.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.remove_shopping_cart_rounded,
                color: rosePink.withValues(alpha: 0.7),
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Unavailable",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "This item was removed by the seller.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: rosePink,
                backgroundColor: rosePink.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: cartId.isEmpty ? null : () => _removeCartItem(cartId),
              icon: const Icon(Icons.delete_outline_rounded, size: 14),
              label: const Text(
                "Remove",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: themeOrange.withValues(alpha: 0.08),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: 56,
                    color: themeOrange.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Your Cart is Empty",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Items you add to your cart will\nappear right here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
