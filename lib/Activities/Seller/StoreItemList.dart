import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Activities/Seller/SubActivities/AddEditStoreItem.dart';
import 'package:gasan_port_tracker/Dialogs/Bottomsheets/StoreItemDetailsBottomSheet.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';

import '../../Utility/Utility.dart';
import '../../Utility/ItemVariations.dart';
import '../../Utility/MasonryGrid.dart';

class StoreItemList extends StatefulWidget {
  final String sellerId;

  const StoreItemList({super.key, required this.sellerId});

  @override
  State<StoreItemList> createState() => _StoreItemListState();
}

class _StoreItemListState extends State<StoreItemList> {
  final _supabase = Supabase.instance.client;

  // --- THEME COLORS ---
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color primaryBlue = const Color(0xFF2563EB);
  final Color priceColor = const Color(0xFFEE4D2D);
  final Color bgColor = const Color(0xFFF5F5F5);
  final Color successColor = const Color(0xFF10B981);
  final Color dangerColor = const Color(0xFFEF4444);

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  // --- SEARCH & FILTER STATE ---
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filterOptions = [
    "All",
    "Food",
    "Service",
    "Material",
    "Apparel",
    "Electronics",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- DATABASE LOGIC ---

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      // Base Query
      var query = _supabase
          .from('store_items')
          .select()
          .eq('item_seller_id', widget.sellerId);

      // Apply Search Filter (Case-insensitive)
      if (_searchQuery.trim().isNotEmpty) {
        query = query.ilike('item_name', '%${_searchQuery.trim()}%');
      }

      // Apply Category Filter
      if (_selectedFilter != 'All') {
        query = query.eq('item_type', _selectedFilter.toLowerCase());
      }

      // Execute Query
      final data = await query.order('item_id', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);
      bool outOfStock(Map<String, dynamic> m) {
        final vars = m['item_variations'];
        if (vars is List && vars.isNotEmpty) {
          for (final v in vars) {
            if (v is Map &&
                (num.tryParse(v['stock']?.toString() ?? '0') ?? 0) > 0)
              return false;
          }
          return true;
        }
        final raw = m['item_stocks'];
        final s = raw is int
            ? raw
            : (int.tryParse(raw?.toString() ?? '0') ?? 0);
        return s <= 0;
      }

      list.sort((a, b) {
        final ao = outOfStock(a) ? 1 : 0;
        final bo = outOfStock(b) ? 1 : 0;
        if (ao != bo) return ao.compareTo(bo);
        return (b['item_id']?.toString() ?? '').compareTo(
          a['item_id']?.toString() ?? '',
        );
      });

      if (mounted) {
        setState(() {
          _items = list;
        });
      }
    } catch (e) {
      debugPrint("Error fetching items: $e");
      _showSnackBar("Failed to load items", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != value) {
        setState(() {
          _searchQuery = value;
        });
        _fetchItems();
      }
    });
  }

  void _onFilterSelected(String filter) {
    if (_selectedFilter != filter) {
      setState(() {
        _selectedFilter = filter;
      });
      _fetchItems();
    }
  }

  Future<void> _toggleAvailability(
    int index,
    String itemId,
    bool currentStatus,
  ) async {
    // Optimistic update
    setState(() => _items[index]['item_available'] = !currentStatus);

    try {
      await _supabase
          .from('store_items')
          .update({'item_available': !currentStatus})
          .eq('item_id', itemId);
    } catch (e) {
      // Revert on fail
      setState(() => _items[index]['item_available'] = currentStatus);
      _showSnackBar("Update failed", isError: true);
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await _supabase.from('store_items').delete().eq('item_id', itemId);
      _fetchItems();
      _showSnackBar("Item deleted successfully");
    } catch (e) {
      _showSnackBar("Delete failed", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? dangerColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _deleteItemConfirm(String itemId) {
    final dialog = ClassicDialog();
    dialog.setTitle("Delete Item?");
    dialog.setMessage(
      "Are you sure you want to remove this item? This action cannot be undone.",
    );
    dialog.setPositiveMessage("Delete");
    dialog.setNegativeMessage("Cancel");
    dialog.setCancelable(false);
    dialog.showTwoButtonDialog(
      context,
      (_) {
        dialog.dismissDialog();
      },
      (_) {
        dialog.dismissDialog();
        _deleteItem(itemId);
      },
    );
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: const Text(
          "My Products",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditStoreItem(sellerId: widget.sellerId),
                  ),
                );
                _fetchItems();
              },
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: primaryBlue,
                size: 20,
              ),
              label: Text(
                "Add New",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchItems,
              color: primaryBlue,
              backgroundColor: Colors.white,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryBlue))
                  : _items.isEmpty
                  ? _buildEmptyState()
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: _buildShopeeStyleGrid(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryDark,
              ),
              decoration: InputDecoration(
                hintText: "Search your products...",
                hintStyle: TextStyle(
                  color: textSecondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: textSecondary,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: bgColor,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryBlue, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isSelected ? Colors.white : textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => _onFilterSelected(filter),
                    backgroundColor: Colors.white,
                    selectedColor: primaryBlue,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? primaryBlue : cardBorder,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isFiltering =
        _searchQuery.isNotEmpty || _selectedFilter != 'All';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryDark.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        isFiltering
                            ? Icons.search_off_rounded
                            : Icons.add_business_rounded,
                        size: 72,
                        color: primaryBlue.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isFiltering ? "No results found" : "No products yet",
                      style: TextStyle(
                        color: primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFiltering
                          ? "Try adjusting your search or filters."
                          : "Add products to start selling to your customers.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShopeeStyleGrid() {
    final double width = MediaQuery.of(context).size.width;
    final int crossAxis = (width / 220).floor().clamp(2, 6);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.all(12),
      child: MasonryGrid(
        crossAxisCount: crossAxis,
        spacing: 8,
        children: [
          for (int i = 0; i < _items.length; i++)
            _buildProductCard(_items[i], i),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item, int index) {
    final List<String> images = StoreItemDetailsBottomSheet.parseImages(
      item['item_images'],
    );
    final String? firstImage = images.isNotEmpty ? images.first : null;

    final bool isAvailable = item['item_available'] ?? false;
    final variations = ItemVariations.parse(item['item_variations']);
    final num stock = variations.isNotEmpty
        ? ItemVariations.totalStock(item['item_variations'])
        : (item['item_stocks'] ?? 0);
    final bool noStockLimit = stock < 0;
    final String itemId = item['item_id'].toString();
    final String type = (item['item_type'] ?? 'OTHER').toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => StoreItemDetailsBottomSheet.show(
            context,
            item,
            onEdit: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditStoreItem(
                    sellerId: widget.sellerId,
                    existingItem: item,
                  ),
                ),
              );
              _fetchItems();
            },
            onDelete: () => _deleteItemConfirm(item['item_id'].toString()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. Product Image (1:1 Aspect Ratio) ---
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: bgColor,
                      child: firstImage != null
                          ? StoreItemDetailsBottomSheet.buildImage(firstImage)
                          : Icon(
                              Icons.image_outlined,
                              color: textSecondary.withValues(alpha: 0.3),
                              size: 40,
                            ),
                    ),

                    // Top Left Tag Overlay (Shopee Style)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Sold Out Overlay
                    if (!noStockLimit && stock <= 0)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "SOLD OUT",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // --- 2. Product Details ---
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item['item_name'] ?? 'Unnamed Product',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: primaryDark,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Price (range if variations)
                    Text(
                      variations.isNotEmpty
                          ? ItemVariations.priceLabel(
                              item['item_variations'],
                              num.tryParse(
                                    item['item_price']?.toString() ?? '0',
                                  ) ??
                                  0,
                              (v) => Utility().formatPrice(v),
                            )
                          : "₱${Utility().formatPrice(item['item_price'])}",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: priceColor,
                      ),
                    ),

                    // Variants
                    if (variations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "${variations.length} variants",
                          style: TextStyle(
                            fontSize: 10,
                            color: primaryBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Bottom Action Row (Stock & Controls)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Stock Indicator
                        if (!noStockLimit)
                          Text(
                            "Stock: $stock",
                            style: TextStyle(
                              fontSize: 10,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                        SizedBox(
                          height: 20,
                          width: 34,
                          child: Transform.scale(
                            scale: 0.65,
                            alignment: Alignment.centerRight,
                            child: Switch(
                              value: isAvailable,
                              activeColor: successColor,
                              inactiveThumbColor: textSecondary,
                              inactiveTrackColor: cardBorder,
                              trackOutlineColor: WidgetStateProperty.all(
                                Colors.transparent,
                              ),
                              onChanged: (val) => _toggleAvailability(
                                index,
                                itemId,
                                isAvailable,
                              ),
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
}
