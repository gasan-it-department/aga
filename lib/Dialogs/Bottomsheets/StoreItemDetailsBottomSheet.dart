import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/ItemVariations.dart';
import 'package:gasan_port_tracker/Utility/ImageViewer.dart';

class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class StoreItemDetailsBottomSheet {
  static final Color primaryDark = const Color(0xFF0F172A);
  static final Color textSecondary = const Color(0xFF64748B);
  static final Color cardBorder = const Color(0xFFE2E8F0);
  static final Color primaryBlue = const Color(0xFF2563EB);
  static final Color bgColor = const Color(0xFFF8FAFC);
  static final Color priceColor = const Color(0xFFEE4D2D);
  static final Color successColor = const Color(0xFF10B981);
  static final Color dangerColor = const Color(0xFFEF4444);

  static void show(
    BuildContext context,
    Map<String, dynamic> item, {
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(item: item, onEdit: onEdit, onDelete: onDelete),
    );
  }

  static List<String> parseImages(dynamic rawImages) {
    if (rawImages is List) return rawImages.map((e) => e.toString()).toList();
    return [];
  }

  static Widget buildImage(String src, {BoxFit fit = BoxFit.cover}) {
    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => _broken(),
      );
    }
    final bytes = Utility.decodeHexImage(src);
    if (bytes == null) return _broken();
    return Image.memory(bytes, fit: fit, errorBuilder: (_, __, ___) => _broken());
  }

  static Widget _broken() {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade400, size: 32),
    );
  }
}

class _Sheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _Sheet({required this.item, this.onEdit, this.onDelete});

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  int _activeImage = 0;

  void _openViewer(List<String> images, int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => ImageViewer(imageUrls: images, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final List<String> images = StoreItemDetailsBottomSheet.parseImages(item['item_images']);
    final bool isAvailable = item['item_available'] ?? false;
    final variations = ItemVariations.parse(item['item_variations']);
    final num stock = variations.isNotEmpty
        ? ItemVariations.totalStock(item['item_variations'])
        : (item['item_stocks'] ?? 0);
    final String name = item['item_name'] ?? 'Unnamed Product';
    final String description = (item['item_description'] ?? '').toString();
    final String category = (item['item_category'] ?? 'General').toString();
    final String type = (item['item_type'] ?? 'OTHER').toString().toUpperCase();
    final double price = (item['item_price'] is num) ? (item['item_price'] as num).toDouble() : 0;

    final maxH = MediaQuery.of(context).size.height * 0.88;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: StoreItemDetailsBottomSheet.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      _buildImageSection(images, stock),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: StoreItemDetailsBottomSheet.primaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(type,
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: StoreItemDetailsBottomSheet.primaryBlue,
                                          letterSpacing: 0.6)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isAvailable
                                            ? StoreItemDetailsBottomSheet.successColor
                                            : StoreItemDetailsBottomSheet.textSecondary)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6, height: 6,
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? StoreItemDetailsBottomSheet.successColor
                                              : StoreItemDetailsBottomSheet.textSecondary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isAvailable ? "ACTIVE" : "HIDDEN",
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            color: isAvailable
                                                ? StoreItemDetailsBottomSheet.successColor
                                                : StoreItemDetailsBottomSheet.textSecondary,
                                            letterSpacing: 0.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              name,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: StoreItemDetailsBottomSheet.primaryDark,
                                  letterSpacing: -0.4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              variations.isNotEmpty
                                  ? ItemVariations.priceLabel(item['item_variations'], price,
                                      (v) => Utility().formatPrice(v))
                                  : "₱${Utility().formatPrice(price)}",
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: StoreItemDetailsBottomSheet.priceColor,
                                  letterSpacing: -0.5),
                            ),
                            if (variations.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                "VARIATIONS",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: StoreItemDetailsBottomSheet.textSecondary,
                                    letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: variations.map((v) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: StoreItemDetailsBottomSheet.bgColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: StoreItemDetailsBottomSheet.cardBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(v['label'].toString(),
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12.5,
                                                color: StoreItemDetailsBottomSheet.primaryDark)),
                                        const SizedBox(height: 2),
                                        Text(
                                            "₱${Utility().formatPrice(v['price'])} · Stock ${v['stock']}",
                                            style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: StoreItemDetailsBottomSheet.textSecondary)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _infoTile(
                                    icon: Icons.inventory_2_rounded,
                                    label: "STOCK",
                                    value: stock < 0 ? "N/A" : stock.toString(),
                                    color: (stock < 0 || stock > 0)
                                        ? StoreItemDetailsBottomSheet.successColor
                                        : StoreItemDetailsBottomSheet.dangerColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _infoTile(
                                    icon: Icons.folder_rounded,
                                    label: "CATEGORY",
                                    value: category,
                                    color: StoreItemDetailsBottomSheet.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            if (description.trim().isNotEmpty) ...[
                              const SizedBox(height: 22),
                              Text(
                                "DESCRIPTION",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: StoreItemDetailsBottomSheet.textSecondary,
                                    letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: StoreItemDetailsBottomSheet.primaryDark.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(List<String> images, num stock) {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            Container(
              color: StoreItemDetailsBottomSheet.bgColor,
              alignment: Alignment.center,
              child: Icon(Icons.image_outlined,
                  color: StoreItemDetailsBottomSheet.textSecondary.withValues(alpha: 0.3), size: 64),
            )
          else
            ScrollConfiguration(
              behavior: _DragScrollBehavior(),
              child: PageView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _activeImage = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _openViewer(images, i),
                  child: StoreItemDetailsBottomSheet.buildImage(images[i]),
                ),
              ),
            ),
          if (stock == 0)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "SOLD OUT",
                  style: TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
            ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final active = i == _activeImage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoTile({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: StoreItemDetailsBottomSheet.primaryDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: StoreItemDetailsBottomSheet.cardBorder)),
      ),
      child: Row(
        children: [
          if (widget.onDelete != null)
            Container(
              decoration: BoxDecoration(
                color: StoreItemDetailsBottomSheet.dangerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete!();
                },
                icon: Icon(Icons.delete_outline_rounded, color: StoreItemDetailsBottomSheet.dangerColor),
                tooltip: "Delete",
              ),
            ),
          if (widget.onDelete != null) const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onEdit == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      widget.onEdit!();
                    },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text("Edit Item", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: StoreItemDetailsBottomSheet.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

