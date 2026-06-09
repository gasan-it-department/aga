import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';

class ChatService {
  final String schema = SupabaseUtility().getSchema();
  final SupabaseClient _db = Supabase.instance.client;

  // Conversation the user is currently viewing; used to suppress notifications.
  static String? activeConversationId;

  String? get currentUserId => _db.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> fetchConversations({String? sellerId}) async {
    final uid = currentUserId;
    if (uid == null) return [];
    var query = _db.schema(schema).from('chat_conversations').select();
    if (sellerId != null) {
      query = query.eq('conversation_seller_id', sellerId);
    } else {
      query = query.eq('conversation_buyer_id', uid);
    }
    final data = await query.order('conversation_last_message_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<int> sellerUnreadTotal(String sellerId) async {
    final data = await _db
        .schema(schema)
        .from('chat_conversations')
        .select('conversation_seller_unread')
        .eq('conversation_seller_id', sellerId);
    int total = 0;
    for (final r in (data as List)) {
      total += int.tryParse(r['conversation_seller_unread']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  Future<Map<String, dynamic>?> getOrCreateConversation({required String sellerId, String? itemId}) async {
    final res = await _db.schema(schema).rpc('get_or_create_conversation', params: {
      'p_seller_id': sellerId,
      'p_item_id': itemId,
    });
    if (res is List && res.isNotEmpty) return Map<String, dynamic>.from(res.first);
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String conversationId) async {
    final data = await _db
        .schema(schema)
        .from('chat_messages')
        .select()
        .eq('message_conversation_id', conversationId)
        .order('message_date_added', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> sendMessage({required String conversationId, String? body, String? imageUrl}) async {
    await _db.schema(schema).rpc('send_message', params: {
      'p_conversation_id': conversationId,
      'p_body': body,
      'p_image_url': imageUrl,
    });
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _db.schema(schema).rpc('mark_conversation_read', params: {'p_conversation_id': conversationId});
    } catch (_) {}
  }

  RealtimeChannel subscribeMessages(String conversationId, void Function(Map<String, dynamic>) onInsert) {
    final channel = _db.channel('chat_$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: schema,
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'message_conversation_id',
            value: conversationId,
          ),
          callback: (payload) => onInsert(Map<String, dynamic>.from(payload.newRecord)),
        )
        .subscribe();
    return channel;
  }

  Future<int> buyerUnreadTotal() async {
    final uid = currentUserId;
    if (uid == null) return 0;
    final data = await _db
        .schema(schema)
        .from('chat_conversations')
        .select('conversation_buyer_unread')
        .eq('conversation_buyer_id', uid);
    int total = 0;
    for (final r in (data as List)) {
      total += int.tryParse(r['conversation_buyer_unread']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.schema(schema).from('chat_messages').delete().eq('message_id', messageId);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _db.schema(schema).from('chat_messages').delete().eq('message_conversation_id', conversationId);
    await _db.schema(schema).from('chat_conversations').delete().eq('conversation_id', conversationId);
  }

  RealtimeChannel subscribeAllMessages(void Function(Map<String, dynamic>) onInsert) {
    final channel = _db.channel('chat_all_${DateTime.now().millisecondsSinceEpoch}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: schema,
          table: 'chat_messages',
          callback: (payload) => onInsert(Map<String, dynamic>.from(payload.newRecord)),
        )
        .subscribe();
    return channel;
  }

  Future<Map<String, String>> fetchSellerNames(Set<String> sellerIds) async {
    if (sellerIds.isEmpty) return {};
    final data = await _db.from('sellers').select('seller_id, seller_store_name').inFilter('seller_id', sellerIds.toList());
    final map = <String, String>{};
    for (final r in (data as List)) {
      map[r['seller_id'].toString()] = (r['seller_store_name'] ?? 'Store').toString();
    }
    return map;
  }

  Future<Map<String, String>> fetchUserNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final data = await _db.from('user_data').select('user_id, user_name').inFilter('user_id', userIds.toList());
    final map = <String, String>{};
    for (final r in (data as List)) {
      map[r['user_id'].toString()] = (r['user_name'] ?? 'Buyer').toString();
    }
    return map;
  }
}
