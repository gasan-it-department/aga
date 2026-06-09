import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight on-device recommendation helper.
///
/// Records the item TYPE every time the user opens an item (max 10 most
/// recent records, stored in SharedPreferences). The recency-weighted history
/// is then used to personalize how item lists are ordered: types the user
/// looked at most often float to the top, while ties (and unseen types) stay
/// randomly shuffled so the feed never feels static.
class ItemPreferenceTracker {
  static const String _key = 'viewed_item_types';
  static const int maxRecords = 10;

  static String _norm(dynamic type) => (type ?? '').toString().trim().toLowerCase();

  /// Call whenever the user opens/views an item.
  static Future<void> recordView(dynamic type) async {
    final t = _norm(type);
    if (t.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    list.insert(0, t);
    await prefs.setStringList(_key, list.take(maxRecords).toList());
  }

  /// Most recent viewed types (newest first), max [maxRecords].
  static Future<List<String>> recentTypes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? <String>[];
  }

  /// type -> frequency among the recorded views.
  static Future<Map<String, int>> typeWeights() async {
    final list = await recentTypes();
    final map = <String, int>{};
    for (final t in list) {
      map[t] = (map[t] ?? 0) + 1;
    }
    return map;
  }

  /// Returns a new list ordered by the user's preferences.
  /// Items whose type was viewed more often rank higher; items within the
  /// same weight tier (including all unseen types when there is no history)
  /// are randomly shuffled.
  static List<Map<String, dynamic>> personalize(
    List<Map<String, dynamic>> items,
    Map<String, int> weights,
  ) {
    final rng = Random();
    final scored = items.map((e) {
      final w = weights[_norm(e['item_type'])] ?? 0;
      // Integer weight defines the tier; random fraction shuffles within it.
      return _Scored(e, w + rng.nextDouble());
    }).toList();
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.item).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class _Scored {
  final Map<String, dynamic> item;
  final double score;
  _Scored(this.item, this.score);
}
