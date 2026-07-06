class Municipalities {
  static const List<Map<String, String>> list = [
    {"name": "Boac", "psgc": "174001000", "zip": "4900", "bridge": "boac-4900"},
    {"name": "Mogpog", "psgc": "174004000", "zip": "4901", "bridge": "mogpog-4901"},
    {"name": "Santa Cruz", "psgc": "174005000", "zip": "4902", "bridge": "santa-cruz-4902"},
    {"name": "Torrijos", "psgc": "174006000", "zip": "4903", "bridge": "torrijos-4903"},
    {"name": "Buenavista", "psgc": "174002000", "zip": "4904", "bridge": "buenavista-4904"},
    {"name": "Gasan", "psgc": "174003000", "zip": "4905", "bridge": "gasan-4905"},
  ];

  static List<String> getNames() => list.map((m) => m['name']!).toList();

  static String? getNameByZip(dynamic zip) {
    if (zip == null) return null;
    final z = zip.toString();
    for (final m in list) {
      if (m['zip'] == z) return m['name'];
    }
    return null;
  }

  static String? getBridgeByZip(dynamic zip) {
    if (zip == null) return null;
    final z = zip.toString();
    for (final m in list) {
      if (m['zip'] == z) return m['bridge'];
    }
    return null;
  }

  static Map<String, String>? getByBridge(String? bridge) {
    if (bridge == null || bridge.trim().isEmpty) return null;
    final key = bridge.trim().toLowerCase();
    for (final m in list) {
      if (m['bridge'] == key) return m;
    }
    return null;
  }
}
