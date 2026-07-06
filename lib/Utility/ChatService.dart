import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';

class ChatService {
  final String schema = SupabaseUtility().getSchema();
  final SupabaseClient _db = Supabase.instance.client;

  // Conversation the user is currently viewing; used to suppress notifications.
  static String? activeConversationId;

  String? get currentUserId => _db.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> fetchConversations({
    String? sellerId,
  }) async {
    final uid = currentUserId;
    if (uid == null) return [];
    var query = _db.schema(schema).from('chat_conversations').select();
    if (sellerId != null) {
      query = query.eq('conversation_seller_id', sellerId);
    } else {
      query = query.eq('conversation_buyer_id', uid);
    }
    final data = await query
        .gt('conversation_last_message_at', 0)
        .order('conversation_last_message_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      data,
    ).where(_hasConversationActivity).toList();
  }

  Future<int> sellerUnreadTotal(String sellerId) async {
    final data = await _db
        .schema(schema)
        .from('chat_conversations')
        .select('conversation_seller_unread')
        .eq('conversation_seller_id', sellerId);
    int total = 0;
    for (final r in (data as List)) {
      total +=
          int.tryParse(r['conversation_seller_unread']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  Future<Map<String, dynamic>?> getOrCreateConversation({
    required String sellerId,
    String? itemId,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return null;

    final activeConversation = await findConversation(sellerId: sellerId);
    if (activeConversation != null) return activeConversation;

    final emptyConversation = await findConversation(
      sellerId: sellerId,
      includeEmpty: true,
    );
    if (emptyConversation != null) return emptyConversation;

    final res = await _db
        .schema(schema)
        .rpc(
          'get_or_create_conversation',
          params: {'p_seller_id': sellerId, 'p_item_id': itemId},
        );
    if (res is List && res.isNotEmpty) {
      return Map<String, dynamic>.from(res.first);
    }
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<Map<String, dynamic>?> findConversation({
    required String sellerId,
    bool includeEmpty = false,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return null;

    final existing = await _db
        .schema(schema)
        .from('chat_conversations')
        .select()
        .eq('conversation_buyer_id', uid)
        .eq('conversation_seller_id', sellerId)
        .order('conversation_last_message_at', ascending: false)
        .limit(20);

    for (final row in (existing as List)) {
      final conversation = Map<String, dynamic>.from(row);
      if (includeEmpty || _hasConversationActivity(conversation)) {
        return conversation;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> deduplicateConversations(
    List<Map<String, dynamic>> conversations, {
    required bool sellerMode,
  }) {
    final unique = <String, Map<String, dynamic>>{};
    for (final conversation in conversations) {
      if (!_hasConversationActivity(conversation)) continue;
      final key = sellerMode
          ? conversation['conversation_buyer_id']?.toString()
          : conversation['conversation_seller_id']?.toString();
      if (key == null || key.isEmpty) continue;
      final current = unique[key];
      final nextDate =
          num.tryParse(
            conversation['conversation_last_message_at']?.toString() ?? '0',
          ) ??
          0;
      final currentDate =
          num.tryParse(
            current?['conversation_last_message_at']?.toString() ?? '0',
          ) ??
          0;
      if (current == null || nextDate > currentDate) {
        unique[key] = conversation;
      }
    }
    final result = unique.values.toList()
      ..sort((a, b) {
        final aDate =
            num.tryParse(
              a['conversation_last_message_at']?.toString() ?? '0',
            ) ??
            0;
        final bDate =
            num.tryParse(
              b['conversation_last_message_at']?.toString() ?? '0',
            ) ??
            0;
        return bDate.compareTo(aDate);
      });
    return result;
  }

  bool _hasConversationActivity(Map<String, dynamic> conversation) {
    final lastMessage =
        conversation['conversation_last_message']?.toString().trim() ?? '';
    final lastMessageAt =
        num.tryParse(
          conversation['conversation_last_message_at']?.toString() ?? '0',
        ) ??
        0;
    return lastMessageAt > 0 && lastMessage.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> fetchMessages(
    String conversationId,
  ) async {
    final data = await _db
        .schema(schema)
        .from('chat_messages')
        .select()
        .eq('message_conversation_id', conversationId)
        .order('message_date_added', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> sendMessage({
    required String conversationId,
    String? body,
    String? imageUrl,
  }) async {
    await _db
        .schema(schema)
        .rpc(
          'send_message',
          params: {
            'p_conversation_id': conversationId,
            'p_body': body,
            'p_image_url': imageUrl,
          },
        );
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _db
          .schema(schema)
          .rpc(
            'mark_conversation_read',
            params: {'p_conversation_id': conversationId},
          );
    } catch (_) {}
  }

  RealtimeChannel subscribeMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
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
          callback: (payload) =>
              onInsert(Map<String, dynamic>.from(payload.newRecord)),
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
      total +=
          int.tryParse(r['conversation_buyer_unread']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  Future<void> deleteMessage(String messageId) async {
    await _db
        .schema(schema)
        .from('chat_messages')
        .delete()
        .eq('message_id', messageId);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _db
        .schema(schema)
        .from('chat_messages')
        .delete()
        .eq('message_conversation_id', conversationId);
    await _db
        .schema(schema)
        .from('chat_conversations')
        .delete()
        .eq('conversation_id', conversationId);
  }

  RealtimeChannel subscribeAllMessages(
    void Function(Map<String, dynamic>) onInsert,
  ) {
    final channel = _db.channel(
      'chat_all_${DateTime.now().millisecondsSinceEpoch}',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: schema,
          table: 'chat_messages',
          callback: (payload) =>
              onInsert(Map<String, dynamic>.from(payload.newRecord)),
        )
        .subscribe();
    return channel;
  }

  Future<Map<String, String>> fetchSellerNames(Set<String> sellerIds) async {
    if (sellerIds.isEmpty) return {};
    final data = await _db
        .from('sellers')
        .select('seller_id, seller_store_name')
        .inFilter('seller_id', sellerIds.toList());
    final map = <String, String>{};
    for (final r in (data as List)) {
      map[r['seller_id'].toString()] = (r['seller_store_name'] ?? 'Store')
          .toString();
    }
    return map;
  }

  Future<Map<String, String>> fetchUserNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final data = await _db
        .from('user_data')
        .select('user_id, user_name')
        .inFilter('user_id', userIds.toList());
    final map = <String, String>{};
    for (final r in (data as List)) {
      map[r['user_id'].toString()] = (r['user_name'] ?? 'Buyer').toString();
    }
    return map;
  }

  Future<Map<String, int>> fetchUserBuyingScores(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final data = await _db
        .from('user_data')
        .select('user_id, user_buying_score')
        .inFilter('user_id', userIds.toList());
    final map = <String, int>{};
    for (final r in (data as List)) {
      map[r['user_id'].toString()] =
          int.tryParse(r['user_buying_score']?.toString() ?? '100') ?? 100;
    }
    return map;
  }
}
