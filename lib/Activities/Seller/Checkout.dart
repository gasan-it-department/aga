import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Activities/OrderPlaced.dart';
import 'package:gasan_port_tracker/Activities/UserDeliveryAddressList.dart';
import '../../Dialogs/LoadingDialog.dart';
import '../../Dialogs/ClassicDialog.dart';
import '../../FloatingMessages/SnackbarMessenger.dart';
import '../../Utility/BuyerScoreService.dart';
import '../../Utility/SemaphoreSmsService.dart';

class Checkout extends StatefulWidget {
  final List<Map<String, dynamic>> selectedItems;
  final num totalAmount;
  final bool returnToPreviousAfterOrder;

  const Checkout({
    super.key,
    required this.selectedItems,
    required this.totalAmount,
    this.returnToPreviousAfterOrder = false,
  });

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  final _supabase = Supabase.instance.client;
  final _loadingDialog = LoadingDialog();
  final _classicDialog = ClassicDialog();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color themeOrange = const Color(0xFFEE4D2D);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color accentGreen = const Color(0xFF10B981);
  final Color primaryBlue = const Color(0xFF2563EB);

  // Payment + fulfillment state
  String? _paymentMethod;
  String _fulfillment = "delivery"; // "delivery" | "pickup"
  bool _isProcessing = false;
  XFile? _proofFile;
  String? _proofUrl;

  List<String> _sellerFulfillment = [];

  // Seller state
  bool _loadingSeller = true;
  String? _sellerId;
  Map<String, dynamic> _seller = {};
  Map<String, dynamic> _sellerPrefs = {};
  List<String> _sellerPaymentMethods = [];
  List<Map<String, dynamic>> _sellerRates = [];
  bool _isPaymentFirst = false;

  // Buyer state
  int _buyerScore = 100;
  List<Map<String, dynamic>> _savedAddresses = [];
  Map<String, dynamic>? _selectedAddress;

  static const String _GCASH = "GCash";
  static const String _MAYA = "Maya";
  static const String _COD = "Cash on Delivery";
  static const String _OTC = "In-Store Payment";

  @override
  void initState() {
    super.initState();
    _loadSeller();
    _loadBuyer();
  }

  Future<void> _loadBuyer() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final row = await _supabase
          .from('user_data')
          .select(
            'user_name, user_account, user_delivery_address, user_buying_score',
          )
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) return;
      _buyerScore =
          int.tryParse(row['user_buying_score']?.toString() ?? '100') ?? 100;
      final raw = row['user_delivery_address'];
      List<Map<String, dynamic>> parsed = [];
      if (raw is List) {
        parsed = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        m['id'] ??= 'ADDR_legacy';
        m['is_default'] ??= true;
        parsed = [m];
      }
      Map<String, dynamic>? initial;
      if (parsed.isNotEmpty) {
        initial = parsed.firstWhere(
          (a) => a['is_default'] == true,
          orElse: () => parsed.first,
        );
      }
      if (mounted) {
        setState(() {
          _savedAddresses = parsed;
          _selectedAddress = initial;
        });
      }
    } catch (e) {
      debugPrint("Checkout buyer load error: $e");
    }
  }

  String? _blockReason;

  Future<void> _loadSeller() async {
    try {
      // Guard: all items must belong to the same seller
      final ids = widget.selectedItems
          .map((r) => _itemOf(r))
          .map(
            (it) =>
                it['item_seller_id']?.toString() ?? it['seller_id']?.toString(),
          )
          .where((s) => s != null && s.isNotEmpty)
          .toSet();
      if (ids.length > 1) {
        _blockReason =
            "Your cart contains items from multiple shops. Please checkout one shop at a time.";
        setState(() => _loadingSeller = false);
        return;
      }
      final first = widget.selectedItems.isNotEmpty
          ? _itemOf(widget.selectedItems.first)
          : <String, dynamic>{};
      _sellerId =
          first['item_seller_id']?.toString() ?? first['seller_id']?.toString();
      if (_sellerId == null || _sellerId!.isEmpty) {
        setState(() => _loadingSeller = false);
        return;
      }
      final row = await _supabase
          .from('sellers')
          .select(
            'seller_id, seller_store_name, seller_contact_number, seller_store_address, seller_payment_method, seller_preferences, seller_delivery_rates, seller_store_status, seller_operating_hours',
          )
          .eq('seller_id', _sellerId!)
          .maybeSingle();
      if (row != null) {
        if (row['seller_store_status']?.toString() != 'visible') {
          _blockReason =
              "This shop is currently unavailable and cannot accept orders.";
          setState(() => _loadingSeller = false);
          return;
        }
        _seller = Map<String, dynamic>.from(row);
        _sellerPaymentMethods = _decodeList(row['seller_payment_method']);
        final rawRates = row['seller_delivery_rates'];
        _sellerRates = rawRates is List
            ? rawRates
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : <Map<String, dynamic>>[];
        _sellerPrefs = _decodePrefsMap(row['seller_preferences']);
        _isPaymentFirst = _sellerPrefs['is_payment_first'] == true;
        final ff = _sellerPrefs['fulfillment'];
        if (ff is List)
          _sellerFulfillment = ff.map((e) => e.toString()).toList();
        if (_sellerFulfillment.isEmpty) _sellerFulfillment = ["Delivery"];
        if (!_isStoreOpenNow()) {
          _blockReason =
              "This shop is currently closed and cannot accept orders right now.";
          setState(() => _loadingSeller = false);
          return;
        }
      }
    } catch (e) {
      debugPrint("Checkout seller load error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loadingSeller = false;
          _initFulfillmentAndPayment();
        });
      }
    }
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

  bool _isStoreOpenNow() {
    final hours = _operatingHours();
    if (hours.isEmpty) return true;
    final today = hours[_todayName()];
    if (today == null) return true;
    if (today['closed'] == true) return false;
    final open = _minutesOf(today['open']?.toString());
    final close = _minutesOf(today['close']?.toString());
    if (open == null || close == null) return true;
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    if (close < open) {
      return current >= open || current <= close;
    }
    return current >= open && current <= close;
  }

  // --- Fulfillment (Delivery / Pickup) and payment instruments ---
  // Delivery → allows COD, hides In-Store Payment
  // Pickup   → allows In-Store Payment, hides COD
  // Payment First Policy → only digital (GCash/Maya), also forces Delivery off if pickup unavailable; otherwise both allowed
  bool get _hasPickup => _sellerFulfillment.contains("In-Store Pickup");
  bool get _hasDelivery => _sellerFulfillment.contains("Delivery");

  List<String> _availablePaymentsForCurrent() {
    final all = List<String>.from(_sellerPaymentMethods);
    if (_buyerScore < BuyerScoreService.normalMinimum) {
      all.removeWhere((m) => m == _COD);
    }
    if (_fulfillment == "pickup") {
      all.removeWhere((m) => m == _COD); // no delivery → no COD
    } else {
      all.removeWhere((m) => m == _OTC); // no store visit → no In-Store Payment
    }
    if (_isPaymentFirst) {
      all.removeWhere((m) => m == _COD || m == _OTC);
    }
    return all;
  }

  void _initFulfillmentAndPayment() {
    if (_hasPickup && !_hasDelivery) {
      _fulfillment = "pickup";
    } else {
      _fulfillment = "delivery";
    }
    final available = _availablePaymentsForCurrent();
    _paymentMethod = available.isNotEmpty ? available.first : null;
  }

  List<String> _decodeList(dynamic raw) {
    try {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) {
        final d = jsonDecode(raw);
        if (d is List) return d.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic> _decodePrefsMap(dynamic raw) {
    try {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      if (raw is String && raw.isNotEmpty) {
        final d = jsonDecode(raw);
        if (d is Map) return Map<String, dynamic>.from(d);
      }
    } catch (_) {}
    return {};
  }

  String _sellerAddressLine() {
    final addr = _seller['seller_store_address'];
    if (addr is Map) {
      return [
        addr['street'],
        addr['barangay'],
        addr['municipality'],
        addr['province'],
      ].where((s) => s != null && s.toString().isNotEmpty).join(", ");
    }
    if (addr is String) return addr;
    return "";
  }

  // --- Delivery rate matching ---
  String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

  Map<String, dynamic>? _matchedRate() {
    final a = _selectedAddress;
    if (a == null) return null;
    final am = _norm(a['municipality']);
    final ab = _norm(a['barangay']);
    if (am.isEmpty || ab.isEmpty) return null;
    for (final r in _sellerRates) {
      if (_norm(r['rate_municipality']) == am &&
          _norm(r['rate_barangay']) == ab)
        return r;
    }
    return null;
  }

  num? _deliveryFee() {
    final r = _matchedRate();
    if (r == null) return null;
    return num.tryParse(r['rate_amount']?.toString() ?? '0') ?? 0;
  }

  bool get _isDelivery => _fulfillment == "delivery";

  num get _minOrder =>
      (_sellerPrefs['delivery_min_order'] as num?)?.toDouble() ?? 0;

  bool get _belowMinOrder =>
      _isDelivery && _minOrder > 0 && _itemSubtotal() < _minOrder;

  // Buyer's chosen address has no matching seller delivery rate.
  bool get _isUnreachable =>
      _isDelivery && _selectedAddress != null && _matchedRate() == null;

  num get _effectiveDeliveryFee =>
      (_isDelivery && !_isUnreachable) ? (_deliveryFee() ?? 0) : 0;

  Future<void> _sendSellerOrderSms(String orderId) async {
    final number = _seller['seller_contact_number']?.toString() ?? '';
    debugPrint(
      '[CheckoutSMS][$orderId] START seller_id=$_sellerId '
      'has_contact=${number.trim().isNotEmpty}',
    );
    if (number.trim().isEmpty) {
      debugPrint(
        '[CheckoutSMS][$orderId] SKIPPED code=missing_seller_contact '
        'seller_id=$_sellerId',
      );
      return;
    }
    final result = await SemaphoreSmsService().sendOrderPlacedToSeller(
      sellerNumber: number,
      orderId: orderId,
    );
    debugPrint(
      '[CheckoutSMS][$orderId] COMPLETE sent=${result.sent} '
      'code=${result.code} http=${result.httpStatus ?? '<none>'} '
      'provider_status=${result.providerStatus ?? '<none>'}',
    );
  }

  bool get _requiresProof =>
      _paymentMethod == _GCASH || _paymentMethod == _MAYA;

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (x != null) setState(() => _proofFile = x);
  }

  Future<String?> _uploadProof() async {
    if (_proofFile == null) return _proofUrl;
    try {
      final bytes = await _proofFile!.readAsBytes();
      final util = Utility();
      final ext = _proofFile!.name.split('.').last;
      final path = "proof_${util.generateUniqueID()}.$ext";
      await _supabase.storage
          .from('order_proof')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = _supabase.storage.from('order_proof').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint("Upload proof error: $e");
      return null;
    }
  }

  String? _mobileNumberForSelected() {
    String? raw;
    if (_paymentMethod == _GCASH)
      raw = _sellerPrefs['gcash_number']?.toString();
    if (_paymentMethod == _MAYA) raw = _sellerPrefs['maya_number']?.toString();
    final trimmed = raw?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _qrUrlForSelected() {
    if (_paymentMethod == _GCASH)
      return _sellerPrefs['gcash_qr_image']?.toString();
    if (_paymentMethod == _MAYA)
      return _sellerPrefs['maya_qr_image']?.toString();
    return null;
  }

  num _unitPriceOf(Map<String, dynamic> raw) {
    final variation = raw['cart_variation'];
    if (variation is Map && variation['price'] != null) {
      return num.tryParse(variation['price'].toString()) ?? 0;
    }
    final item = _itemOf(raw);
    return num.tryParse(item['item_price']?.toString() ?? '0') ?? 0;
  }

  num _itemSubtotal() {
    num sum = 0;
    for (final raw in widget.selectedItems) {
      final price = _unitPriceOf(raw);
      final qty = num.tryParse(raw['cart_quantity']?.toString() ?? '1') ?? 1;
      sum += price * qty;
    }
    return sum;
  }

  Map<String, dynamic> _itemOf(Map<String, dynamic> raw) {
    if (raw['store_items'] is Map<String, dynamic>)
      return Map<String, dynamic>.from(raw['store_items']);
    return raw;
  }

  bool _hasUnavailableItem() {
    for (final raw in widget.selectedItems) {
      final item = _itemOf(raw);
      if (item['item_available'] != true) return true;
    }
    return false;
  }

  List<String> _unavailableItemNames() {
    final names = <String>[];
    for (final raw in widget.selectedItems) {
      final item = _itemOf(raw);
      if (item['item_available'] != true) {
        names.add((item['item_name'] ?? 'Unnamed item').toString());
      }
    }
    return names;
  }

  Future<void> _processCheckout() async {
    if (_buyerScore < BuyerScoreService.purchaseMinimum) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "Your buying score is too low to place orders. Please contact an administrator.",
      );
      return;
    }
    if (_blockReason != null) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        _blockReason!,
      );
      return;
    }
    if (_hasUnavailableItem()) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "One or more items are no longer available.",
      );
      return;
    }
    if (_paymentMethod == null) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "Please select a payment method.",
      );
      return;
    }
    if (_buyerScore < BuyerScoreService.normalMinimum &&
        _paymentMethod == _COD) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "Cash on Delivery is disabled because of your buying score.",
      );
      return;
    }
    if (_isPaymentFirst && (_paymentMethod == _COD || _paymentMethod == _OTC)) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "This shop requires online payment. Please choose GCash or Maya.",
      );
      return;
    }
    if ((_paymentMethod == _GCASH || _paymentMethod == _MAYA) &&
        (_qrUrlForSelected() == null || _qrUrlForSelected()!.isEmpty)) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "Seller hasn't uploaded a $_paymentMethod QR. Please pick another method or contact the seller.",
      );
      return;
    }
    if (_requiresProof &&
        _proofFile == null &&
        (_proofUrl == null || _proofUrl!.isEmpty)) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "Please upload your payment proof receipt.",
      );
      return;
    }
    if (_selectedAddress == null) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "Please add a delivery address to continue.",
      );
      return;
    }
    if (_fulfillment == "pickup" && _sellerAddressLine().isEmpty) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "Pickup address unavailable. Please contact the seller.",
      );
      return;
    }
    if (_isUnreachable) {
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.failed,
        "This shop doesn't deliver to your selected address. Choose another address or pick up at the store.",
      );
      return;
    }

    setState(() => _isProcessing = true);
    _loadingDialog.showLoadingDialog(context);
    _loadingDialog.updateTitle("Placing order...");

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      final util = Utility();
      final orderId = "ORDER_${util.generateUniqueID()}";

      // Build delivery address jsonb. Buyer info travels here for both
      // delivery and pickup so the seller can identify who placed the order.
      final buyer = _selectedAddress ?? <String, dynamic>{};
      final buyerFields = {
        "first_name": buyer['first_name'],
        "middle_name": buyer['middle_name'],
        "last_name": buyer['last_name'],
        "contact_number": buyer['contact_number'],
        "email": buyer['email'],
      };
      Map<String, dynamic> deliveryAddress;
      if (_fulfillment == "pickup") {
        final saddr = _seller['seller_store_address'];
        if (saddr is Map) {
          deliveryAddress = {
            "delivery_type": "Pickup",
            ...buyerFields,
            "province": saddr['province'],
            "municipality": saddr['municipality'],
            "barangay": saddr['barangay'],
            "street": saddr['street'],
          };
        } else {
          deliveryAddress = {
            "delivery_type": "Pickup",
            ...buyerFields,
            "street": _sellerAddressLine(),
          };
        }
      } else {
        final a = _selectedAddress ?? <String, dynamic>{};
        deliveryAddress = {
          "delivery_type": "Delivery",
          "first_name": a['first_name'],
          "middle_name": a['middle_name'],
          "last_name": a['last_name'],
          "contact_number": a['contact_number'],
          "email": a['email'],
          "province": a['province'],
          "municipality": a['municipality'],
          "barangay": a['barangay'],
          "street": a['street'],
          "coordinates": a['coordinates'],
          "notes": a['notes'],
          "delivery_fee": _effectiveDeliveryFee,
        };
      }

      // Seller zipcode
      num? sellerZip;
      final saddr = _seller['seller_store_address'];
      if (saddr is Map && saddr['zip_code'] != null) {
        sellerZip = num.tryParse(saddr['zip_code'].toString());
      }

      String? proofUrl;
      if (_requiresProof) {
        _loadingDialog.updateTitle("Uploading payment proof...");
        proofUrl = await _uploadProof();
        if (proofUrl == null || proofUrl.isEmpty) {
          throw Exception("Failed to upload payment proof. Please try again.");
        }
        _proofUrl = proofUrl;
      }

      final paymentDetails = {
        "channel": _paymentMethod,
        "payment_proof_url": proofUrl,
      };
      final orderMetaData = {
        "delivery_fee": _effectiveDeliveryFee,
        "items_count": widget.selectedItems.length,
        "fulfillment":
            deliveryAddress['delivery_type']?.toString() ?? _fulfillment,
      };

      // Insert one row per item
      final List<Map<String, dynamic>> receiptItems = [];
      final List<Map<String, dynamic>> orderRows = [];
      final List<String> cartIds = [];
      num grandTotal = 0;
      for (int i = 0; i < widget.selectedItems.length; i++) {
        final raw = widget.selectedItems[i];
        final item = _itemOf(raw);
        final unitPrice = _unitPriceOf(raw);
        final qty = num.tryParse(raw['cart_quantity']?.toString() ?? '1') ?? 1;
        final lineTotal = unitPrice * qty;
        final variation = raw['cart_variation'] is Map
            ? Map<String, dynamic>.from(raw['cart_variation'])
            : null;
        final displayName = variation != null
            ? "${item['item_name'] ?? 'Item'} (${variation['label']})"
            : (item['item_name'] ?? 'Item').toString();
        grandTotal += lineTotal;
        receiptItems.add({
          'name': displayName,
          'qty': qty,
          'unit_price': unitPrice,
          'line_total': lineTotal,
        });
        orderRows.add({
          'order_id': widget.selectedItems.length == 1
              ? orderId
              : '${orderId}_${i + 1}',
          'order_group_id': orderId,
          'order_user_id': user.id,
          'order_item_id': item['item_id'],
          'order_quantity': qty,
          'order_total_price': lineTotal,
          'order_delivery_address': deliveryAddress,
          'order_meta_data': orderMetaData,
          'order_notes': _noteCtrl.text.trim(),
          'order_payment_details': paymentDetails,
          'order_status': 'placed',
          'order_seller_id': _sellerId,
          'order_seller_zipcode': sellerZip,
          if (variation != null) 'order_variation': variation,
        });
        if (raw['cart_id'] != null) {
          cartIds.add(raw['cart_id'].toString());
        }
      }

      debugPrint(
        'Checkout: inserting ${orderRows.length} order row(s) for group $orderId.',
      );
      await _supabase.rpc(
        'place_order_with_stock_check',
        params: {'p_order_rows': orderRows},
      );
      debugPrint('Checkout: order rows inserted for group $orderId.');
      if (cartIds.isNotEmpty) {
        await _supabase.from('cart').delete().inFilter('cart_id', cartIds);
      }

      debugPrint(
        '[CheckoutSMS][$orderId] Order committed; starting seller SMS notification.',
      );
      await _sendSellerOrderSms(orderId);

      grandTotal += _effectiveDeliveryFee;

      if (mounted) {
        _loadingDialog.dismiss();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderPlaced(
              orderId: orderId,
              sellerName: _seller['seller_store_name']?.toString() ?? '',
              items: receiptItems,
              total: grandTotal,
              deliveryFee: _effectiveDeliveryFee,
              paymentChannel: _paymentMethod ?? '',
              deliveryType:
                  deliveryAddress['delivery_type']?.toString() ?? _fulfillment,
              deliveryAddress: deliveryAddress,
              notes: _noteCtrl.text.trim(),
              placedAt: DateTime.now(),
              returnToPrevious: widget.returnToPreviousAfterOrder,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _loadingDialog.dismiss();
        if (_isStockException(e)) {
          _showOutOfStockDialog();
        } else {
          SnackbarMessenger().showSnackbar(
            context,
            SnackbarMessenger.failed,
            "Checkout failed. Please try again.",
          );
          debugPrint('Checkout failed: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  bool _isStockException(Object error) {
    final message = error is PostgrestException
        ? error.message.toLowerCase()
        : error.toString().toLowerCase();
    return message.contains('insufficient stock') ||
        message.contains('out of stock') ||
        (message.contains('variation') && message.contains('unavailable'));
  }

  void _showOutOfStockDialog() {
    _classicDialog.setTitle('Item Out of Stock');
    _classicDialog.setMessage(
      'One or more selected items no longer have enough stock. '
      'Please review the quantities or choose another variation.',
    );
    _classicDialog.setCancelable(false);
    _classicDialog.setPositiveMessage('Review Items');
    _classicDialog.showOnButtonDialog(context, () {
      _classicDialog.dismissDialog();
    });
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _itemSubtotal();
    final total = subtotal + _effectiveDeliveryFee;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
      ),
      body: _loadingSeller
          ? const Center(child: CircularProgressIndicator())
          : _blockReason != null
          ? _buildBlockedView(_blockReason!)
          : LayoutBuilder(
              builder: (context, constraints) {
                final double w = constraints.maxWidth;
                final double maxW = w >= 1000 ? 900 : double.infinity;
                int step = 0;
                String nextStep() {
                  step += 1;
                  return "$step";
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      children: [
                        _buildStepHeader(),
                        const SizedBox(height: 12),
                        if (_hasPickup && _hasDelivery) ...[
                          _buildFulfillmentCard(stepLabel: nextStep()),
                          const SizedBox(height: 12),
                        ],
                        _buildAddressOrPickupCard(stepLabel: nextStep()),
                        const SizedBox(height: 12),
                        _buildItemsCard(),
                        const SizedBox(height: 12),
                        _buildPaymentCard(stepLabel: nextStep()),
                        const SizedBox(height: 12),
                        _buildNoteCard(),
                        const SizedBox(height: 12),
                        _buildSummaryCard(subtotal, total),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: _loadingSeller || _blockReason != null
          ? null
          : _buildPlaceOrderBar(total),
    );
  }

  Widget _buildStepHeader() {
    final storeName = _seller['seller_store_name']?.toString() ?? 'this shop';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryBlue.withValues(alpha: 0.08),
            themeOrange.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_rounded, color: primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ordering from",
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  storeName,
                  style: TextStyle(
                    color: primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          if (_isPaymentFirst)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: themeOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "PAY FIRST",
                style: TextStyle(
                  color: themeOrange,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String label, {String? step}) {
    return Row(
      children: [
        if (step != null) ...[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: themeOrange,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ] else ...[
          Icon(icon, color: themeOrange, size: 18),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: primaryDark,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _buildBlockedView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_shopping_cart_rounded,
              size: 64,
              color: textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              "Can't checkout yet",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: primaryDark,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Go Back"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFulfillmentCard({String stepLabel = "1"}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.local_shipping_rounded,
            "HOW TO RECEIVE",
            step: stepLabel,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _fulfillmentChip(
                  "delivery",
                  Icons.local_shipping_rounded,
                  "Delivery",
                  "Ship to my address",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _fulfillmentChip(
                  "pickup",
                  Icons.storefront_rounded,
                  "Pickup",
                  "At the store",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fulfillmentChip(
    String value,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final selected = _fulfillment == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _fulfillment = value;
          final avail = _availablePaymentsForCurrent();
          _paymentMethod = avail.isNotEmpty ? avail.first : null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? themeOrange.withValues(alpha: 0.06) : bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? themeOrange : cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? themeOrange : textSecondary, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: primaryDark,
                fontSize: 13.5,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: textSecondary, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressOrPickupCard({String stepLabel = "2"}) {
    if (_fulfillment == "pickup") {
      final addr = _sellerAddressLine();
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              Icons.location_on_rounded,
              "PICKUP LOCATION",
              step: stepLabel,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.storefront_rounded, color: accentGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _seller['seller_store_name']?.toString() ?? "Store",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: primaryDark,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          addr.isEmpty ? "Address not provided" : addr,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildBuyerInfoBlock(),
          ],
        ),
      );
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.location_on_rounded,
            "DELIVERY ADDRESS",
            step: stepLabel,
          ),
          const SizedBox(height: 10),
          if (_savedAddresses.isEmpty)
            _buildNoAddressCta()
          else
            _buildAddressPicker(),
          if (_isUnreachable) ...[
            const SizedBox(height: 12),
            _buildUnreachableBanner(),
          ],
          const SizedBox(height: 14),
          _buildBuyerInfoBlock(),
        ],
      ),
    );
  }

  Widget _buildAddressPicker() {
    final selected = _selectedAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected != null) _buildAddressOption(selected, true),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openChangeAddressSheet,
                icon: Icon(
                  Icons.swap_horiz_rounded,
                  color: themeOrange,
                  size: 16,
                ),
                label: Text(
                  _savedAddresses.length > 1
                      ? "Change Address"
                      : "Choose Address",
                  style: TextStyle(
                    color: themeOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: themeOrange.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openManageAddresses,
                icon: Icon(
                  Icons.add_location_alt_rounded,
                  color: primaryBlue,
                  size: 16,
                ),
                label: Text(
                  "Add / Manage",
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryBlue.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openManageAddresses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserDeliveryAddressList()),
    );
    await _loadBuyer();
  }

  Widget _buildAddressOption(Map<String, dynamic> a, bool isSelected) {
    final name = [
      (a['first_name'] ?? '').toString().trim(),
      (a['last_name'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    final line = [
      (a['street'] ?? '').toString().trim(),
      (a['barangay'] ?? '').toString().trim(),
      (a['municipality'] ?? '').toString().trim(),
      (a['province'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(', ');
    final isDefault = a['is_default'] == true;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selectedAddress = a),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? themeOrange.withValues(alpha: 0.06) : bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? themeOrange : cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? themeOrange : textSecondary,
              size: 20,
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
                          name.isEmpty ? "Recipient" : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: primaryDark,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "DEFAULT",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    line,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnreachableBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            color: Color(0xFFB91C1C),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Unreachable address",
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "This shop doesn't deliver to your selected barangay. Choose another address or pick up at the store.",
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAddressCta() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeOrange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_off_rounded, color: themeOrange, size: 18),
              const SizedBox(width: 8),
              Text(
                "No saved delivery address",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: primaryDark,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Add an address so we can deliver your order. You can manage your addresses here.",
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openManageAddresses,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: const Text(
                "Add Delivery Address",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openChangeAddressSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: cardBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: themeOrange),
                    const SizedBox(width: 12),
                    const Text(
                      "Choose Delivery Address",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: cardBorder),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: _savedAddresses.length,
                  itemBuilder: (_, i) {
                    final a = _savedAddresses[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() => _selectedAddress = a);
                          Navigator.pop(sheetCtx);
                        },
                        child: _buildAddressOption(
                          a,
                          a['id'] == _selectedAddress?['id'],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _openManageAddresses();
                      },
                      icon: const Icon(
                        Icons.add_location_alt_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        "Add / Manage Addresses",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBuyerInfoBlock() {
    final selected = _selectedAddress;
    if (selected == null) return const SizedBox.shrink();
    final first = (selected['first_name'] ?? '').toString().trim();
    final middle = (selected['middle_name'] ?? '').toString().trim();
    final last = (selected['last_name'] ?? '').toString().trim();
    final fullName = [first, middle, last].where((s) => s.isNotEmpty).join(' ');
    final notes = (selected['notes'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, color: primaryBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                "BUYER INFORMATION",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buyerKv(
            Icons.badge_outlined,
            "Name",
            fullName.isEmpty ? "—" : fullName,
          ),
          if (middle.isNotEmpty)
            _buyerKv(Icons.short_text_rounded, "Middle name", middle),
          if ((selected['contact_number'] ?? '').toString().trim().isNotEmpty)
            _buyerKv(
              Icons.call_rounded,
              "Contact",
              (selected['contact_number']).toString().trim(),
            ),
          if ((selected['email'] ?? '').toString().trim().isNotEmpty)
            _buyerKv(
              Icons.alternate_email_rounded,
              "Email",
              (selected['email']).toString().trim(),
            ),
          if (notes.isNotEmpty)
            _buyerKv(Icons.notes_rounded, "Address notes", notes),
        ],
      ),
    );
  }

  Widget _buyerKv(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textSecondary, size: 14),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: primaryDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.shopping_bag_rounded,
            "ORDER ITEMS (${widget.selectedItems.length})",
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < widget.selectedItems.length; i++) ...[
            _buildItemRow(widget.selectedItems[i]),
            if (i < widget.selectedItems.length - 1)
              Divider(color: cardBorder, height: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> raw) {
    final item = _itemOf(raw);
    final name = item['item_name']?.toString() ?? 'Item';
    final variation = raw['cart_variation'] is Map
        ? Map<String, dynamic>.from(raw['cart_variation'])
        : null;
    final unitPrice = _unitPriceOf(raw);
    final qty = num.tryParse(raw['cart_quantity']?.toString() ?? '1') ?? 1;
    final stocks = variation != null
        ? num.tryParse(variation['stock']?.toString() ?? '')
        : num.tryParse(item['item_stocks']?.toString() ?? '');
    final lineTotal = unitPrice * qty;
    final imgs = item['item_images'];
    String? img;
    if (imgs is List && imgs.isNotEmpty) img = imgs[0].toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: img != null
                ? Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgFallback(),
                  )
                : _imgFallback(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
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
                  fontSize: 13.5,
                ),
              ),
              if (variation != null) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    "Variant: ${variation['label']}",
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                "₱${Utility().formatPrice(unitPrice)} each",
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _qtyStepper(raw, qty.toInt(), stocks?.toInt()),
            ],
          ),
        ),
        Text(
          "₱${Utility().formatPrice(lineTotal)}",
          style: TextStyle(
            color: themeOrange,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _qtyStepper(Map<String, dynamic> raw, int qty, int? maxStock) {
    final canDec = qty > 1;
    final canInc = maxStock == null || maxStock < 0 || qty < maxStock;
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyButton(Icons.remove_rounded, canDec, () {
            setState(() => raw['cart_quantity'] = qty - 1);
          }),
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            alignment: Alignment.center,
            child: Text(
              "$qty",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: primaryDark,
                fontSize: 13,
              ),
            ),
          ),
          _qtyButton(Icons.add_rounded, canInc, () {
            setState(() => raw['cart_quantity'] = qty + 1);
          }),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? primaryDark : textSecondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    color: bgColor,
    child: Icon(
      Icons.image_outlined,
      color: textSecondary.withValues(alpha: 0.4),
    ),
  );

  IconData _paymentIcon(String m) {
    switch (m) {
      case _GCASH:
        return Icons.account_balance_wallet_rounded;
      case _MAYA:
        return Icons.credit_card_rounded;
      case _COD:
        return Icons.local_shipping_rounded;
      case _OTC:
        return Icons.point_of_sale_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  String _paymentLabel(String m) => m;

  String _paymentSubtitle(String m) {
    switch (m) {
      case _GCASH:
        return "Scan the seller's QR & send";
      case _MAYA:
        return "Scan the seller's QR & send";
      case _COD:
        return "Pay cash when the order arrives";
      case _OTC:
        return "Pay with cash at the store counter";
      default:
        return "";
    }
  }

  Widget _buildPaymentCard({String stepLabel = "3"}) {
    final available = _availablePaymentsForCurrent();
    final qrUrl = _qrUrlForSelected();
    final needsQrButMissing =
        (_paymentMethod == _GCASH || _paymentMethod == _MAYA) &&
        (qrUrl == null || qrUrl.isEmpty);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.payments_rounded,
            "PAYMENT METHOD",
            step: stepLabel,
          ),
          const SizedBox(height: 4),
          Text(
            _isPaymentFirst
                ? "This shop requires payment before processing your order."
                : "Choose how you want to pay.",
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          if (available.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "No payment methods available for this option.",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            )
          else
            ...available.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _paymentOption(
                  m,
                  _paymentIcon(m),
                  _paymentLabel(m),
                  _paymentSubtitle(m),
                ),
              ),
            ),
          if ((_paymentMethod == _GCASH || _paymentMethod == _MAYA) &&
              _mobileNumberForSelected() != null) ...[
            const SizedBox(height: 8),
            _buildWalletNumberPanel(
              _paymentMethod!,
              _mobileNumberForSelected()!,
            ),
          ],
          if (qrUrl != null && qrUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildQrPanel(qrUrl),
          ],
          if (_requiresProof) ...[
            const SizedBox(height: 10),
            _buildProofUploader(),
          ],
          if (needsQrButMissing) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade800,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Seller hasn't uploaded a $_paymentMethod QR yet. Pick another method or message the seller.",
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProofUploader() {
    final hasFile = _proofFile != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeOrange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeOrange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: themeOrange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Upload Payment Proof",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: primaryDark,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: themeOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "REQUIRED",
                  style: TextStyle(
                    color: themeOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Send the total via $_paymentMethod, then upload a screenshot of your receipt below.",
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          if (hasFile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: kIsWeb
                        ? Image.network(_proofFile!.path, fit: BoxFit.cover)
                        : Image.file(File(_proofFile!.path), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _proofFile!.name,
                        style: TextStyle(
                          color: primaryDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickProof,
                            icon: Icon(
                              Icons.swap_horiz_rounded,
                              size: 16,
                              color: primaryBlue,
                            ),
                            label: Text(
                              "Replace",
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: primaryBlue),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _proofFile = null;
                              _proofUrl = null;
                            }),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Colors.red,
                            ),
                            label: Text(
                              "Remove",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickProof,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: themeOrange.withValues(alpha: 0.4),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      color: themeOrange,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Tap to upload receipt",
                      style: TextStyle(
                        color: themeOrange,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "PNG / JPG",
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _viewQrFullscreen(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Container(
                  color: Colors.white,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, prog) => prog == null
                        ? child
                        : Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(40),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_rounded,
                            color: textSecondary,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          const Text("Couldn't load QR image."),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.6),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.zoom_in_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Pinch to zoom. Scan with your $_paymentMethod app.",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletNumberPanel(String method, String number) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.phone_iphone_rounded,
              color: primaryBlue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$method Mobile Number",
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  number,
                  style: TextStyle(
                    color: primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: "Copy",
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: number));
              if (!mounted) return;
              SnackbarMessenger().showSnackbar(
                context,
                SnackbarMessenger.success,
                "$method number copied",
              );
            },
            icon: Icon(Icons.copy_rounded, color: primaryBlue, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPanel(String url) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _viewQrFullscreen(url),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: bgColor,
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.zoom_out_map_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pay via $_paymentMethod",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: primaryDark,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "1. Tap the QR to view full screen\n2. Scan & send the total amount\n3. Upload the payment proof below",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _viewQrFullscreen(url),
              icon: Icon(Icons.qr_code_2_rounded, color: primaryBlue, size: 18),
              label: Text(
                "View QR Code",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primaryBlue.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentOption(
    String value,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final selected = _paymentMethod == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? themeOrange.withValues(alpha: 0.06) : bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? themeOrange : cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? themeOrange : textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: primaryDark,
                      fontSize: 13.5,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(color: textSecondary, fontSize: 11.5),
                    ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? themeOrange : textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.edit_note_rounded, "NOTES (OPTIONAL)"),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Special instructions for seller...",
              hintStyle: TextStyle(color: textSecondary, fontSize: 13),
              filled: true,
              fillColor: bgColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: themeOrange, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(num subtotal, num total) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.receipt_long_rounded, "ORDER SUMMARY"),
          const SizedBox(height: 12),
          _summaryRow("Subtotal", subtotal),
          const SizedBox(height: 6),
          if (_isDelivery)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    "Delivery Fee",
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _isUnreachable
                      ? Text(
                          "Unreachable",
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        )
                      : Text(
                          "₱${Utility().formatPrice(_effectiveDeliveryFee)}",
                          style: TextStyle(
                            color: primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                ],
              ),
            ),
          _summaryRow("Voucher Discount", 0),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                "Payment",
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _paymentMethod ?? "—",
                style: TextStyle(
                  color: primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Divider(color: cardBorder, height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: primaryDark,
                  fontSize: 16,
                ),
              ),
              Text(
                "₱${Utility().formatPrice(total)}",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: themeOrange,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, num value, {String? note}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (note != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              "($note)",
              style: TextStyle(
                color: textSecondary.withValues(alpha: 0.7),
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const Spacer(),
        Text(
          "₱${Utility().formatPrice(value)}",
          style: TextStyle(
            color: primaryDark,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderBar(num total) {
    final unavailable = _hasUnavailableItem();
    final missingAddress = _selectedAddress == null;
    final unreachable = _isUnreachable;
    final belowMin = _belowMinOrder;
    final disabled =
        _isProcessing ||
        _paymentMethod == null ||
        unavailable ||
        missingAddress ||
        unreachable ||
        belowMin;
    final unavailableNames = unavailable
        ? _unavailableItemNames()
        : const <String>[];
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: cardBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unavailable) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFB91C1C),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Item not available",
                            style: TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            unavailableNames.length == 1
                                ? "${unavailableNames.first} is currently unavailable. Remove it from your cart to continue."
                                : "${unavailableNames.length} items are currently unavailable. Remove them from your cart to continue.",
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!unavailable && missingAddress) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: themeOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: themeOrange.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_off_rounded,
                      color: themeOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Delivery address required",
                            style: TextStyle(
                              color: themeOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Add an address in My Account → Delivery Address to place your order.",
                            style: TextStyle(
                              color: primaryDark.withValues(alpha: 0.75),
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!unavailable && !missingAddress && belowMin) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: themeOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: themeOrange.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shopping_bag_rounded,
                      color: themeOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Minimum order not met",
                            style: TextStyle(
                              color: themeOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "This shop requires a ₱${Utility().formatPrice(_minOrder)} minimum subtotal for delivery. Add more items to continue.",
                            style: TextStyle(
                              color: primaryDark.withValues(alpha: 0.75),
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "TOTAL",
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      "₱${Utility().formatPrice(total)}",
                      style: TextStyle(
                        color: themeOrange,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Material(
                    color: disabled ? Colors.grey : themeOrange,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: disabled ? null : _processCheckout,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              unavailable
                                  ? Icons.block_rounded
                                  : missingAddress
                                  ? Icons.location_off_rounded
                                  : unreachable
                                  ? Icons.local_shipping_rounded
                                  : belowMin
                                  ? Icons.shopping_bag_rounded
                                  : Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              unavailable
                                  ? "Item Unavailable"
                                  : missingAddress
                                  ? "Add Address"
                                  : unreachable
                                  ? "Unreachable"
                                  : belowMin
                                  ? "Min ₱${Utility().formatPrice(_minOrder)}"
                                  : "Place Order",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
