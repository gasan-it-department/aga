class ItemVariations {
  static List<Map<String, dynamic>> parse(dynamic raw) {
    if (raw is! List) return [];
    final list = <Map<String, dynamic>>[];
    for (final v in raw) {
      if (v is Map) {
        final label = v['label']?.toString().trim() ?? '';
        if (label.isEmpty) continue;
        list.add({
          'label': label,
          'price': num.tryParse(v['price']?.toString() ?? '') ?? 0,
          'stock': num.tryParse(v['stock']?.toString() ?? '') ?? 0,
        });
      }
    }
    return list;
  }

  static bool has(dynamic raw) => parse(raw).isNotEmpty;

  static num minPrice(dynamic raw, {num fallback = 0}) {
    final vs = parse(raw);
    if (vs.isEmpty) return fallback;
    return vs.map((e) => e['price'] as num).reduce((a, b) => a < b ? a : b);
  }

  static num maxPrice(dynamic raw, {num fallback = 0}) {
    final vs = parse(raw);
    if (vs.isEmpty) return fallback;
    return vs.map((e) => e['price'] as num).reduce((a, b) => a > b ? a : b);
  }

  static num totalStock(dynamic raw, {num fallback = 0}) {
    final vs = parse(raw);
    if (vs.isEmpty) return fallback;
    if (vs.any((v) => (v['stock'] as num) < 0)) return -1;
    return vs.fold<num>(0, (s, v) => s + (v['stock'] as num));
  }

  static String priceLabel(
    dynamic raw,
    num fallbackPrice,
    String Function(num) format,
  ) {
    final vs = parse(raw);
    if (vs.isEmpty) return "₱${format(fallbackPrice)}";
    final lo = minPrice(raw);
    final hi = maxPrice(raw);
    if (lo == hi) return "₱${format(lo)}";
    return "₱${format(lo)} – ₱${format(hi)}";
  }
}
