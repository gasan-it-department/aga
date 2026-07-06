import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Map/MapLocationPicker.dart';
import 'package:latlong2/latlong.dart';
import 'package:gasan_port_tracker/Activities/Seller/StoreItemList.dart';
import 'package:gasan_port_tracker/Activities/Seller/DeliveryRateList.dart';
import 'package:gasan_port_tracker/Activities/Seller/StoreAnalytics.dart';
import 'package:gasan_port_tracker/Activities/Chat/ChatInbox.dart';
import 'package:gasan_port_tracker/Utility/ChatService.dart';
import 'package:gasan_port_tracker/Utility/SemaphoreSmsService.dart';
import 'package:gasan_port_tracker/Services/OnlineStoreWidgetService.dart';
import 'package:gasan_port_tracker/Activities/Seller/SubActivities/SellerOrders.dart';
import 'package:gasan_port_tracker/Activities/Seller/SubActivities/SellerOperatingHours.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'package:gasan_port_tracker/Dialogs/Bottomsheets/DeleteShopConfirmation.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';

import '../../Dialogs/LoadingDialog.dart';

class SellerProfile extends StatefulWidget {
  const SellerProfile({super.key});

  @override
  State<SellerProfile> createState() => _SellerProfileState();
}

class _SellerProfileState extends State<SellerProfile> {
  final _supabase = Supabase.instance.client;

  // --- THEME COLORS ---
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color primaryBlue = const Color(0xFF2563EB);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color warningColor = const Color(0xFFF59E0B);
  final Color successColor = const Color(0xFF10B981);
  final Color dangerColor = const Color(0xFFEF4444);

  // --- CONTROLLERS ---
  final TextEditingController _storeNameCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _streetCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _messengerCtrl = TextEditingController();
  final TextEditingController _gcashQrCtrl = TextEditingController();
  final TextEditingController _mayaQrCtrl = TextEditingController();

  // --- ADDRESS STATE ---
  String? _selectedProvince = "Marinduque";
  String? _selectedMunicipality;
  String? _selectedBarangay;

  final List<String> _provinces = ["Marinduque"];
  final Map<String, List<String>> _municipalities = {
    "Marinduque": [
      "Boac",
      "Buenavista",
      "Gasan",
      "Mogpog",
      "Santa Cruz",
      "Torrijos",
    ],
  };
  final Map<String, List<String>> _barangays = {
    "Boac": [
      "Agot",
      "Agumaymayan",
      "Amoingon",
      "Apitong",
      "Balagasan",
      "Balaring",
      "Balimbing",
      "Balogo",
      "Bamban",
      "Bangbangalon",
      "Bantad",
      "Bantay",
      "Bayuti",
      "Binunga",
      "Boi",
      "Boton",
      "Buliasnin",
      "Bunganay",
      "Caganhao",
      "Canat",
      "Catubugan",
      "Cawit",
      "Daig",
      "Daypay",
      "Duyay",
      "Hinapulan",
      "Ihatub",
      "Isok I (Poblacion)",
      "Isok II Poblacion",
      "Laylay",
      "Lupac",
      "Mahinhin",
      "Mainit",
      "Malbog",
      "Maligaya",
      "Malusak (Poblacion)",
      "Mansiwat",
      "Mataas na Bayan (Poblacion)",
      "Maybo",
      "Mercado (Poblacion)",
      "Murallon (Poblacion)",
      "Ogbac",
      "Pawa",
      "Pili",
      "Poctoy",
      "Poras",
      "Puting Buhangin",
      "Puyog",
      "Sabong",
      "San Miguel (Poblacion)",
      "Santol",
      "Sawi",
      "Tabi",
      "Tabigue",
      "Tagwak",
      "Tambunan",
      "Tampus (Poblacion)",
      "Tanza",
      "Tugos",
      "Tumagabok",
      "Tumapon",
    ],
    "Buenavista": [
      "Bagacay",
      "Bagtingon",
      "Barangay I (Poblacion)",
      "Barangay II (Poblacion)",
      "Barangay III (Poblacion)",
      "Barangay IV (Poblacion)",
      "Bicas-Bicas",
      "Caigangan",
      "Daykitin",
      "Libas",
      "Malbog",
      "Sihi",
      "Timbo",
      "Tungib-Lipata",
      "Yook",
    ],
    "Gasan": [
      "Antipolo",
      "Bachao Ibaba",
      "Bachao Ilaya",
      "Bacongbacong",
      "Bahi",
      "Bangbang",
      "Banot",
      "Banuyo",
      "Barangay I (Poblacion)",
      "Barangay II (Poblacion)",
      "Barangay III (Poblacion)",
      "Bognuyan",
      "Cabugao",
      "Dawis",
      "Dili",
      "Libtangin",
      "Mahunig",
      "Mangiliol",
      "Masiga",
      "Matandang Gasan",
      "Pangi",
      "Pingan",
      "Tabionan",
      "Tapuyan",
      "Tiguion",
    ],
    "Mogpog": [
      "Anapog-Sibucao",
      "Argao",
      "Balanacan",
      "Banto",
      "Bintakay",
      "Bocboc",
      "Butansapa",
      "Candahon",
      "Capayang",
      "Danao",
      "Dulong Bayan (Poblacion)",
      "Gitnang Bayan (Poblacion)",
      "Guisian",
      "Hinadharan",
      "Hinanggayon",
      "Ino",
      "Janagdong",
      "Lamesa",
      "Laon",
      "Magapua",
      "Malayak",
      "Malusak",
      "Mampaitan",
      "Mangyan-Mababad",
      "Market Site (Poblacion)",
      "Mataas na Bayan",
      "Mendez",
      "Nangka I",
      "Nangka II",
      "Paye",
      "Pili",
      "Puting Buhangin",
      "Sayao",
      "Silangan",
      "Sumangga",
      "Tarug",
      "Villa Mendez (Poblacion)",
    ],
    "Santa Cruz": [
      "Alobo",
      "Angas",
      "Aturan",
      "Bagong Silang (Poblacion)",
      "Baguidbirin",
      "Baliis",
      "Balogo",
      "Banahaw (Poblacion)",
      "Bangcuangan",
      "Banogbog",
      "Biga",
      "Botilao",
      "Buyabod",
      "Dating Bayan",
      "Devilla",
      "Dolores",
      "Haguimit",
      "Hupi",
      "Ipil",
      "Jolo",
      "Kaganhao",
      "Kalangkang",
      "Kamandugan",
      "Kasily",
      "Kilo-Kilo",
      "KiÃ±aman",
      "Labo",
      "Lamesa",
      "Landy",
      "Lapu-Lapu",
      "Libjo",
      "Lipa",
      "Lusok",
      "Maharlika (Poblacion)",
      "Makina",
      "Maniwaya",
      "Manlibunan",
      "Masaguisi",
      "Masalukot",
      "Matalaba",
      "Mongpong",
      "Morales",
      "Napo",
      "Pag-Asa (Poblacion)",
      "Pantayin",
      "Polo",
      "Pulong-Parang",
      "Punong",
      "San Antonio",
      "San Isidro",
      "Tagum",
      "Tamayo",
      "Tambangan",
      "Tawiran",
      "Taytay",
    ],
    "Torrijos": [
      "Bangwayin",
      "Bayakbakin",
      "Bolo",
      "Bonliw",
      "Buangan",
      "Cabuyo",
      "Cagpo",
      "Dampulan",
      "Kay Duke",
      "Mabuhay",
      "Makawayan",
      "Malibago",
      "Malinao",
      "Marlangga",
      "Matuyatuya",
      "Nangka",
      "Pakaskasan",
      "Payanas",
      "Poblacion",
      "Poctoy",
      "Sibuyao",
      "Suha",
      "Talawan",
      "Tigwi",
    ],
  };

  final Map<String, String> _zipCodes = {
    "Boac": "4900",
    "Mogpog": "4901",
    "Santa Cruz": "4902",
    "Torrijos": "4903",
    "Buenavista": "4904",
    "Gasan": "4905",
  };

  // --- STATE VARIABLES ---
  bool _isLoadingData = true; // For initial fetch
  bool _showIntro = false;
  final PageController _introPageCtrl = PageController();
  int _introPage = 0;
  final bool _isSaving = false; // For saving state
  bool _isPaymentFirst = false;
  num _deliveryMinOrder = 0;
  Map<String, dynamic> _operatingHours = {};
  String _verificationDocumentType = 'business_permit_dti';

  // Rules based on Store Status
  String _storeStatus = 'new';
  bool _isReadOnly = false;
  bool _isStoreTypeLocked = false;
  String? _sellerId; // The actual primary key of the seller record if it exists

  // Dashboard counts
  int _itemCount = 0;
  int _rateCount = 0;
  int _unreadMessages = 0;
  int _newOrders = 0;

  // Image Management
  XFile? _coverFile;
  XFile? _logoFile;
  XFile? _permitFile;
  XFile? _gcashQrFile;
  XFile? _mayaQrFile;

  String? _coverUrl;
  String? _logoUrl;
  String? _permitUrl;
  String? _gcashQrUrl;
  String? _mayaQrUrl;

  Map<String, dynamic>? _coordinates;

  // --- STORE TYPE VARIABLES ---
  String? _selectedStoreType;
  final List<String> _availableStoreTypes = [
    "Restaurant",
    "Milk Tea / Coffee Shop",
    "Bakery",
    "Souvenirs",
    "Homemade Products",
    "Clothing and Apparel",
    "Seafoods",
    "Electronics and Accessories",
    "Flowers and Gifts",
    "General Store",
  ];

  // Available Tags for Seller Features
  final List<String> _availableTags = [
    "GCash",
    "Maya",
    "Cash on Delivery",
    "In-Store Pickup",
    "Delivery",
    "24/7",
    "Halal",
    "Vegan Friendly",
  ];
  final List<String> _selectedTags = [];

  // --- PAYMENT METHODS (multi-select) ---
  static const List<String> _availablePaymentMethods = [
    "GCash",
    "Maya",
    "Cash on Delivery",
    "In-Store Payment",
  ];
  final Set<String> _selectedPaymentMethods = <String>{};

  // --- FULFILLMENT OPTIONS (multi-select) ---
  static const List<String> _availableFulfillment = [
    "Delivery",
    "In-Store Pickup",
  ];
  final Set<String> _selectedFulfillment = <String>{};

  // --- UTILS ---
  final LoadingDialog _loadingDialog = LoadingDialog();

  @override
  void initState() {
    super.initState();
    _fetchSellerData();
  }

  @override
  void dispose() {
    _loadingDialog.dismiss(); // Clean up on dispose
    _storeNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _messengerCtrl.dispose();
    _gcashQrCtrl.dispose();
    _mayaQrCtrl.dispose();
    _streetCtrl.dispose();
    _introPageCtrl.dispose();
    super.dispose();
  }

  // --- CORE LOGIC: FETCH & APPLY RULES ---
  Future<void> _fetchSellerData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingData = false);
      return;
    }

    try {
      // Check if user already has a store
      final data = await _supabase
          .from('sellers')
          .select()
          .eq('seller_user_id', user.id)
          .maybeSingle();

      if (data != null) {
        _sellerId = data['seller_id'];
        _storeStatus = data['seller_store_status'] ?? 'in_review';
        final operatingHours = data['seller_operating_hours'];
        if (operatingHours is Map) {
          _operatingHours = Map<String, dynamic>.from(operatingHours);
        } else if (operatingHours is String && operatingHours.isNotEmpty) {
          _operatingHours = Map<String, dynamic>.from(
            jsonDecode(operatingHours) as Map,
          );
        }

        final rates = data['seller_delivery_rates'];
        if (rates is List) _rateCount = rates.length;

        // Apply Access Rules based on Status
        if (_storeStatus == 'in_review' || _storeStatus == 'banned') {
          _isReadOnly = true;
          _isStoreTypeLocked = true;
        } else if (_storeStatus == 'visible') {
          _isReadOnly = false;
          _isStoreTypeLocked = true; // Cannot modify type once approved
        }

        // Populate Form
        _storeNameCtrl.text = data['seller_store_name'] ?? '';
        _descriptionCtrl.text = data['seller_store_description'] ?? '';

        final addrData = data['seller_store_address'];
        if (addrData is Map<String, dynamic>) {
          _selectedProvince = addrData['province'] ?? "Marinduque";
          _selectedMunicipality = addrData['municipality'];
          _selectedBarangay = addrData['barangay'];
          _streetCtrl.text = addrData['street'] ?? '';
        } else if (addrData is String) {
          _streetCtrl.text = addrData;
        }

        _contactCtrl.text = data['seller_contact_number'] ?? '';
        _emailCtrl.text = data['seller_email_address'] ?? '';
        _messengerCtrl.text = data['seller_messenger_link'] ?? '';

        if (data['seller_store_type'] != null) {
          String dbType = data['seller_store_type'];
          if (!_availableStoreTypes.contains(dbType)) {
            _availableStoreTypes.add(dbType);
          }
          _selectedStoreType = dbType;
        }

        if (data['seller_payment_method'] != null) {
          final pm = data['seller_payment_method'];
          List<dynamic> list = [];
          if (pm is List) {
            list = pm;
          } else if (pm is String) {
            try {
              list = jsonDecode(pm);
            } catch (_) {}
          }
          _selectedPaymentMethods.addAll(list.map((e) => e.toString()));
        }

        if (data['seller_tags'] != null) {
          final tags = data['seller_tags'];
          if (tags is List) {
            _selectedTags.addAll(tags.map((e) => e.toString()));
          } else if (tags is String) {
            _selectedTags.addAll(List<String>.from(jsonDecode(tags)));
          }
        }

        if (data['seller_store_coordinates'] != null) {
          final coords = data['seller_store_coordinates'];
          if (coords is Map<String, dynamic>) {
            _coordinates = coords;
          } else if (coords is String) {
            _coordinates = jsonDecode(coords);
          }
        }

        _coverUrl = data['seller_cover_image'];
        _logoUrl = data['seller_logo'];
        _permitUrl = data['seller_business_permit_image'];

        if (data['seller_preferences'] != null) {
          final prefs = data['seller_preferences'];
          Map<String, dynamic> prefMap = {};
          if (prefs is Map<String, dynamic>) {
            prefMap = prefs;
          } else if (prefs is String) {
            prefMap = jsonDecode(prefs);
          }

          _isPaymentFirst = prefMap['is_payment_first'] ?? false;
          _gcashQrCtrl.text =
              prefMap['gcash_number'] ?? prefMap['gcash_qr'] ?? '';
          _mayaQrCtrl.text = prefMap['maya_number'] ?? prefMap['maya_qr'] ?? '';
          _gcashQrUrl = prefMap['gcash_qr_image'];
          _mayaQrUrl = prefMap['maya_qr_image'];
          final verificationType = prefMap['verification_document_type']
              ?.toString();
          if (verificationType == 'valid_id' ||
              verificationType == 'business_permit_dti') {
            _verificationDocumentType = verificationType!;
          }
          final ff = prefMap['fulfillment'];
          if (ff is List) {
            _selectedFulfillment.addAll(ff.map((e) => e.toString()));
          }
          if (_rateCount == 0) {
            _selectedFulfillment.remove("Delivery");
          }
          _deliveryMinOrder =
              (prefMap['delivery_min_order'] as num?)?.toDouble() ?? 0;
        }
      }
    } catch (e) {
      debugPrint("Error fetching seller profile: $e");
    } finally {
      if (mounted) {
        // Always show the intro carousel until the seller actually registers
        // a shop (i.e. moves out of the 'new' status).
        setState(() {
          _isLoadingData = false;
          _showIntro = _storeStatus == 'new';
        });
        if (_storeStatus == 'visible' && _sellerId != null) _fetchCounts();
      }
    }
  }

  Future<void> _fetchCounts() async {
    final sid = _sellerId;
    if (sid == null) return;
    try {
      final itemRes = await _supabase
          .from('store_items')
          .select('item_id')
          .eq('item_seller_id', sid)
          .count(CountOption.exact);
      final orderRes = await _supabase
          .from('orders')
          .select('order_id')
          .eq('order_seller_id', sid)
          .eq('order_status', 'placed')
          .count(CountOption.exact);
      final unread = await ChatService().sellerUnreadTotal(sid);
      await OnlineStoreWidgetService.update(
        newOrders: orderRes.count,
        messages: unread,
        storeName: _storeNameCtrl.text.trim().isEmpty
            ? 'Online Store'
            : _storeNameCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _itemCount = itemRes.count;
          _newOrders = orderRes.count;
          _unreadMessages = unread;
        });
      }
    } catch (e) {
      debugPrint("Count fetch error: $e");
    }
  }

  void _dismissIntro() {
    if (mounted) setState(() => _showIntro = false);
  }

  Future<void> _pickImage(String imageType) async {
    if (_isReadOnly) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (image != null) {
      setState(() {
        if (imageType == 'cover') _coverFile = image;
        if (imageType == 'logo') _logoFile = image;
        if (imageType == 'permit') _permitFile = image;
        if (imageType == 'gcash_qr') _gcashQrFile = image;
        if (imageType == 'maya_qr') _mayaQrFile = image;
      });
    }
  }

  ImageProvider? _getImageProvider(
    XFile? file,
    String? url,
    IconData placeholder,
  ) {
    if (file != null) {
      return kIsWeb ? NetworkImage(file.path) : FileImage(File(file.path));
    }
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }
    return null;
  }

  Future<void> _deleteFromBucket(String? url, String bucket) async {
    if (url == null || url.isEmpty) return;
    try {
      final segs = Uri.parse(url).pathSegments;
      final idx = segs.indexOf(bucket);
      if (idx < 0 || idx + 1 >= segs.length) return;
      final path = segs.sublist(idx + 1).join('/');
      await _supabase.storage.from(bucket).remove([path]);
    } catch (e) {
      debugPrint("Storage delete error [$bucket]: $e");
    }
  }

  Future<String?> _uploadToBucket(
    XFile file,
    String bucket,
    String prefix,
  ) async {
    try {
      final String fileExt = file.name.split('.').last;
      final String fileName =
          "${prefix}_${DateTime.now().millisecondsSinceEpoch}_${Utility().generateUniqueID()}.$fileExt";
      final Uint8List fileBytes = await file.readAsBytes();

      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      return _supabase.storage.from(bucket).getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Storage upload error [$bucket/$prefix]: $e");
      return null;
    }
  }

  Future<String?> _uploadToStorage(XFile file, String folder) async {
    try {
      final String fileExt = file.name.split('.').last;
      final String fileName =
          "$folder/${DateTime.now().millisecondsSinceEpoch}_${Utility().generateUniqueID()}.$fileExt";
      final Uint8List fileBytes = await file.readAsBytes();

      await _supabase.storage
          .from('seller_images')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      return _supabase.storage.from('seller_images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Storage upload error [$folder]: $e");
      return null;
    }
  }

  void _toggleTag(String tag) {
    if (_isReadOnly) return; // Prevent toggling if locked

    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _saveSellerProfile() async {
    FocusScope.of(context).unfocus();

    if (_storeNameCtrl.text.trim().isEmpty) {
      _showErrorSnackBar("Store Name is required.");
      return;
    }
    if (_selectedStoreType == null) {
      _showErrorSnackBar("Please select a Store Type.");
      return;
    }
    if (_permitFile == null && _permitUrl == null && _storeStatus == 'new') {
      _showErrorSnackBar(
        "${_verificationDocumentLabel()} is required for new applications.",
      );
      return;
    }
    if (_selectedFulfillment.isEmpty) {
      _showErrorSnackBar(
        "Please select at least one delivery option (Delivery or In-Store Pickup).",
      );
      return;
    }
    if (_selectedFulfillment.contains("Delivery") && _rateCount == 0) {
      _selectedFulfillment.remove("Delivery");
      _showErrorSnackBar(
        "Add at least one delivery rate before enabling Delivery.",
      );
      return;
    }
    if (_selectedPaymentMethods.isEmpty) {
      _showErrorSnackBar("Please select at least one payment method.");
      return;
    }
    final normalizedContact = SemaphoreSmsService.normalizePhilippineMobile(
      _contactCtrl.text,
    );
    if (_contactCtrl.text.trim().isEmpty) {
      _showErrorSnackBar("Contact Number is required for order SMS alerts.");
      return;
    }
    if (normalizedContact == null) {
      _showErrorSnackBar(
        "Enter a valid Philippine mobile number, like 09123456789.",
      );
      return;
    }
    _contactCtrl.text = normalizedContact;
    final bool gcashQrMissing =
        _gcashQrFile == null && (_gcashQrUrl == null || _gcashQrUrl!.isEmpty);
    final bool mayaQrMissing =
        _mayaQrFile == null && (_mayaQrUrl == null || _mayaQrUrl!.isEmpty);
    if (_isPaymentFirst) {
      if (gcashQrMissing && mayaQrMissing) {
        _showErrorSnackBar(
          "At least GCash or Maya QR is required when Payment First Policy is enabled.",
        );
        return;
      }
    } else {
      if (_selectedPaymentMethods.contains("GCash") && gcashQrMissing) {
        _showErrorSnackBar("GCash QR code is required when GCash is selected.");
        return;
      }
      if (_selectedPaymentMethods.contains("Maya") && mayaQrMissing) {
        _showErrorSnackBar("Maya QR code is required when Maya is selected.");
        return;
      }
    }

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    _loadingDialog.showLoadingDialog(context);
    _loadingDialog.updateTitle("Saving your store profile...");

    try {
      // Upload Images if new ones were picked (delete old first)
      if (_coverFile != null) {
        final oldUrl = _coverUrl;
        _coverUrl = await _uploadToStorage(_coverFile!, 'cover');
        if (_coverUrl != null && oldUrl != null && oldUrl != _coverUrl) {
          await _deleteFromBucket(oldUrl, 'seller_images');
        }
      }
      if (_logoFile != null) {
        final oldUrl = _logoUrl;
        _logoUrl = await _uploadToStorage(_logoFile!, 'logo');
        if (_logoUrl != null && oldUrl != null && oldUrl != _logoUrl) {
          await _deleteFromBucket(oldUrl, 'seller_images');
        }
      }
      if (_permitFile != null) {
        final oldUrl = _permitUrl;
        final documentFolder = _verificationDocumentType == 'valid_id'
            ? 'valid_id'
            : 'permit';
        _permitUrl = await _uploadToStorage(_permitFile!, documentFolder);
        if (_permitUrl != null && oldUrl != null && oldUrl != _permitUrl) {
          await _deleteFromBucket(oldUrl, 'seller_images');
        }
      }
      if (_gcashQrFile != null) {
        final oldUrl = _gcashQrUrl;
        _gcashQrUrl = await _uploadToBucket(
          _gcashQrFile!,
          'digital_wallet_qr',
          'gcash',
        );
        if (_gcashQrUrl != null && oldUrl != null && oldUrl != _gcashQrUrl) {
          await _deleteFromBucket(oldUrl, 'digital_wallet_qr');
        }
      }
      if (_mayaQrFile != null) {
        final oldUrl = _mayaQrUrl;
        _mayaQrUrl = await _uploadToBucket(
          _mayaQrFile!,
          'digital_wallet_qr',
          'maya',
        );
        if (_mayaQrUrl != null && oldUrl != null && oldUrl != _mayaQrUrl) {
          await _deleteFromBucket(oldUrl, 'digital_wallet_qr');
        }
      }

      // Delete QR images that were cleared by user
      if (_gcashQrFile == null && _gcashQrUrl == null) {
        final dbPrefs = await _supabase
            .from('sellers')
            .select('seller_preferences')
            .eq('seller_user_id', currentUser.id)
            .maybeSingle();
        final prev = dbPrefs?['seller_preferences'];
        if (prev is Map && prev['gcash_qr_image'] is String) {
          await _deleteFromBucket(prev['gcash_qr_image'], 'digital_wallet_qr');
        }
      }
      if (_mayaQrFile == null && _mayaQrUrl == null) {
        final dbPrefs = await _supabase
            .from('sellers')
            .select('seller_preferences')
            .eq('seller_user_id', currentUser.id)
            .maybeSingle();
        final prev = dbPrefs?['seller_preferences'];
        if (prev is Map && prev['maya_qr_image'] is String) {
          await _deleteFromBucket(prev['maya_qr_image'], 'digital_wallet_qr');
        }
      }

      final Map<String, dynamic> payload = {
        "seller_user_id": currentUser.id,
        "seller_store_name": _storeNameCtrl.text.trim(),
        "seller_store_description": _descriptionCtrl.text.trim(),
        "seller_store_address": {
          "province": _selectedProvince,
          "municipality": _selectedMunicipality,
          "barangay": _selectedBarangay,
          "street": _streetCtrl.text.trim(),
          "zip_code": _selectedMunicipality != null
              ? _zipCodes[_selectedMunicipality]
              : null,
        },
        "seller_contact_number": normalizedContact,
        "seller_email_address": _emailCtrl.text.trim(),
        "seller_messenger_link": _messengerCtrl.text.trim(),
        "seller_tags": _selectedTags,
        "seller_payment_method": _selectedPaymentMethods.toList(),
        "seller_cover_image": _coverUrl,
        "seller_logo": _logoUrl,
        "seller_business_permit_image": _permitUrl,
        "seller_operating_hours": _operatingHours,
        "seller_preferences": {
          "is_payment_first": _isPaymentFirst,
          "gcash_number": _gcashQrCtrl.text.trim(),
          "maya_number": _mayaQrCtrl.text.trim(),
          "gcash_qr_image": _gcashQrUrl,
          "maya_qr_image": _mayaQrUrl,
          "fulfillment": _selectedFulfillment.toList(),
          "delivery_min_order": _deliveryMinOrder,
          "verification_document_type": _verificationDocumentType,
        },
      };

      // Only update type if it's not locked
      if (!_isStoreTypeLocked) {
        payload["seller_store_type"] = _selectedStoreType;
      }

      // If it's a new store, ensure it goes to review status
      if (_storeStatus == 'new') {
        payload["seller_store_status"] = 'in_review';
        // You might generate a unique ID here if your DB doesn't auto-generate seller_id
        payload["seller_id"] = "STORE_${DateTime.now().millisecondsSinceEpoch}";
      } else if (_sellerId != null) {
        payload["seller_id"] = _sellerId; // Crucial for upsert matching
      }

      if (_coordinates != null) {
        payload["seller_store_coordinates"] = _coordinates;
      }

      await _supabase.from('sellers').upsert(payload);

      if (mounted) {
        _loadingDialog.dismiss();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Store details saved successfully!"),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        setState(() {
          if (_storeStatus == 'new') _storeStatus = 'in_review';
          // Ensure it locks down if it went into review
          if (_storeStatus == 'in_review') {
            _isReadOnly = true;
          }
          _isStoreTypeLocked = true;
        });
      }
    } catch (e) {
      _loadingDialog.dismiss();
      debugPrint("Error saving seller: $e");
      if (mounted) _showErrorSnackBar("Failed to save profile: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _hideShop() async {
    if (_sellerId == null || _storeStatus != 'visible') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hide shop?'),
        content: const Text(
          'Your shop and products will be removed from public marketplace listings. You can request visibility again through the marketplace administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide Shop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _supabase
        .from('sellers')
        .update({'seller_store_status': 'hidden'})
        .eq('seller_id', _sellerId!);
    if (mounted) {
      setState(() => _storeStatus = 'hidden');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your shop is now hidden from customers.'),
        ),
      );
    }
  }

  Future<void> _editOperatingHours() async {
    if (_sellerId == null) return;
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SellerOperatingHours(
          sellerId: _sellerId!,
          initialHours: _operatingHours,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _operatingHours = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Operating hours updated.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Store Profile",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'hide') _hideShop();
              if (value == 'hours') _editOperatingHours();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'hide',
                enabled: _storeStatus == 'visible',
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.visibility_off_outlined),
                  title: Text('Hide Shop'),
                ),
              ),
              PopupMenuItem(
                value: 'hours',
                enabled: _sellerId != null,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule_rounded),
                  title: Text('Operating Hours'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : _showIntro
          ? _buildIntroCarousel()
          : Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isDesktop = Responsive.isDesktop(context);
                    final bool isTablet = Responsive.isTablet(context);
                    final bool isWide = isDesktop || isTablet;
                    final double maxW = isDesktop
                        ? 1200
                        : (isTablet ? 900 : 640);
                    final EdgeInsets pad = EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                      vertical: isDesktop ? 32 : 20,
                    );

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxW),
                          child: Padding(
                            padding: pad,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildStatusBanner(),
                                _buildProhibitedItemsBanner(),

                                if (_storeStatus == 'visible') ...[
                                  _buildSectionHeader(
                                    "STORE MANAGEMENT",
                                    "Manage your products and view sales insights",
                                  ),
                                  _buildManagementModules(),
                                  const SizedBox(height: 32),
                                ],

                                if (isWide)
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _buildSectionHeader(
                                                "BRAND ASSETS",
                                                "Make your store stand out",
                                              ),
                                              _buildImagePickers(),
                                              const SizedBox(height: 28),
                                              _buildSectionHeader(
                                                "VERIFICATION",
                                                "Upload legal documents to verify your business",
                                              ),
                                              _buildPermitUploadCard(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 7,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _buildSectionHeader(
                                                "STORE DETAILS",
                                                "General information about your business",
                                              ),
                                              _buildBasicInfoCard(),
                                              const SizedBox(height: 28),
                                              _buildSectionHeader(
                                                "FEATURES",
                                                "Select tags that apply to your store",
                                              ),
                                              _buildTagsCard(),
                                              const SizedBox(height: 28),
                                              _buildSectionHeader(
                                                "PAYMENT SETTINGS",
                                                "Configure how you want to be paid",
                                              ),
                                              _buildPaymentSettingsCard(),
                                              const SizedBox(height: 28),
                                              _buildSubmitButton(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildSectionHeader(
                                        "BRAND ASSETS",
                                        "Make your store stand out",
                                      ),
                                      _buildImagePickers(),
                                      const SizedBox(height: 28),
                                      _buildSectionHeader(
                                        "STORE DETAILS",
                                        "General information about your business",
                                      ),
                                      _buildBasicInfoCard(),
                                      const SizedBox(height: 28),
                                      _buildSectionHeader(
                                        "FEATURES",
                                        "Select tags that apply to your store",
                                      ),
                                      _buildTagsCard(),
                                      const SizedBox(height: 28),
                                      _buildSectionHeader(
                                        "PAYMENT SETTINGS",
                                        "Configure how you want to be paid",
                                      ),
                                      _buildPaymentSettingsCard(),
                                      const SizedBox(height: 28),
                                      _buildSectionHeader(
                                        "VERIFICATION",
                                        "Upload legal documents to verify your business",
                                      ),
                                      _buildPermitUploadCard(),
                                      const SizedBox(height: 36),
                                      _buildSubmitButton(),
                                      if (_sellerId != null) ...[
                                        const SizedBox(height: 28),
                                        _buildDangerZone(),
                                      ],
                                    ],
                                  ),

                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                if (_isSaving)
                  Container(
                    color: Colors.white.withValues(alpha: 0.5),
                    child: Center(
                      child: CircularProgressIndicator(color: primaryBlue),
                    ),
                  ),
              ],
            ),
    );
  }

  // =========================================================================
  // UI BUILDERS
  // =========================================================================

  Widget _buildProhibitedItemsBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dangerColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dangerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: dangerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.gpp_bad_rounded, color: dangerColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Prohibited Items",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: dangerColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Selling illegal or regulated items is strictly prohibited â€” including drugs, weapons and guns, "
                  "vapes and e-cigarettes, alcohol to minors, counterfeit goods, and other unlawful products. "
                  "Violations will result in store suspension and may be reported to authorities.",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textSecondary,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_storeStatus == 'new') return const SizedBox.shrink();

    Color bannerColor;
    IconData bannerIcon;
    String bannerTitle;
    String bannerMessage;

    switch (_storeStatus) {
      case 'in_review':
        bannerColor = warningColor;
        bannerIcon = Icons.hourglass_empty_rounded;
        bannerTitle = "Application in Review";
        bannerMessage =
            "Your store details and business permit are currently being reviewed by admins. Editing is disabled until a decision is made.";
        break;
      case 'banned':
        bannerColor = dangerColor;
        bannerIcon = Icons.gavel_rounded;
        bannerTitle = "Store Suspended";
        bannerMessage =
            "Your store has been suspended. Please contact support for more information.";
        break;
      case 'visible':
        bannerColor = successColor;
        bannerIcon = Icons.check_circle_outline_rounded;
        bannerTitle = "Store is Live";
        bannerMessage =
            "Your store is verified and currently visible to customers. You can update your details below.";
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(bannerIcon, color: bannerColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerTitle,
                  style: TextStyle(
                    color: bannerColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bannerMessage,
                  style: TextStyle(
                    color: bannerColor.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementModules() {
    final modules = <_ManagementModule>[
      _ManagementModule(
        title: "Analytics",
        subtitle: "Traffic, sales and products",
        icon: Icons.insights_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () {
          if (_sellerId == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreAnalytics(
                sellerId: _sellerId!,
                storeName: _storeNameCtrl.text.trim(),
              ),
            ),
          );
        },
      ),
      _ManagementModule(
        title: "Vouchers",
        subtitle: "Coming soon",
        icon: Icons.local_offer_rounded,
        color: const Color(0xFFDB2777),
        disabled: true,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vouchers is coming soon."),
            duration: Duration(seconds: 2),
          ),
        ),
      ),
      _ManagementModule(
        title: "Manage Items",
        subtitle: "$_itemCount ${_itemCount == 1 ? 'item' : 'items'}",
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF10B981),
        onTap: () async {
          if (_sellerId == null) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreItemList(sellerId: _sellerId!),
            ),
          );
          _fetchCounts();
        },
      ),
      _ManagementModule(
        title: "Delivery Rates",
        subtitle: "$_rateCount ${_rateCount == 1 ? 'rate' : 'rates'}",
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFFEA580C),
        onTap: () async {
          if (_sellerId == null) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeliveryRateList(sellerId: _sellerId!),
            ),
          );
          _fetchSellerData();
        },
      ),
      _ManagementModule(
        title: "Messages",
        subtitle: _unreadMessages > 0
            ? "$_unreadMessages new"
            : "Chat with buyers",
        icon: Icons.forum_rounded,
        color: const Color(0xFFEE4D2D),
        badge: _unreadMessages,
        onTap: () async {
          if (_sellerId == null) return;
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatInbox(sellerId: _sellerId!)),
          );
          _fetchCounts();
        },
      ),
      _ManagementModule(
        title: "Orders",
        subtitle: _newOrders > 0 ? "$_newOrders new" : "Customer orders",
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF2563EB),
        badge: _newOrders,
        onTap: () async {
          if (_sellerId == null) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellerOrders(sellerId: _sellerId!),
            ),
          );
          _fetchCounts();
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Pick column count so cards stay tappable & evenly aligned.
        final int cols = w < 340
            ? 1
            : w < 560
            ? 2
            : w < 900
            ? 4
            : 4;
        const double spacing = 12;
        // Compute aspect ratio so the card always fits its content without overflow.
        final double cardWidth = (w - spacing * (cols - 1)) / cols;
        final double aspect = cols == 1 ? 3.4 : 1.05;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspect,
          ),
          itemBuilder: (_, i) {
            final m = modules[i];
            return _buildDashboardCard(
              title: m.title,
              subtitle: m.subtitle,
              icon: m.icon,
              color: m.color,
              onTap: m.onTap,
              horizontal: cols == 1,
              compact: cardWidth < 170,
              badge: m.badge,
              disabled: m.disabled,
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool horizontal = false,
    bool compact = false,
    int badge = 0,
    bool disabled = false,
  }) {
    final double iconBoxPad = compact ? 8 : 10;
    final double iconSize = compact ? 20 : 24;
    final double titleSize = compact ? 13 : 14.5;
    final double subSize = compact ? 10.5 : 11.5;

    Widget iconBox = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(iconBoxPad),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: iconSize),
        ),
        if (badge > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: dangerColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                badge > 99 ? "99+" : "$badge",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );

    Widget textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: primaryDark,
            fontSize: titleSize,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textSecondary,
            fontSize: subSize,
          ),
        ),
      ],
    );

    Widget body;
    if (horizontal) {
      body = Row(
        children: [
          iconBox,
          const SizedBox(width: 14),
          Expanded(child: textBlock),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: textSecondary.withValues(alpha: 0.5),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [iconBox, textBlock],
      );
    }

    final card = Container(
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: primaryDark.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 14),
            child: body,
          ),
        ),
      ),
    );

    if (disabled) {
      return Opacity(opacity: 0.55, child: card);
    }
    return card;
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickers() {
    final coverProvider = _getImageProvider(
      _coverFile,
      _coverUrl,
      Icons.add_photo_alternate_rounded,
    );
    final logoProvider = _getImageProvider(
      _logoFile,
      _logoUrl,
      Icons.storefront_rounded,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Cover Photo",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pickImage('cover'),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isReadOnly ? bgColor.withValues(alpha: 0.5) : bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 2),
                image: coverProvider != null
                    ? DecorationImage(image: coverProvider, fit: BoxFit.cover)
                    : null,
              ),
              child: coverProvider == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          color: textSecondary.withValues(alpha: 0.5),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Upload Cover",
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            "Store Logo",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pickImage('logo'),
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: _isReadOnly ? bgColor.withValues(alpha: 0.5) : bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: cardBorder, width: 2),
                image: logoProvider != null
                    ? DecorationImage(image: logoProvider, fit: BoxFit.cover)
                    : null,
              ),
              child: logoProvider == null
                  ? Icon(
                      Icons.storefront_rounded,
                      color: textSecondary.withValues(alpha: 0.5),
                      size: 28,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: textSecondary, size: 20),
      filled: true,
      fillColor: (_isReadOnly || _isStoreTypeLocked)
          ? cardBorder.withValues(alpha: 0.3)
          : bgColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cardBorder),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cardBorder.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryBlue, width: 1.5),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _storeNameCtrl,
            label: "Store Name",
            icon: Icons.store_mall_directory_outlined,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _selectedStoreType,
            isExpanded: true,
            hint: Text(
              "Select Store Type",
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
            items: _availableStoreTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(
                  type,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primaryDark,
                    fontSize: 15,
                  ),
                ),
              );
            }).toList(),
            // Disable dropdown if Read Only OR if Store Type is locked (i.e. already verified)
            onChanged: (_isReadOnly || _isStoreTypeLocked)
                ? null
                : (val) {
                    setState(() {
                      _selectedStoreType = val;
                    });
                  },
            decoration: _inputDecoration("Store Type", Icons.category_outlined),
          ),
          if (_isStoreTypeLocked)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 12,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Store type cannot be changed after creation.",
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          _buildTextField(
            controller: _descriptionCtrl,
            label: "Description",
            icon: Icons.subject_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedProvince,
            hint: const Text("Province"),
            items: _provinces
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (_isReadOnly || _storeStatus == 'visible')
                ? null
                : (val) => setState(() {
                    _selectedProvince = val;
                    _selectedMunicipality = null;
                    _selectedBarangay = null;
                  }),
            decoration: _inputDecoration("Province", Icons.map_outlined),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedMunicipality,
            hint: const Text("Municipality"),
            items: (_municipalities[_selectedProvince] ?? [])
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (_isReadOnly || _storeStatus == 'visible')
                ? null
                : (val) => setState(() {
                    _selectedMunicipality = val;
                    _selectedBarangay = null;
                  }),
            decoration: _inputDecoration(
              "Municipality",
              Icons.location_city_outlined,
            ),
          ),
          if (_storeStatus == 'visible') ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 12,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Province and Municipality cannot be changed once your store is visible.",
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedBarangay,
            hint: const Text("Barangay"),
            items: (_barangays[_selectedMunicipality] ?? [])
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: _isReadOnly
                ? null
                : (val) => setState(() => _selectedBarangay = val),
            decoration: _inputDecoration("Barangay", Icons.home_outlined),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _streetCtrl,
            label: "Street/Purok (Optional)",
            icon: Icons.streetview_outlined,
          ),
          const SizedBox(height: 16),

          Builder(
            builder: (_) {
              final double? lat = (_coordinates?['latitude'] as num?)
                  ?.toDouble();
              final double? lng = (_coordinates?['longitude'] as num?)
                  ?.toDouble();
              final bool hasCoords = lat != null && lng != null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isReadOnly
                          ? null
                          : () async {
                              final picked = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapLocationPicker(
                                    initialLocation: hasCoords
                                        ? LatLng(lat, lng)
                                        : null,
                                  ),
                                ),
                              );
                              if (picked is LatLng) {
                                setState(() {
                                  _coordinates = {
                                    "latitude": picked.latitude,
                                    "longitude": picked.longitude,
                                  };
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Coordinates pinned!"),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: Icon(
                        Icons.pin_drop_rounded,
                        color: _isReadOnly ? textSecondary : primaryBlue,
                        size: 18,
                      ),
                      label: Text(
                        hasCoords ? "Change Location" : "Pin Location on Map",
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isReadOnly
                            ? textSecondary
                            : primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: _isReadOnly
                              ? cardBorder
                              : primaryBlue.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (hasCoords) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryBlue.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            color: primaryBlue,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Selected Coordinates",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: primaryBlue,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryDark,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isReadOnly)
                            InkWell(
                              onTap: () => setState(() => _coordinates = null),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const Divider(height: 32),

          const Text(
            "Contact Information",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _contactCtrl,
            label: "Contact Number",
            icon: Icons.phone_rounded,
            hintText: "09123456789",
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailCtrl,
            label: "Email Address",
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _messengerCtrl,
            label: "Messenger Link (Optional)",
            icon: Icons.message_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Delivery Options",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            "Select how customers can receive their orders.",
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableFulfillment.map((f) {
              final selected = _selectedFulfillment.contains(f);
              final deliveryDisabled = f == "Delivery" && _rateCount == 0;
              final disabled = _isReadOnly || deliveryDisabled;
              return FilterChip(
                label: Text(
                  f,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: disabled
                        ? textSecondary
                        : (selected ? Colors.white : primaryDark),
                    fontSize: 12.5,
                  ),
                ),
                selected: selected,
                showCheckmark: false,
                selectedColor: primaryBlue,
                backgroundColor: const Color(0xFFF1F5F9),
                disabledColor: const Color(0xFFE5E7EB),
                side: BorderSide(color: selected ? primaryBlue : cardBorder),
                avatar: Icon(
                  f == "Delivery"
                      ? Icons.local_shipping_rounded
                      : Icons.storefront_rounded,
                  size: 16,
                  color: disabled
                      ? textSecondary
                      : (selected ? Colors.white : primaryDark),
                ),
                onSelected: disabled
                    ? null
                    : (val) {
                        setState(() {
                          if (val) {
                            _selectedFulfillment.add(f);
                          } else {
                            _selectedFulfillment.remove(f);
                          }
                        });
                      },
              );
            }).toList(),
          ),
          if (_rateCount == 0) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: warningColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    "Add at least one delivery rate to enable Delivery.",
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Payment First Policy",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              "Require customers to pay before order processing.",
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            value: _isPaymentFirst,
            activeThumbColor: primaryBlue,
            onChanged: _isReadOnly
                ? null
                : (val) => setState(() {
                    _isPaymentFirst = val;
                    if (val) {
                      _selectedPaymentMethods.remove("Cash on Delivery");
                      _selectedPaymentMethods.remove("In-Store Payment");
                    }
                  }),
          ),
          const Divider(height: 32),
          const Text(
            "Accepted Payment Methods",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            "Select all that you accept. GCash/Maya require a QR code below.",
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availablePaymentMethods.map((m) {
              final selected = _selectedPaymentMethods.contains(m);
              final bool disabled =
                  _isReadOnly ||
                  (_isPaymentFirst &&
                      (m == "Cash on Delivery" || m == "In-Store Payment"));
              return FilterChip(
                label: Text(
                  m,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: disabled
                        ? textSecondary
                        : (selected ? Colors.white : primaryDark),
                    fontSize: 12.5,
                  ),
                ),
                selected: selected,
                showCheckmark: false,
                selectedColor: primaryBlue,
                backgroundColor: const Color(0xFFF1F5F9),
                disabledColor: const Color(0xFFE5E7EB),
                side: BorderSide(color: selected ? primaryBlue : cardBorder),
                onSelected: disabled
                    ? null
                    : (val) {
                        setState(() {
                          if (val) {
                            _selectedPaymentMethods.add(m);
                          } else {
                            _selectedPaymentMethods.remove(m);
                          }
                        });
                      },
              );
            }).toList(),
          ),
          const Divider(height: 32),
          const Text(
            "Digital Wallets (GCash/Maya)",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _gcashQrCtrl,
            label: "GCash Number (Optional)",
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 12),
          _buildQrUploader(
            label: "GCash QR Code",
            file: _gcashQrFile,
            url: _gcashQrUrl,
            onPick: () => _pickImage('gcash_qr'),
            onRemove: () => setState(() {
              _gcashQrFile = null;
              _gcashQrUrl = null;
            }),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _mayaQrCtrl,
            label: "Maya Number (Optional)",
            icon: Icons.wallet_outlined,
          ),
          const SizedBox(height: 12),
          _buildQrUploader(
            label: "Maya QR Code",
            file: _mayaQrFile,
            url: _mayaQrUrl,
            onPick: () => _pickImage('maya_qr'),
            onRemove: () => setState(() {
              _mayaQrFile = null;
              _mayaQrUrl = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQrUploader({
    required String label,
    required XFile? file,
    required String? url,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final provider = _getImageProvider(file, url, Icons.qr_code_2_rounded);
    final bool hasImage = provider != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isReadOnly ? null : onPick,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: _isReadOnly ? bgColor.withValues(alpha: 0.5) : bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder, width: 1.5),
              image: hasImage
                  ? DecorationImage(image: provider, fit: BoxFit.cover)
                  : null,
            ),
            child: hasImage
                ? null
                : Icon(
                    Icons.qr_code_2_rounded,
                    color: textSecondary.withValues(alpha: 0.6),
                    size: 32,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasImage ? "Tap image to change" : "Upload your QR code image",
                style: TextStyle(fontSize: 11.5, color: textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!_isReadOnly)
                    OutlinedButton.icon(
                      onPressed: onPick,
                      icon: Icon(
                        hasImage
                            ? Icons.swap_horiz_rounded
                            : Icons.upload_rounded,
                        size: 14,
                        color: primaryBlue,
                      ),
                      label: Text(
                        hasImage ? "Replace" : "Upload",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: primaryBlue,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 30),
                        side: BorderSide(
                          color: primaryBlue.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  if (hasImage && !_isReadOnly) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onRemove,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 14,
                        color: dangerColor,
                      ),
                      label: Text(
                        "Remove",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: dangerColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 30),
                        side: BorderSide(
                          color: dangerColor.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 12,
        children: _availableTags.map((tag) {
          final isSelected = _selectedTags.contains(tag);
          return FilterChip(
            label: Text(
              tag,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isSelected ? Colors.white : primaryDark,
              ),
            ),
            selected: isSelected,
            onSelected: _isReadOnly ? null : (_) => _toggleTag(tag),
            backgroundColor: _isReadOnly
                ? bgColor.withValues(alpha: 0.5)
                : bgColor,
            selectedColor: _isReadOnly ? textSecondary : primaryDark,
            checkmarkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected
                    ? (_isReadOnly ? textSecondary : primaryDark)
                    : cardBorder,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _verificationDocumentLabel() {
    return _verificationDocumentType == 'valid_id'
        ? 'Valid ID'
        : 'Business Permit / DTI';
  }

  String _verificationDocumentDescription() {
    return _verificationDocumentType == 'valid_id'
        ? 'Upload a clear image of one government-issued ID. This helps admins verify the seller identity before approval.'
        : 'Upload a clear image of your official business permit or DTI registration. This helps admins verify the legitimacy of your store.';
  }

  IconData _verificationDocumentIcon() {
    return _verificationDocumentType == 'valid_id'
        ? Icons.badge_rounded
        : Icons.assignment_turned_in_rounded;
  }

  Widget _buildVerificationChoice({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _verificationDocumentType == value;
    final Color accent = isSelected ? primaryBlue : textSecondary;

    return InkWell(
      onTap: _isReadOnly
          ? null
          : () => setState(() => _verificationDocumentType = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryBlue.withValues(alpha: 0.08)
              : bgColor.withValues(alpha: _isReadOnly ? 0.45 : 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryBlue : cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? primaryBlue : textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermitUploadCard() {
    final permitProvider = _getImageProvider(
      _permitFile,
      _permitUrl,
      _verificationDocumentIcon(),
    );
    final documentLabel = _verificationDocumentLabel();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: primaryBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Verification Document",
                  style: TextStyle(
                    color: primaryDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Choose the document you want to submit for store verification.",
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildVerificationChoice(
            value: 'business_permit_dti',
            title: 'Business Permit / DTI',
            subtitle: 'Recommended for registered stores and businesses.',
            icon: Icons.assignment_turned_in_rounded,
          ),
          const SizedBox(height: 10),
          _buildVerificationChoice(
            value: 'valid_id',
            title: 'Valid ID',
            subtitle: 'Use this if you do not have a permit yet.',
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 20),
          Text(
            documentLabel,
            style: TextStyle(
              color: primaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _verificationDocumentDescription(),
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isReadOnly ? null : () => _pickImage('permit'),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isReadOnly ? bgColor.withValues(alpha: 0.5) : bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 2),
                image: permitProvider != null
                    ? DecorationImage(
                        image: permitProvider,
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
              child: permitProvider == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _verificationDocumentIcon(),
                          color: textSecondary.withValues(alpha: 0.5),
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Tap to Upload $documentLabel",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "JPG, PNG (Max 5MB)",
                          style: TextStyle(
                            color: textSecondary.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      enabled: !_isReadOnly, // Disables text input if in review
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: textSecondary, size: 20)
            : null,
        filled: true,
        fillColor: _isReadOnly ? cardBorder.withValues(alpha: 0.3) : bgColor,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorder.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    const Color danger = Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dangerous_rounded, color: danger, size: 18),
              const SizedBox(width: 8),
              Text(
                "DANGER ZONE",
                style: TextStyle(
                  color: danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Permanently delete your shop, its products, delivery rates, payment QR codes, and order history. This cannot be undone.",
            style: TextStyle(
              color: textSecondary,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _openDeleteShopSheet,
              icon: Icon(Icons.delete_forever_rounded, color: danger),
              label: Text(
                "Delete Shop",
                style: TextStyle(color: danger, fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: danger.withValues(alpha: 0.6),
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDeleteShopSheet() {
    if (_sellerId == null) return;
    DeleteShopConfirmation.show(
      context,
      shopName: _storeNameCtrl.text.trim(),
      onConfirmed: _deleteShop,
    );
  }

  Future<void> _deleteShop() async {
    final id = _sellerId;
    if (id == null) return;
    _loadingDialog.showLoadingDialog(context);
    _loadingDialog.updateTitle("Deleting shop...");
    try {
      // Best-effort cascade: remove dependent rows first.
      try {
        await _supabase.from('store_items').delete().eq('item_seller_id', id);
      } catch (_) {}
      try {
        await _supabase
            .from('delivery_rates')
            .delete()
            .eq('rate_seller_id', id);
      } catch (_) {}
      await _supabase.from('sellers').delete().eq('seller_id', id);

      _loadingDialog.dismiss();
      if (mounted) {
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.success,
          "Shop deleted.",
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _loadingDialog.dismiss();
      if (mounted) {
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.failed,
          "Delete failed: $e",
        );
      }
      rethrow;
    }
  }

  Widget _buildSubmitButton() {
    // If the store is in review or suspended, show a disabled button outlining the status.
    if (_storeStatus == 'in_review' || _storeStatus == 'banned') {
      return SizedBox(
        height: 56,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            disabledForegroundColor: textSecondary,
            side: BorderSide(color: cardBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            _storeStatus == 'in_review'
                ? "STORE IS UNDER REVIEW"
                : "STORE IS SUSPENDED",
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // If new or visible, show the active save/submit button.
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSellerProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _storeStatus == 'visible' ? "SAVE CHANGES" : "SUBMIT STORE DETAILS",
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INTRO CAROUSEL (shown once for brand-new sellers)
  // ---------------------------------------------------------------------------

  Widget _buildIntroCarousel() {
    final pages = <_IntroSlide>[
      const _IntroSlide(
        icon: Icons.storefront_rounded,
        tagline: "AGA MARKETPLACE",
        title: "Sell Online for FREE",
        body:
            "Set up a digital storefront for your Marinduque business at zero cost. No subscriptions, no listing fees â€” ever.",
        accent: Color(0xFF10B981),
      ),
      const _IntroSlide(
        icon: Icons.volunteer_activism_rounded,
        tagline: "SUPPORTING LOCAL",
        title: "Built for MarinduqueÃ±os",
        body:
            "AGA was created to help local entrepreneurs reach buyers across the island. Every order helps a Marinduque family.",
        accent: Color(0xFF2563EB),
      ),
      const _IntroSlide(
        icon: Icons.shopping_bag_rounded,
        tagline: "EASY TO MANAGE",
        title: "Products, Orders & Payments",
        body:
            "List products with photos, set delivery rates, accept GCash, Maya, COD or In-Store Payment, and track orders in real time.",
        accent: Color(0xFFEA580C),
      ),
      const _IntroSlide(
        icon: Icons.rocket_launch_rounded,
        tagline: "GET STARTED",
        title: "Ready to open your shop?",
        body:
            "Fill in your store details and upload a Business Permit, DTI registration, or Valid ID. Our team verifies new shops within 1-3 business days.",
        accent: Color(0xFF8B5CF6),
      ),
    ];

    final accent = pages[_introPage].accent;
    final isLast = _introPage == pages.length - 1;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                // Top bar with Skip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.celebration_rounded,
                            color: accent,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "FREE FOREVER",
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!isLast)
                      TextButton(
                        onPressed: _dismissIntro,
                        child: Text(
                          "Skip",
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView.builder(
                    controller: _introPageCtrl,
                    onPageChanged: (i) => setState(() => _introPage = i),
                    itemCount: pages.length,
                    itemBuilder: (_, i) => _buildIntroSlide(pages[i]),
                  ),
                ),
                const SizedBox(height: 16),
                // Page dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pages.length, (i) {
                    final active = i == _introPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? accent : cardBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Bottom action row
                Row(
                  children: [
                    if (_introPage > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _introPageCtrl.previousPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textSecondary,
                            side: BorderSide(color: cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text(
                            "Back",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    if (_introPage > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: isLast
                            ? _dismissIntro
                            : () => _introPageCtrl.nextPage(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          isLast
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isLast ? "Start Selling" : "Next",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSlide(_IntroSlide slide) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: slide.accent.withValues(alpha: 0.12),
            border: Border.all(
              color: slide.accent.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(slide.icon, color: slide.accent, size: 56),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: slide.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            slide.tagline,
            style: TextStyle(
              color: slide.accent,
              fontWeight: FontWeight.w900,
              fontSize: 10.5,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            slide.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroSlide {
  final IconData icon;
  final String tagline;
  final String title;
  final String body;
  final Color accent;
  const _IntroSlide({
    required this.icon,
    required this.tagline,
    required this.title,
    required this.body,
    required this.accent,
  });
}

class _ManagementModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  final bool disabled;
  const _ManagementModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge = 0,
    this.disabled = false,
  });
}
