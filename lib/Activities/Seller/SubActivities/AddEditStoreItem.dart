import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'package:gasan_port_tracker/Utility/MarketCategories.dart';

import '../../../Dialogs/LoadingDialog.dart';

class AddEditStoreItem extends StatefulWidget {
  final String sellerId;
  final Map<String, dynamic>? existingItem; // Pass null for Add, pass data for Edit

  const AddEditStoreItem({super.key, required this.sellerId, this.existingItem});

  @override
  State<AddEditStoreItem> createState() => _AddEditStoreItemState();
}

class _AddEditStoreItemState extends State<AddEditStoreItem> {
  final _supabase = Supabase.instance.client;

  // --- THEME COLORS ---
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color primaryBlue = const Color(0xFF2563EB);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color successColor = const Color(0xFF10B981);
  final Color dangerColor = const Color(0xFFEF4444);

  // --- CONTROLLERS ---
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();

  // --- STATE VARIABLES ---
  bool _isAvailable = true;
  bool _stockNotApplicable = false;
  String? _selectedType;
  String? _selectedCategory;
  final LoadingDialog _loadingDialog = LoadingDialog();

  // Image Management (Max 2)
  List<String> _existingImages = [];
  List<XFile> _newImages = []; // Newly picked images as XFiles

  // Variations: parallel lists of controllers
  final List<TextEditingController> _varLabelCtrls = [];
  final List<TextEditingController> _varPriceCtrls = [];
  final List<TextEditingController> _varStockCtrls = [];

  final List<String> _itemTypes = [
    "food", "service", "material", "apparel", "electronics", "other"
  ];

  @override
  void initState() {
    super.initState();
    _populateExistingData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _categoryCtrl.dispose();
    for (final c in _varLabelCtrls) { c.dispose(); }
    for (final c in _varPriceCtrls) { c.dispose(); }
    for (final c in _varStockCtrls) { c.dispose(); }
    super.dispose();
  }

  void _populateExistingData() {
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _nameCtrl.text = item['item_name'] ?? '';
      _descCtrl.text = item['item_description'] ?? '';
      _priceCtrl.text = item['item_price']?.toString() ?? '';
      _stockCtrl.text = item['item_stocks']?.toString() ?? '';
      _stockNotApplicable = (num.tryParse(item['item_stocks']?.toString() ?? '') ?? 0) < 0;
      if (_stockNotApplicable) _stockCtrl.text = '';
      _categoryCtrl.text = item['item_category'] ?? '';
      _isAvailable = item['item_available'] ?? true;

      String? type = item['item_type'];
      if (type != null && _itemTypes.contains(type.toLowerCase())) {
        _selectedType = type.toLowerCase();
      } else if (type != null) {
        _itemTypes.add(type);
        _selectedType = type;
      }

      String? cat = item['item_category'];
      if (cat != null && MarketCategories.labels.contains(cat)) {
        _selectedCategory = cat;
      }

      // Parse existing images
      final rawImages = item['item_images'];
      if (rawImages != null) {
        if (rawImages is List) {
          _existingImages = rawImages.map((e) => e.toString()).toList();
        }
      }

      // Parse existing variations
      final rawVars = item['item_variations'];
      if (rawVars is List) {
        for (final v in rawVars) {
          if (v is Map) {
            _varLabelCtrls.add(TextEditingController(text: v['label']?.toString() ?? ''));
            _varPriceCtrls.add(TextEditingController(text: v['price']?.toString() ?? '0'));
            _varStockCtrls.add(TextEditingController(text: v['stock']?.toString() ?? '0'));
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _collectVariations() {
    final list = <Map<String, dynamic>>[];
    for (int i = 0; i < _varLabelCtrls.length; i++) {
      final label = _varLabelCtrls[i].text.trim();
      if (label.isEmpty) continue;
      list.add({
        'label': label,
        'price': num.tryParse(_varPriceCtrls[i].text.trim()) ?? 0,
        'stock': num.tryParse(_varStockCtrls[i].text.trim()) ?? 0,
      });
    }
    return list;
  }

  void _addVariation() {
    setState(() {
      _varLabelCtrls.add(TextEditingController());
      _varPriceCtrls.add(TextEditingController(text: '0'));
      _varStockCtrls.add(TextEditingController(text: '0'));
    });
  }

  void _removeVariation(int i) {
    setState(() {
      _varLabelCtrls.removeAt(i).dispose();
      _varPriceCtrls.removeAt(i).dispose();
      _varStockCtrls.removeAt(i).dispose();
    });
  }

  Future<void> _pickImage() async {
    if ((_existingImages.length + _newImages.length) >= 2) {
      _showSnackBar("Maximum of 2 images allowed.", isError: true);
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 700,
      maxHeight: 700,
      imageQuality: 60,
    );

    if (image != null) {
      setState(() {
        _newImages.add(image);
      });
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<String?> _uploadToStorage(XFile file) async {
    try {
      final String fileExt = file.name.split('.').last;
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}_${Utility().generateUniqueID()}.$fileExt";
      final Uint8List fileBytes = await file.readAsBytes();

      await _supabase.storage.from('store_item_images').uploadBinary(
        fileName,
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );

      return _supabase.storage.from('store_item_images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Storage upload error [store_item_images]: $e");
      return null;
    }
  }

  num? _zipForMunicipality(String? municipality) {
    if (municipality == null) return null;
    const zips = {
      "Boac": 4900,
      "Mogpog": 4901,
      "Santa Cruz": 4902,
      "Sta. Cruz": 4902,
      "Torrijos": 4903,
      "Buenavista": 4904,
      "Gasan": 4905,
    };
    return zips[municipality.trim()];
  }

  Future<void> _saveItem() async {
    FocusScope.of(context).unfocus();

    // Validation
    if (_nameCtrl.text.trim().isEmpty) return _showSnackBar("Item Name is required", isError: true);
    final bool hasVariations = _collectVariations().isNotEmpty;
    if (_priceCtrl.text.trim().isEmpty && !hasVariations) {
      return _showSnackBar("Set a price or add at least one variation", isError: true);
    }
    if (!_stockNotApplicable && !hasVariations && _stockCtrl.text.trim().isEmpty) {
      return _showSnackBar("Stock count is required", isError: true);
    }
    if (_selectedType == null) return _showSnackBar("Please select an Item Type", isError: true);
    if (_categoryCtrl.text.trim().isEmpty) return _showSnackBar("Category is required", isError: true);

    _loadingDialog.showLoadingDialog(context);
    _loadingDialog.updateTitle("Saving item details...");

    try {
      // 1. Handle Images
      List<String> finalImageUrls = List.from(_existingImages);
      for (var file in _newImages) {
        String? url = await _uploadToStorage(file);
        if (url != null) finalImageUrls.add(url);
      }

      // Fetch seller's municipal zip code
      num? municipalOrigin;
      try {
        final sellerRow = await _supabase
            .from('sellers')
            .select('seller_store_address')
            .eq('seller_id', widget.sellerId)
            .maybeSingle();
        final addr = sellerRow?['seller_store_address'];
        if (addr is Map) {
          final zip = addr['zip_code'];
          if (zip != null && zip.toString().trim().isNotEmpty) {
            municipalOrigin = num.tryParse(zip.toString().trim());
          }
          // Fallback: derive zip from municipality name if zip_code missing.
          municipalOrigin ??= _zipForMunicipality(addr['municipality']?.toString());
        }
      } catch (e) {
        debugPrint("Fetch seller zip error: $e");
      }
      if (municipalOrigin == null) {
        _loadingDialog.dismiss();
        return _showSnackBar(
          "Your store has no municipality set. Update your Store Profile address first.",
          isError: true,
        );
      }

      // 2. Prepare Payload
      final Map<String, dynamic> payload = {
        "item_seller_id": widget.sellerId,
        "item_name": _nameCtrl.text.trim(),
        "item_description": _descCtrl.text.trim(),
        "item_price": num.tryParse(_priceCtrl.text.trim()) ?? 0,
        "item_stocks": _stockNotApplicable ? -1 : (num.tryParse(_stockCtrl.text.trim()) ?? 0),
        "item_type": _selectedType,
        "item_category": _categoryCtrl.text.trim(),
        "item_available": _isAvailable,
        "item_images": finalImageUrls, // jsonb column
        "item_municipality_origin": municipalOrigin,
        "item_variations": _collectVariations().isEmpty ? null : _collectVariations(),
      };

      // 3. Upsert to Database
      if (widget.existingItem != null) {
        // Edit Mode
        payload["item_id"] = widget.existingItem!['item_id'];
        await _supabase.from('store_items').update(payload).eq('item_id', widget.existingItem!['item_id']);
      } else {
        // Add Mode
        payload["item_id"] = "ITEM_${DateTime.now().millisecondsSinceEpoch}";
        await _supabase.from('store_items').insert(payload);
      }

      if (mounted) {
        _loadingDialog.dismiss();
        _showSnackBar("Item saved successfully!");
        Navigator.pop(context, true); // Return true to trigger a refresh on the previous screen
      }
    } catch (e) {
      _loadingDialog.dismiss();
      debugPrint("Error saving item: $e");
      _showSnackBar("Failed to save item: $e", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? dangerColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // =========================================================================
  // UI BUILDERS
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.existingItem != null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        title: Text(
          isEditMode ? "Edit Item" : "Add New Item",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = Responsive.isDesktop(context);
              final bool isTablet = Responsive.isTablet(context);
              final bool isWide = isDesktop || isTablet;
              final double maxW = isDesktop ? 1200 : (isTablet ? 900 : 640);
              final EdgeInsets pad = EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                vertical: isDesktop ? 28 : 20,
              );

              final submitButton = SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isEditMode ? "SAVE CHANGES" : "PUBLISH ITEM",
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 14.5),
                  ),
                ),
              );

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Padding(
                      padding: pad,
                      child: isWide
                          ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSectionHeader("ITEM IMAGES", "Upload up to 2 high-quality images"),
                                  _buildImageUploader(),
                                  const SizedBox(height: 24),
                                  _buildAvailabilityCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSectionHeader("BASIC DETAILS", "Product name and description"),
                                  _buildBasicInfoCard(),
                                  const SizedBox(height: 24),
                                  _buildSectionHeader("PRICING & STOCK", "Set the price and available quantity"),
                                  _buildPricingInventoryCard(),
                                  const SizedBox(height: 24),
                                  _buildSectionHeader("CATEGORIZATION", "Organize your item for customers"),
                                  _buildCategoryCard(),
                                  const SizedBox(height: 24),
                                  _buildSectionHeader("VARIATIONS (OPTIONAL)", "e.g. Sizes, flavors, colors — each with its own price & stock"),
                                  _buildVariationsCard(),
                                  const SizedBox(height: 28),
                                  submitButton,
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader("ITEM IMAGES", "Upload up to 2 high-quality images"),
                          _buildImageUploader(),
                          const SizedBox(height: 28),
                          _buildSectionHeader("BASIC DETAILS", "Product name and description"),
                          _buildBasicInfoCard(),
                          const SizedBox(height: 28),
                          _buildSectionHeader("PRICING & STOCK", "Set the price and available quantity"),
                          _buildPricingInventoryCard(),
                          const SizedBox(height: 28),
                          _buildSectionHeader("CATEGORIZATION", "Organize your item for customers"),
                          _buildCategoryCard(),
                          const SizedBox(height: 28),
                          _buildSectionHeader("VARIATIONS (OPTIONAL)", "e.g. Sizes, flavors, colors — each with its own price & stock"),
                          _buildVariationsCard(),
                          const SizedBox(height: 28),
                          _buildAvailabilityCard(),
                          const SizedBox(height: 36),
                          submitButton,
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  ImageProvider _getImageProvider(dynamic media) {
    if (media is String) {
      if (media.startsWith('http')) return NetworkImage(media);
      return MemoryImage(Utility.decodeHexImage(media)!);
    }
    if (media is XFile) {
      return kIsWeb ? NetworkImage(media.path) : FileImage(File(media.path));
    }
    throw Exception("Unknown media type");
  }

  Widget _buildImageUploader() {
    int totalImages = _existingImages.length + _newImages.length;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Photos ($totalImages/2)",
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              if (totalImages < 2)
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.add_photo_alternate_rounded, color: primaryBlue, size: 18),
                  label: Text("Add Photo", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700)),
                )
            ],
          ),
          const SizedBox(height: 16),

          if (totalImages == 0)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder, style: BorderStyle.solid, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined, color: textSecondary.withValues(alpha: 0.5), size: 36),
                    const SizedBox(height: 8),
                    Text("Tap to upload images", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Show Existing Images (From DB)
                  ..._existingImages.asMap().entries.map((entry) {
                    int idx = entry.key;
                    String imageUrlOrHex = entry.value;
                    return _buildImageThumbnail(_getImageProvider(imageUrlOrHex), () => _removeExistingImage(idx));
                  }),

                  // Show Newly Picked Images
                  ..._newImages.asMap().entries.map((entry) {
                    int idx = entry.key;
                    XFile file = entry.value;
                    return _buildImageThumbnail(_getImageProvider(file), () => _removeNewImage(idx));
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(ImageProvider image, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(
          height: 100,
          width: 100,
          margin: const EdgeInsets.only(right: 12, top: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 0,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: dangerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
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
        children: [
          _buildTextField(controller: _nameCtrl, label: "Item Name", icon: Icons.label_outline_rounded),
          const SizedBox(height: 16),
          _buildTextField(controller: _descCtrl, label: "Description (Optional)", icon: Icons.subject_rounded, maxLines: 4),
        ],
      ),
    );
  }

  Widget _buildPricingInventoryCard() {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 360;

    final priceField = _buildTextField(
      controller: _priceCtrl,
      label: "Price (₱)",
      icon: Icons.payments_outlined,
      inputType: const TextInputType.numberWithOptions(decimal: true),
    );

    final stockField = _buildTextField(
      controller: _stockCtrl,
      label: "Initial Stock",
      icon: Icons.inventory_2_outlined,
      inputType: TextInputType.number,
      enabled: !_stockNotApplicable,
    );

    final naSwitch = Row(
      children: [
        Expanded(
          child: Text(
            "Stocks not applicable",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryDark),
          ),
        ),
        Switch(
          value: _stockNotApplicable,
          activeColor: primaryBlue,
          onChanged: (val) => setState(() {
            _stockNotApplicable = val;
            if (val) _stockCtrl.clear();
          }),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isSmallScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [priceField, const SizedBox(height: 14), stockField],
                )
              : Row(
                  children: [
                    Expanded(child: priceField),
                    const SizedBox(width: 16),
                    Expanded(child: stockField),
                  ],
                ),
          const SizedBox(height: 8),
          naSwitch,
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedType,
            hint: Text("Select Item Type", style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
            items: _itemTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark, fontSize: 14)),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedType = val),
            decoration: InputDecoration(
              labelText: "Item Type",
              labelStyle: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
              prefixIcon: Icon(Icons.category_outlined, color: textSecondary, size: 20),
              filled: true,
              fillColor: bgColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryBlue, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            hint: Text("Select Category", style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
            items: MarketCategories.labels.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(cat, style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark, fontSize: 14)),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedCategory = val;
                if (val != null) _categoryCtrl.text = val;
              });
            },
            decoration: InputDecoration(
              labelText: "Category",
              labelStyle: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
              prefixIcon: Icon(Icons.folder_outlined, color: textSecondary, size: 20),
              filled: true,
              fillColor: bgColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryBlue, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariationsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Variations (${_varLabelCtrls.length})",
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              TextButton.icon(
                onPressed: _addVariation,
                icon: Icon(Icons.add_circle_outline_rounded, color: primaryBlue, size: 18),
                label: Text("Add Variation",
                    style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (_varLabelCtrls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Leave empty if this item has no variants. The main price & stock will be used.",
                style: TextStyle(color: textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ),
          for (int i = 0; i < _varLabelCtrls.length; i++)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text("#${i + 1}",
                            style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 11)),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: "Remove",
                        onPressed: () => _removeVariation(i),
                        icon: Icon(Icons.delete_outline_rounded,
                            color: dangerColor, size: 20),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _varLabelCtrls[i],
                    decoration: InputDecoration(
                      labelText: "Label (e.g. Small, Red, 500g)",
                      labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primaryBlue, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _varPriceCtrls[i],
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: "Price (₱)",
                            labelStyle:
                                TextStyle(color: textSecondary, fontSize: 13),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: cardBorder)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: primaryBlue, width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _varStockCtrls[i],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Stock",
                            labelStyle:
                                TextStyle(color: textSecondary, fontSize: 13),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: cardBorder)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: primaryBlue, width: 1.5)),
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
    );
  }

  Widget _buildAvailabilityCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _isAvailable ? primaryBlue.withValues(alpha: 0.05) : cardBorder.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isAvailable ? primaryBlue.withValues(alpha: 0.3) : cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isAvailable ? primaryBlue.withValues(alpha: 0.1) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isAvailable ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: _isAvailable ? primaryBlue : textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Item Visibility",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: primaryDark),
                ),
                const SizedBox(height: 2),
                Text(
                  _isAvailable ? "Visible to customers" : "Hidden from your store",
                  style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            activeColor: primaryBlue,
            onChanged: (val) => setState(() => _isAvailable = val),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: inputType,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primaryDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        prefixIcon: maxLines == 1 ? Icon(icon, color: textSecondary, size: 20) : null,
        filled: true,
        fillColor: bgColor,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryBlue, width: 1.5)),
      ),
    );
  }
}
