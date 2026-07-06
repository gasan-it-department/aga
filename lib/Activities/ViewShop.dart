import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gasan_port_tracker/Utility/MarketCategories.dart';
import 'package:gasan_port_tracker/Utility/MasonryGrid.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Activities/Seller/StoreItemDetails.dart';
import 'package:gasan_port_tracker/Utility/ChatService.dart';
import 'package:gasan_port_tracker/Activities/Chat/ChatThread.dart';

class ViewShop extends StatefulWidget {
  final String sellerId;
  final Map<String, dynamic> sellerData;

  static final Set<String> openShops = <String>{};

  const ViewShop({super.key, required this.sellerId, required this.sellerData});

  @override
  State<ViewShop> createState() => _ViewShopState();
}

class _ViewShopState extends State<ViewShop> {
  final _supabase = Supabase.instance.client;

  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color primaryBlue = const Color(0xFF2563EB);
  final Color accentBlue = const Color(0xFF1E40AF);
  final Color priceColor = const Color(0xFFEE4D2D);
  final Color bgColor = const Color(0xFFF8FAFC);

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isShopVisible = false;
  bool _visitCheckStarted = false;
  bool _sellerLastActiveUpdated = false;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  Map<String, dynamic> _seller = {};

  @override
  void initState() {
    super.initState();
    ViewShop.openShops.add(widget.sellerId);
    _seller = Map<String, dynamic>.from(widget.sellerData);
    _refreshSeller().then((_) => _fetchItems());
  }

  @override
  void dispose() {
    ViewShop.openShops.remove(widget.sellerId);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _refreshSeller() async {
    try {
      final row = await _supabase
          .from('sellers')
          .select()
          .eq('seller_id', widget.sellerId)
          .maybeSingle();
      if (row != null && mounted) {
        final seller = Map<String, dynamic>.from(row);
        final currentUserId = _supabase.auth.currentUser?.id;
        final isOwnStore =
            currentUserId != null &&
            seller['seller_user_id']?.toString() == currentUserId;
        setState(() {
          _seller = seller;
          _isShopVisible = row['seller_store_status']?.toString() == 'visible';
        });
        if (isOwnStore) {
          _updateSellerLastActive();
        } else if (_isShopVisible) {
          _recordShopVisit();
        }
      }
    } catch (e) {
      debugPrint("Seller fetch error: $e");
    }
  }

  Future<void> _updateSellerLastActive() async {
    if (_sellerLastActiveUpdated || widget.sellerId.isEmpty) return;
    _sellerLastActiveUpdated = true;
    try {
      await _supabase
          .from('sellers')
          .update({'seller_last_active': Utility().getCurrentMSEpochTime()})
          .eq('seller_id', widget.sellerId);
    } catch (e) {
      debugPrint('Seller last active update failed: $e');
    }
  }

  Future<void> _recordShopVisit() async {
    if (_visitCheckStarted) return;
    _visitCheckStarted = true;

    final visitorId = _supabase.auth.currentUser?.id;
    if (visitorId == null || visitorId.isEmpty || widget.sellerId.isEmpty) {
      return;
    }

    try {
      final latestVisit = await _supabase
          .from('shop_visitor')
          .select('visitor_visit_date')
          .eq('visitor_id', visitorId)
          .eq('visitor_store_id', widget.sellerId)
          .order('visitor_visit_date', ascending: false)
          .limit(1)
          .maybeSingle();

      final now = Utility().getCurrentMSEpochTime();
      final latestVisitDate = num.tryParse(
        latestVisit?['visitor_visit_date']?.toString() ?? '',
      );
      const cooldownMilliseconds = 10 * 60 * 1000;

      if (latestVisitDate != null &&
          now - latestVisitDate.toInt() < cooldownMilliseconds) {
        return;
      }

      await _supabase.from('shop_visitor').insert({
        'visit_id': 'VISIT_${Utility().generateUniqueID()}',
        'visitor_id': visitorId,
        'visitor_store_id': widget.sellerId,
        'visitor_visit_date': now,
      });
    } catch (e) {
      debugPrint('Shop visit tracking failed: $e');
    }
  }

  bool _isItemOutOfStock(Map<String, dynamic> item) {
    final vars = item['item_variations'];
    if (vars is List && vars.isNotEmpty) {
      for (final v in vars) {
        if (v is Map) {
          final stock = num.tryParse(v['stock']?.toString() ?? '0') ?? 0;
          if (stock < 0 || stock > 0) return false;
        }
      }
      return true;
    }
    final raw = item['item_stocks'];
    if (raw == null) return false;
    final stock = raw is num ? raw : num.tryParse(raw.toString());
    return stock != null && stock == 0;
  }

  List<Map<String, dynamic>> _sellableVariations(Map<String, dynamic> item) {
    final vars = item['item_variations'];
    if (vars is! List) return const [];
    return vars.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).where(
      (variation) {
        final stock = num.tryParse(variation['stock']?.toString() ?? '0') ?? 0;
        final price = num.tryParse(variation['price']?.toString() ?? '');
        return (stock < 0 || stock > 0) && price != null;
      },
    ).toList();
  }

  num _displayPrice(Map<String, dynamic> item) {
    final variations = _sellableVariations(item);
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

  num _effectiveStock(Map<String, dynamic> item) {
    final variations = _sellableVariations(item);
    if (variations.isNotEmpty) {
      if (variations.any((variation) {
        final stock = num.tryParse(variation['stock']?.toString() ?? '0') ?? 0;
        return stock < 0;
      })) {
        return -1;
      }
      return variations.fold<num>(0, (sum, variation) {
        final stock = num.tryParse(variation['stock']?.toString() ?? '0') ?? 0;
        return sum + stock;
      });
    }

    final raw = item['item_stocks'];
    return raw is num ? raw : (num.tryParse(raw?.toString() ?? '0') ?? 0);
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    if (!_isShopVisible) {
      if (mounted) {
        setState(() {
          _items = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      var query = _supabase
          .from('store_items')
          .select(
            '*, sellers!inner(seller_store_name, seller_logo, seller_store_status)',
          )
          .eq('item_seller_id', widget.sellerId)
          .eq('item_available', true)
          .eq('sellers.seller_store_status', 'visible');

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().replaceAll(',', ' ');
        query = query.or('item_name.ilike.%$q%,item_category.ilike.%$q%');
      }

      if (_selectedFilter != 'All') {
        query = query.or(
          'item_category.ilike.%$_selectedFilter%,item_type.ilike.%$_selectedFilter%',
        );
      }

      debugPrint(
        "ViewShop fetch seller=${widget.sellerId} filter=$_selectedFilter q=$_searchQuery",
      );
      final data = await query.order('item_name', ascending: true);
      debugPrint("ViewShop fetched ${data.length} items");
      final list = List<Map<String, dynamic>>.from(data);
      list.sort((a, b) {
        final ao = _isItemOutOfStock(a) ? 1 : 0;
        final bo = _isItemOutOfStock(b) ? 1 : 0;
        if (ao != bo) return ao.compareTo(bo);
        return (a['item_name']?.toString() ?? '').toLowerCase().compareTo(
          (b['item_name']?.toString() ?? '').toLowerCase(),
        );
      });
      if (mounted) {
        setState(() => _items = list);
      }
    } catch (e) {
      debugPrint("Error fetching items: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_searchQuery != value) {
        setState(() => _searchQuery = value);
        _fetchItems();
      }
    });
  }

  ImageProvider? _logoProvider() {
    final logo = _seller['seller_logo']?.toString();
    if (logo == null || logo.isEmpty) return null;
    if (logo.startsWith('http')) return NetworkImage(logo);
    final bytes = Utility.decodeHexImage(logo);
    if (bytes != null) return MemoryImage(bytes);
    return null;
  }

  ImageProvider? _coverProvider() {
    final cover = _seller['seller_cover_image']?.toString();
    if (cover == null || cover.isEmpty) return null;
    if (cover.startsWith('http')) return NetworkImage(cover);
    final bytes = Utility.decodeHexImage(cover);
    if (bytes != null) return MemoryImage(bytes);
    return null;
  }

  String _addressLine() {
    final addr = _seller['seller_store_address'];
    if (addr is Map) {
      final mun = addr['municipality']?.toString();
      final prov = addr['province']?.toString();
      final zip = addr['zip_code']?.toString();
      final parts = [
        mun,
        prov,
      ].where((s) => s != null && s.isNotEmpty).join(", ");
      return zip != null && zip.isNotEmpty ? "$parts • $zip" : parts;
    }
    if (addr is String && addr.isNotEmpty) {
      try {
        final decoded = jsonDecode(addr);
        if (decoded is Map) {
          return [
            decoded['municipality'],
            decoded['province'],
          ].where((s) => s != null && s.toString().isNotEmpty).join(", ");
        }
      } catch (_) {}
      return addr;
    }
    return "";
  }

  String? _lastActiveLabel() {
    final raw = _seller['seller_last_active'];
    final value = raw is num ? raw : num.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) return null;

    var milliseconds = value.toInt();
    if (milliseconds < 1000000000000) {
      milliseconds *= 1000;
    }

    final activeAt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final elapsed = DateTime.now().difference(activeAt);
    if (elapsed.isNegative) return 'Active just now';

    if (elapsed.inSeconds < 60) {
      final seconds = elapsed.inSeconds <= 0 ? 1 : elapsed.inSeconds;
      return 'Active ${seconds}s ago';
    }
    if (elapsed.inMinutes < 60) {
      return 'Active ${elapsed.inMinutes}min ago';
    }
    if (elapsed.inHours < 24) {
      return 'Active ${elapsed.inHours}h ago';
    }
    if (elapsed.inDays < 30) {
      return 'Active ${elapsed.inDays} day${elapsed.inDays == 1 ? '' : 's'} ago';
    }
    if (elapsed.inDays < 365) {
      final months = (elapsed.inDays / 30).floor().clamp(1, 11);
      return 'Active $months month${months == 1 ? '' : 's'} ago';
    }
    final years = (elapsed.inDays / 365).floor();
    return 'Active $years year${years == 1 ? '' : 's'} ago';
  }

  Map<String, Map<String, dynamic>> _operatingHours() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final raw = _seller['seller_operating_hours'];
    Map source = {};
    if (raw is Map) {
      source = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) source = decoded;
      } catch (_) {}
    }
    return {
      for (final day in days)
        if (source[day] is Map) day: Map<String, dynamic>.from(source[day]),
    };
  }

  String _todayName() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[DateTime.now().weekday - 1];
  }

  int? _minutesOf(String? value) {
    if (value == null || !value.contains(':')) return null;
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  bool _isOpenNow(Map<String, dynamic> today) {
    if (today['closed'] == true) return false;
    final open = _minutesOf(today['open']?.toString());
    final close = _minutesOf(today['close']?.toString());
    if (open == null || close == null) return false;
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    if (close < open) {
      return current >= open || current <= close;
    }
    return current >= open && current <= close;
  }

  String _format12Hour(String? value) {
    if (value == null || !value.contains(':')) return '--';
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return '--';
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _hoursSummary(Map<String, Map<String, dynamic>> hours) {
    if (hours.isEmpty) return '';
    final today = hours[_todayName()];
    if (today == null) return 'Closed now';
    if (today['closed'] == true) return 'Closed now';
    return _isOpenNow(today) ? 'Open now' : 'Closed now';
  }

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Launch error: $e");
    }
  }

  Future<void> _openDirections() async {
    final coords = _seller['seller_store_coordinates'];
    String destination = _addressLine();
    if (coords is Map &&
        coords['latitude'] != null &&
        coords['longitude'] != null) {
      destination = '${coords['latitude']},${coords['longitude']}';
    } else if (coords is String && coords.isNotEmpty) {
      try {
        final decoded = jsonDecode(coords);
        if (decoded is Map &&
            decoded['latitude'] != null &&
            decoded['longitude'] != null) {
          destination = '${decoded['latitude']},${decoded['longitude']}';
        }
      } catch (_) {}
    }
    if (destination.isEmpty) return;
    await _launch(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && !_isShopVisible) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primaryDark,
          title: const Text(
            'Shop unavailable',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 64, color: textSecondary),
                const SizedBox(height: 16),
                Text(
                  'This shop is currently unavailable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Its profile and products are hidden from the public.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double w = constraints.maxWidth;
          final int crossAxis = w >= 1400
              ? 5
              : w >= 1100
              ? 4
              : w >= 800
              ? 3
              : 2;
          final double maxContent = w >= 1100 ? 1280 : double.infinity;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContent),
              child: RefreshIndicator(
                color: primaryBlue,
                onRefresh: () async {
                  await _refreshSeller();
                  await _fetchItems();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(child: _buildShopHeader()),
                    SliverToBoxAdapter(child: _buildSearchAndFilterBar()),
                    SliverToBoxAdapter(child: _buildResultsHeader()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      sliver: _isLoading
                          ? const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _items.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmpty(),
                            )
                          : _buildItemsGrid(crossAxis),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _messageSeller() async {
    final chat = ChatService();
    if (chat.currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please sign in to chat.")));
      return;
    }
    if (_seller['seller_user_id']?.toString() == chat.currentUserId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("This is your own store.")));
      return;
    }
    final String title = _seller['seller_store_name']?.toString() ?? 'Store';
    try {
      final convo = await chat.findConversation(sellerId: widget.sellerId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThread(
            conversationId: convo?['conversation_id']?.toString(),
            sellerId: widget.sellerId,
            title: title,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to open chat: $e")));
      }
    }
  }

  void _reportShop() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.flag_rounded, color: priceColor),
            const SizedBox(width: 8),
            const Text(
              "Report Shop",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tell us why you're reporting this shop:",
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Describe the issue...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: priceColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final util = Utility();
                await _supabase.from('shop_reports').insert({
                  'report_id': 'REPORT_${util.generateUniqueID()}',
                  'report_seller_id': widget.sellerId,
                  'report_reporter_id': _supabase.auth.currentUser?.id,
                  'report_reason': reason,
                  'report_date_added': util.getCurrentMSEpochTime() / 1000,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Report submitted. Thank you."),
                    ),
                  );
                }
              } catch (e) {
                debugPrint("Report error: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to submit report: $e")),
                  );
                }
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: primaryDark,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.white,
      title: Text(
        _seller['seller_store_name']?.toString() ?? 'Shop',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        TextButton.icon(
          onPressed: _reportShop,
          icon: Icon(Icons.flag_rounded, color: priceColor, size: 18),
          label: Text(
            "Report",
            style: TextStyle(color: priceColor, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildShopHeader() {
    final logo = _logoProvider();
    final name = _seller['seller_store_name']?.toString() ?? 'Local Shop';
    final desc = _seller['seller_store_description']?.toString() ?? '';
    final address = _addressLine();
    final type = _seller['seller_store_type']?.toString();
    final contact = _seller['seller_contact_number']?.toString();
    final email = _seller['seller_email_address']?.toString();
    final messenger = _seller['seller_messenger_link']?.toString();
    final lastActive = _lastActiveLabel();
    final operatingHours = _operatingHours();

    final cover = _coverProvider();

    return Stack(
      children: [
        Positioned.fill(
          child: cover != null
              ? Image(image: cover, fit: BoxFit.cover)
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentBlue, primaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
        ),
        if (cover != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryBlue.withValues(alpha: 0.82),
                    primaryDark.withValues(alpha: 0.86),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: cardBorder,
                      backgroundImage: logo,
                      child: logo == null
                          ? Icon(
                              Icons.storefront_rounded,
                              color: textSecondary,
                              size: 32,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (type != null && type.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              type.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  desc,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statPill(
                    Icons.inventory_2_rounded,
                    "${_items.length} items",
                  ),
                  _statPill(Icons.verified_rounded, "Verified"),
                  if (lastActive != null)
                    _statPill(Icons.access_time_rounded, lastActive),
                ],
              ),
              if (operatingHours.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildOperatingHoursStatus(operatingHours),
              ],
              _buildPaymentMethods(),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (_seller['seller_store_coordinates'] != null ||
                      address.isNotEmpty)
                    Expanded(
                      child: _contactBtn(
                        Icons.directions_rounded,
                        "Directions",
                        _openDirections,
                      ),
                    ),
                  if ((_seller['seller_store_coordinates'] != null ||
                          address.isNotEmpty) &&
                      contact != null &&
                      contact.isNotEmpty)
                    const SizedBox(width: 8),
                  if (contact != null && contact.isNotEmpty)
                    Expanded(
                      child: _contactBtn(
                        Icons.call_rounded,
                        "Call",
                        () => _launch("tel:$contact"),
                      ),
                    ),
                  if (contact != null &&
                      contact.isNotEmpty &&
                      (messenger != null && messenger.isNotEmpty))
                    const SizedBox(width: 8),
                  if (messenger != null && messenger.isNotEmpty)
                    Expanded(
                      child: _contactBtn(
                        Icons.chat_bubble_rounded,
                        "Message",
                        () => _launch(messenger),
                      ),
                    ),
                  if ((contact == null || contact.isEmpty) &&
                      (messenger == null || messenger.isEmpty) &&
                      (email != null && email.isNotEmpty))
                    Expanded(
                      child: _contactBtn(
                        Icons.email_rounded,
                        "Email",
                        () => _launch("mailto:$email"),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _messageSeller,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text(
                    "Message Seller",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryBlue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _paymentMethodsList() {
    final raw = _seller['seller_payment_method'];
    List<dynamic> list = [];
    if (raw is List) {
      list = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        list = jsonDecode(raw);
      } catch (_) {}
    }
    return list.map((e) => e.toString()).toList();
  }

  IconData _paymentIcon(String m) {
    switch (m) {
      case "GCash":
        return Icons.account_balance_wallet_rounded;
      case "Maya":
        return Icons.credit_card_rounded;
      case "Cash on Delivery":
        return Icons.local_shipping_rounded;
      case "In-Store Payment":
        return Icons.point_of_sale_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  Widget _buildPaymentMethods() {
    final methods = _paymentMethodsList();
    if (methods.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_rounded,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                "ACCEPTED PAYMENTS",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: methods
                .map(
                  (m) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_paymentIcon(m), color: accentBlue, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          m,
                          style: TextStyle(
                            color: accentBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatingHoursStatus(Map<String, Map<String, dynamic>> hours) {
    final today = _todayName();
    final todayHours = hours[today];
    final isOpen = todayHours != null && _isOpenNow(todayHours);
    final status = _hoursSummary(hours);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showOperatingHoursSheet(hours),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (isOpen ? Colors.greenAccent : Colors.white)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: isOpen ? Colors.greenAccent : Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STORE STATUS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Hours',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                color: Colors.white.withValues(alpha: 0.88),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOperatingHoursSheet(Map<String, Map<String, dynamic>> hours) {
    final today = _todayName();
    final todayHours = hours[today];
    final isOpen = todayHours != null && _isOpenNow(todayHours);

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.38,
          maxChildSize: 0.88,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cardBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              (isOpen
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFEF4444))
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isOpen
                              ? Icons.storefront_rounded
                              : Icons.storefront_outlined,
                          color: isOpen
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOpen ? 'Open now' : 'Closed now',
                              style: TextStyle(
                                color: primaryDark,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Operating hours',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...hours.entries.map((entry) {
                    final day = entry.key;
                    final value = entry.value;
                    final active = day == today;
                    final closed = value['closed'] == true;
                    final label = closed
                        ? 'Closed'
                        : '${_format12Hour(value['open']?.toString())} - ${_format12Hour(value['close']?.toString())}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? accentBlue.withValues(alpha: 0.08)
                            : bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active
                              ? accentBlue.withValues(alpha: 0.26)
                              : cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              active ? '$day (Today)' : day,
                              style: TextStyle(
                                color: primaryDark,
                                fontSize: 13.5,
                                fontWeight: active
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(
                              color: closed
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF16A34A),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accentBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accentBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                hintText: "Search this shop...",
                hintStyle: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    Icons.search_rounded,
                    color: primaryBlue,
                    size: 20,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchItems();
                        },
                      ),
                filled: true,
                fillColor: bgColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primaryBlue, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                ...MarketCategories.categories.map(
                  (c) => _buildFilterChip(c['label'].toString()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? primaryBlue : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _selectedFilter = label);
            _fetchItems();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? primaryBlue : cardBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: priceColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "PRODUCTS",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: primaryDark,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Text(
            "${_items.length} ${_items.length == 1 ? 'item' : 'items'}",
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "No items found",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: primaryDark,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'All'
                ? "Try a different search or filter"
                : "This shop hasn't added items yet",
            style: TextStyle(color: textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsGrid(int crossAxis) {
    return SliverToBoxAdapter(
      child: MasonryGrid(
        crossAxisCount: crossAxis,
        spacing: 10,
        children: [
          for (int i = 0; i < _items.length; i++)
            _buildProductCard(_items[i], i),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item, [int index = 0]) {
    final name = item['item_name']?.toString() ?? 'Item';
    final price = Utility().formatPrice(_displayPrice(item));
    final totalStock = _effectiveStock(item);
    final stockNotApplicable = totalStock < 0;
    final lowStock = !stockNotApplicable && totalStock > 0 && totalStock <= 5;
    final outOfStock = _isItemOutOfStock(item);

    String? imageUrl;
    final raw = item['item_images'];
    if (raw is List && raw.isNotEmpty) imageUrl = raw[0].toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => StoreItemDetails.open(context, item),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _imgFallback(),
                        )
                      else
                        _imgFallback(),
                      if (outOfStock)
                        Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          alignment: Alignment.center,
                          child: const Text(
                            "OUT OF STOCK",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: primaryDark,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "₱$price",
                      style: TextStyle(
                        color: priceColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (lowStock) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Only $totalStock left",
                        style: TextStyle(
                          color: priceColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgFallback() {
    return Container(
      color: bgColor,
      child: Icon(
        Icons.image_outlined,
        color: textSecondary.withValues(alpha: 0.5),
        size: 36,
      ),
    );
  }
}
