import 'package:supabase_flutter/supabase_flutter.dart';

class BuyerScoreService {
  BuyerScoreService(this._supabase);

  final SupabaseClient _supabase;

  static const int normalMinimum = 80;
  static const int purchaseMinimum = 50;

  Future<int> getScore(String userId) async {
    final row = await _supabase
        .from('user_data')
        .select('user_buying_score')
        .eq('user_id', userId)
        .maybeSingle();
    return int.tryParse(row?['user_buying_score']?.toString() ?? '100') ?? 100;
  }

  Future<void> adjustScore(String userId, int change) async {
    final current = await getScore(userId);
    final updated = (current + change).clamp(0, 150);
    await _supabase
        .from('user_data')
        .update({'user_buying_score': updated})
        .eq('user_id', userId);
  }
}
