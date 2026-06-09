import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/ChatService.dart';

import '../Database/SupabaseUtility.dart';

/// Foreground-side realtime listener for order events.
///
/// The background service isolate has no authenticated Supabase session, so
/// RLS on `orders` / `sellers` blocks its queries and realtime payloads. We
/// run these subscriptions from the main app (which has the user's session)
/// so the local notifications actually fire.
class OrderNotificationService {
  OrderNotificationService._();
  static final OrderNotificationService instance = OrderNotificationService._();

  final _supabase = Supabase.instance.client;
  final _local = FlutterLocalNotificationsPlugin();

  RealtimeChannel? _sellerChannel;
  RealtimeChannel? _userChannel;
  RealtimeChannel? _chatChannel;
  String? _activeUserId;
  String? _activeSellerId;
  bool _initialized = false;

  // In-memory dedupe so the same (orderId, status) doesn't fire twice within
  // the same app session (e.g. when several rows of the same order update at
  // once). Resets on app restart so a returning status change still notifies.
  final Set<String> _seenSessionKeys = <String>{};

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/aga_gasan_app_logo_rounded'),
    );
    await _local.initialize(settings: init);
    try {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  Future<void> start(String userId, {bool force = false}) async {
    if (userId.isEmpty) return;
    await _ensureInit();
    final alreadyActive =
        _activeUserId == userId && _userChannel != null && _sellerChannel != null;
    if (alreadyActive && !force) return;

    _activeUserId = userId;
    await _subscribeUserOrders(userId);
    await _subscribeSellerOrdersForUser(userId);
    await _subscribeChatMessages(userId);
  }

  /// Force a re-subscription. Use this on app resume — websockets can drop
  /// while backgrounded and missed status updates won't be replayed.
  Future<void> refresh() async {
    final uid = _activeUserId;
    if (uid == null || uid.isEmpty) return;
    await start(uid, force: true);
  }

  Future<void> stop() async {
    try {
      if (_userChannel != null) {
        await _supabase.removeChannel(_userChannel!);
        _userChannel = null;
      }
      if (_sellerChannel != null) {
        await _supabase.removeChannel(_sellerChannel!);
        _sellerChannel = null;
      }
      if (_chatChannel != null) {
        await _supabase.removeChannel(_chatChannel!);
        _chatChannel = null;
      }
    } catch (_) {}
    _activeUserId = null;
    _activeSellerId = null;
  }

  Future<void> _subscribeUserOrders(String userId) async {
    try {
      if (_userChannel != null) {
        await _supabase.removeChannel(_userChannel!);
        _userChannel = null;
      }
      _userChannel = _supabase.channel('app:user_orders:$userId');
      _userChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: SupabaseUtility().getSchema(),
            table: 'orders',
            // No server-side filter: with default REPLICA IDENTITY the old row
            // payload only carries the primary key, which makes
            // column-equality filters drop updates. We filter client-side.
            callback: (payload) async {
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;
              final rowUserId = newRecord['order_user_id']?.toString() ?? '';
              if (rowUserId != userId) return;

              final newStatus = newRecord['order_status']?.toString() ?? '';
              final oldStatus = oldRecord['order_status']?.toString() ?? '';
              Utility().printLog('user order update: $rowUserId  $oldStatus -> $newStatus');
              if (newStatus.isEmpty) return;
              // If old status is missing (REPLICA IDENTITY DEFAULT), we still
              // notify — dedupe via the seen key below prevents duplicates.
              if (oldStatus.isNotEmpty && newStatus == oldStatus) return;

              String title;
              switch (newStatus) {
                case 'placed':
                  title = 'Order placed';
                  break;
                case 'preparing':
                  title = 'Your order is being prepared';
                  break;
                case 'ready for pickup':
                case 'ready_for_pickup':
                case 'ready':
                  title = 'Your order is ready for pickup';
                  break;
                case 'out for delivery':
                case 'out_for_delivery':
                  title = 'Your order is out for delivery';
                  break;
                case 'completed':
                  title = 'Your order is completed';
                  break;
                case 'cancelled':
                case 'canceled':
                  title = 'Your order was cancelled';
                  break;
                default:
                  title = 'Order updated: ${newStatus.toUpperCase()}';
              }

              final orderId = newRecord['order_id']?.toString() ?? '';
              final seenKey = '${orderId}_$newStatus';
              if (_seenSessionKeys.contains(seenKey)) return;
              _seenSessionKeys.add(seenKey);

              await _show(
                channelId: 'user_order_updates',
                channelName: 'Order Updates',
                channelDescription: 'Updates on your orders.',
                id: '$orderId-$newStatus'.hashCode,
                title: title,
                body: 'Tap to view your orders.',
              );
            },
          )
          .subscribe((status, [error]) {
        Utility().printLog('user orders channel: $status ${error ?? ''}');
      });
    } catch (e) {
      Utility().printLog('user orders subscribe error: $e');
    }
  }

  Future<void> _subscribeSellerOrdersForUser(String userId) async {
    try {
      if (_sellerChannel != null) {
        await _supabase.removeChannel(_sellerChannel!);
        _sellerChannel = null;
      }
      // Resolve seller_id using the authenticated session (RLS allows it here).
      final row = await _supabase
          .from('sellers')
          .select('seller_id')
          .eq('seller_user_id', userId)
          .maybeSingle();
      final sellerId = row?['seller_id']?.toString();
      if (sellerId == null || sellerId.isEmpty) return;
      _activeSellerId = sellerId;

      _sellerChannel = _supabase.channel('app:seller_orders:$sellerId');
      _sellerChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'orders',
            callback: (payload) async {
              final r = payload.newRecord;
              if ((r['order_seller_id']?.toString() ?? '') != sellerId) return;
              final orderId = r['order_id']?.toString() ?? 'New Order';
              final qty = r['order_quantity']?.toString() ?? '1';
              final total = r['order_total_price']?.toString() ?? '';
              final body = total.isNotEmpty
                  ? 'Qty $qty · ₱$total · Tap to view in Seller Orders.'
                  : 'Qty $qty · Tap to view in Seller Orders.';
              await _show(
                channelId: 'seller_order_alerts',
                channelName: 'New Orders',
                channelDescription: 'Alerts when your shop receives a new order.',
                id: orderId.hashCode,
                title: 'New order placed',
                body: body,
              );
            },
          )
          .subscribe((status, [error]) {
        Utility().printLog('seller orders channel: $status ${error ?? ''}');
      });
    } catch (e) {
      Utility().printLog('seller orders subscribe error: $e');
    }
  }

  Future<void> _subscribeChatMessages(String userId) async {
    try {
      if (_chatChannel != null) {
        await _supabase.removeChannel(_chatChannel!);
        _chatChannel = null;
      }
      _chatChannel = _supabase.channel('app:chat_messages:$userId');
      _chatChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: SupabaseUtility().getSchema(),
            table: 'chat_messages',
            callback: (payload) async {
              final r = payload.newRecord;
              final senderId = r['message_sender_id']?.toString() ?? '';
              if (senderId == userId) return; // own message

              final convId = r['message_conversation_id']?.toString() ?? '';
              if (convId.isEmpty) return;

              final messageId = r['message_id']?.toString() ?? '';
              final seenKey = 'seen_chat_msg_$messageId';
              final prefs = await SharedPreferences.getInstance();
              await prefs.reload();
              if (messageId.isNotEmpty && prefs.getBool(seenKey) == true) return;

              // Suppress when already viewing this conversation (mark seen so the
              // background isolate doesn't fire a notification for it either).
              if (ChatService.activeConversationId == convId) {
                if (messageId.isNotEmpty) await prefs.setBool(seenKey, true);
                return;
              }

              // Confirm this user is a participant (buyer or store owner).
              final conv = await _supabase
                  .schema(SupabaseUtility().getSchema())
                  .from('chat_conversations')
                  .select('conversation_buyer_id, conversation_seller_id')
                  .eq('conversation_id', convId)
                  .maybeSingle();
              if (conv == null) return;
              final isBuyer = conv['conversation_buyer_id']?.toString() == userId;
              final isSeller = _activeSellerId != null &&
                  conv['conversation_seller_id']?.toString() == _activeSellerId;
              if (!isBuyer && !isSeller) return;

              if (messageId.isNotEmpty) await prefs.setBool(seenKey, true);
              final body = (r['message_body']?.toString().trim().isNotEmpty ?? false)
                  ? r['message_body'].toString()
                  : '📷 Photo';
              await _show(
                channelId: 'chat_messages',
                channelName: 'Messages',
                channelDescription: 'New chat messages.',
                id: (messageId.isNotEmpty ? messageId : convId).hashCode,
                title: 'New message',
                body: body,
              );
            },
          )
          .subscribe((status, [error]) {
        Utility().printLog('chat messages channel: $status ${error ?? ''}');
      });
    } catch (e) {
      Utility().printLog('chat messages subscribe error: $e');
    }
  }

  Future<void> _show({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _local.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.max,
            icon: '@drawable/aga_gasan_app_logo_rounded',
            ticker: title,
          ),
        ),
      );
    } catch (e) {
      Utility().printLog('local notif error: $e');
    }
  }
}
