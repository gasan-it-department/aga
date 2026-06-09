import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  await Supabase.initialize(
    url: SupabaseUtility().getSupabaseProjectURL(),
    anonKey: SupabaseUtility().getSupabaseAnonKey(),
  );

  await SupabaseUtility().loadDeveloperMode();

  final supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@drawable/aga_gasan_app_logo_rounded');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await localNotifications.initialize(settings: initializationSettings);

  RealtimeChannel? globalChannel;
  RealtimeChannel? userDataChannel;
  RealtimeChannel? sellerOrdersChannel;
  RealtimeChannel? userOrdersChannel;
  RealtimeChannel? chatChannel;
  StreamSubscription<List<ConnectivityResult>>? connectivitySub;
  StreamSubscription<Position>? gpsStream;

  Future<void> updateLastSeenEpoch(int newEpoch) async {
    if (newEpoch > 0) {
      await prefs.setInt('last_notification_epoch', newEpoch);
    }
  }

  // --- Helper: Seen Personal Notification IDs ---
  List<String> getSeenLimitedIds() => prefs.getStringList('seen_limited_ids') ?? [];

  Future<void> markLimitedIdAsSeen(String id) async {
    List<String> seen = getSeenLimitedIds();
    if (!seen.contains(id)) {
      seen.add(id);
      if (seen.length > 200) seen.removeAt(0);
      await prefs.setStringList('seen_limited_ids', seen);
    }
  }

  // =======================================================================
  // LOCATION TRACKING LOGIC (WITH EXPLICIT SCHEMA FIX)
  // =======================================================================
  service.on('start_location_tracking').listen((event) async {
    final vehicleId = event?['vehicle_id'];
    if (vehicleId == null) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    gpsStream?.cancel();
    gpsStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {

      try {
        await supabase
            .schema(SupabaseUtility().getSchema())
            .from('vehicles')
            .update({
          'vehicle_current_coordinates': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          }
        }).eq('vehicle_id', vehicleId);
      } catch (e) {
        Utility().printLog("Failed to update background location: $e");
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Active Dispatch Tracking",
          content: "Broadcasting: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}",
        );
      }
    });
  });

  service.on('stop_location_tracking').listen((event) {
    gpsStream?.cancel();

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'AGA',
        content: 'Monitoring for critical updates...',
      );
    }
  });

  // =======================================================================
  // NOTIFICATION SYNC LOGIC (WITH EXPLICIT SCHEMA FIX)
  // =======================================================================
  Future<void> syncMissedNotifications() async {
    try {
      await prefs.reload();

      // 1. SYNC GLOBAL NOTIFICATIONS
      int? lastSeenEpoch = prefs.getInt('last_notification_epoch');
      if (lastSeenEpoch == null) {
        await updateLastSeenEpoch(DateTime.now().millisecondsSinceEpoch);
      } else {
        String currentUserZipCode = prefs.getString("preferred_notification_municipality_zipcode") ?? "0000";

        // FIXED: Added .schema()
        final globalResponse = await supabase
            .schema(SupabaseUtility().getSchema())
            .from('global_notification')
            .select()
            .gt('notification_date', lastSeenEpoch)
            .order('notification_date', ascending: true);

        for (var record in globalResponse) {
          String source = record["notification_source"]?.toString() ?? "";
          String originZip = record["notification_origin_zipcode"]?.toString() ?? "0000";
          int recordEpoch = int.tryParse(record["notification_date"]?.toString() ?? "0") ?? 0;

          bool shouldShow = (source != "mdrrmo") ||
              (currentUserZipCode == "0000" || currentUserZipCode == originZip);

          if (shouldShow) {
            await _showNotification(localNotifications, record);
            await Future.delayed(const Duration(milliseconds: 500));
          }
          await updateLastSeenEpoch(recordEpoch);
        }
      }

      // 2. SYNC LIMITED (PERSONAL) NOTIFICATIONS
      final String? userId = prefs.getString('user_id');
      if (userId != null) {
        // FIXED: Added .schema()
        final userResponse = await supabase
            .schema(SupabaseUtility().getSchema())
            .from('user_data')
            .select('limited_notifications')
            .eq('user_id', userId)
            .maybeSingle();

        if (userResponse != null && userResponse['limited_notifications'] != null) {
          final List<dynamic> notifications = userResponse['limited_notifications'];
          final List<String> seenIds = getSeenLimitedIds();

          for (var i = notifications.length - 1; i >= 0; i--) {
            final note = notifications[i];
            final String noteId = note['id']?.toString() ?? "";

            if (noteId.isNotEmpty && !seenIds.contains(noteId)) {
              await _showLimitedNotification(
                  localNotifications,
                  note['title'] ?? 'Notice',
                  note['message'] ?? 'New update'
              );
              await markLimitedIdAsSeen(noteId);
              await Future.delayed(const Duration(milliseconds: 800));
            }
          }
        }
      }
    } catch (e) {
      Utility().printLog("Error syncing offline notifications: $e");
    }
  }

  Future<void> connectSellerOrdersChannel() async {
    try {
      if (sellerOrdersChannel != null) {
        supabase.removeChannel(sellerOrdersChannel!);
        sellerOrdersChannel = null;
      }
      final userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) return;

      // Resolve the seller_id for this user (if they own a shop).
      final sellerRow = await supabase
          .schema(SupabaseUtility().getSchema())
          .from('sellers')
          .select('seller_id, seller_store_name')
          .eq('seller_user_id', userId)
          .maybeSingle();

      if (sellerRow == null) return;
      final String? sellerId = sellerRow['seller_id']?.toString();
      if (sellerId == null || sellerId.isEmpty) return;
      await prefs.setString('seller_id', sellerId);

      sellerOrdersChannel = supabase.channel('${SupabaseUtility().getSchema()}:orders:$sellerId');
      sellerOrdersChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: SupabaseUtility().getSchema(),
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'order_seller_id',
          value: sellerId,
        ),
        callback: (payload) async {
          final newRecord = payload.newRecord;
          final orderId = newRecord['order_id']?.toString() ?? 'New Order';
          final qty = newRecord['order_quantity']?.toString() ?? '1';
          final total = newRecord['order_total_price']?.toString() ?? '';
          final body = total.isNotEmpty
              ? "Qty $qty · ₱$total · Tap to view in Seller Orders."
              : "Qty $qty · Tap to view in Seller Orders.";
          await _showSellerOrderNotification(localNotifications, "New order received", body, orderId);
        },
      ).subscribe();
    } catch (e) {
      Utility().printLog("Error subscribing seller orders channel: $e");
    }
  }

  Future<void> connectUserOrdersChannel() async {
    try {
      if (userOrdersChannel != null) {
        supabase.removeChannel(userOrdersChannel!);
        userOrdersChannel = null;
      }
      final userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) return;

      userOrdersChannel = supabase.channel('${SupabaseUtility().getSchema()}:user_orders:$userId');
      userOrdersChannel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: SupabaseUtility().getSchema(),
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'order_user_id',
          value: userId,
        ),
        callback: (payload) async {
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          final newStatus = newRecord['order_status']?.toString() ?? '';
          final oldStatus = oldRecord['order_status']?.toString() ?? '';
          if (newStatus.isEmpty || newStatus == oldStatus) return;

          String? title;
          String body = "Tap to view your orders.";
          switch (newStatus) {
            case 'preparing':
              title = "Your order is being prepared";
              break;
            case 'ready_for_pickup':
            case 'ready':
              title = "Your order is ready for pickup";
              break;
            case 'out_for_delivery':
              title = "Your order is out for delivery";
              break;
            default:
              return;
          }

          final orderId = newRecord['order_id']?.toString() ?? '';
          final seenKey = 'seen_user_order_${orderId}_$newStatus';
          if (prefs.getBool(seenKey) == true) return;
          await prefs.setBool(seenKey, true);

          await _showUserOrderNotification(localNotifications, title, body, '$orderId-$newStatus');
        },
      ).subscribe();
    } catch (e) {
      Utility().printLog("Error subscribing user orders channel: $e");
    }
  }

  Future<void> connectChatChannel() async {
    try {
      if (chatChannel != null) {
        supabase.removeChannel(chatChannel!);
        chatChannel = null;
      }
      final userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) return;
      final sellerId = prefs.getString('seller_id');

      chatChannel = supabase.channel('${SupabaseUtility().getSchema()}:chat_messages:$userId');
      chatChannel!.onPostgresChanges(
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
          await prefs.reload();
          if (messageId.isNotEmpty && prefs.getBool(seenKey) == true) return;

          // Verify this user is a participant (buyer or store owner).
          final conv = await supabase
              .schema(SupabaseUtility().getSchema())
              .from('chat_conversations')
              .select('conversation_buyer_id, conversation_seller_id')
              .eq('conversation_id', convId)
              .maybeSingle();
          if (conv == null) return;
          final isBuyer = conv['conversation_buyer_id']?.toString() == userId;
          final isSeller = sellerId != null && sellerId.isNotEmpty &&
              conv['conversation_seller_id']?.toString() == sellerId;
          if (!isBuyer && !isSeller) return;

          if (messageId.isNotEmpty) await prefs.setBool(seenKey, true);
          final body = (r['message_body']?.toString().trim().isNotEmpty ?? false)
              ? r['message_body'].toString()
              : '📷 Photo';
          await _showChatNotification(
              localNotifications, 'New message', body, messageId.isNotEmpty ? messageId : convId);
        },
      ).subscribe();
    } catch (e) {
      Utility().printLog("Error subscribing chat channel: $e");
    }
  }

  void connectToSupabase() {
    if (globalChannel != null) {
      supabase.removeChannel(globalChannel!);
      globalChannel = null;
    }
    if (userDataChannel != null) {
      supabase.removeChannel(userDataChannel!);
      userDataChannel = null;
    }

    // Global Channel
    globalChannel = supabase.channel('${SupabaseUtility().getSchema()}:global_notification');
    globalChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: SupabaseUtility().getSchema(),
      table: 'global_notification',
      callback: (payload) async {
        await prefs.reload();
        String currentUserZipCode = prefs.getString("preferred_notification_municipality_zipcode") ?? "0000";
        final newRecord = payload.newRecord;

        String source = newRecord["notification_source"]?.toString() ?? "";
        String originZip = newRecord["notification_origin_zipcode"]?.toString() ?? "0000";
        int recordEpoch = int.tryParse(newRecord["notification_date"]?.toString() ?? "0") ?? 0;

        if (source != "mdrrmo" || (currentUserZipCode == "0000" || currentUserZipCode == originZip)) {
          _showNotification(localNotifications, newRecord);
        }
        await updateLastSeenEpoch(recordEpoch);
      },
    ).subscribe();

    // User Data Channel
    userDataChannel = supabase.channel('${SupabaseUtility().getSchema()}:user_data');
    userDataChannel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: SupabaseUtility().getSchema(),
      table: 'user_data',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: prefs.getString('user_id') ?? '',
      ),
      callback: (payload) async {
        final newRecord = payload.newRecord;
        if (newRecord.containsKey('limited_notifications') && newRecord['limited_notifications'] != null) {
          try {
            final dynamic rawData = newRecord['limited_notifications'];
            if (rawData is List && rawData.isNotEmpty) {
              final Map<String, dynamic> latest = Map<String, dynamic>.from(rawData.first);
              final String noteId = latest['id']?.toString() ?? "";

              if (!getSeenLimitedIds().contains(noteId)) {
                _showLimitedNotification(
                    localNotifications,
                    latest['title'] ?? 'Notice',
                    latest['message'] ?? 'New update'
                );
                await markLimitedIdAsSeen(noteId);
              }
            }
          } catch (e) {
            Utility().printLog("Error parsing limited_notifications List: $e");
          }
        }
      },
    ).subscribe();
  }

  connectToSupabase();
  connectSellerOrdersChannel();
  connectUserOrdersChannel();
  connectChatChannel();
  syncMissedNotifications();

  connectivitySub = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    if (!results.contains(ConnectivityResult.none)) {
      connectToSupabase();
      connectSellerOrdersChannel();
      connectUserOrdersChannel();
      connectChatChannel();
      syncMissedNotifications();
    }
  });

  service.on('refresh_seller_channel').listen((event) {
    connectSellerOrdersChannel();
  });

  service.on('refresh_user_orders_channel').listen((event) {
    connectUserOrdersChannel();
  });

  service.on('refresh_chat_channel').listen((event) {
    connectChatChannel();
  });

  service.on('stopService').listen((event) {
    connectivitySub?.cancel();
    gpsStream?.cancel();
    if (globalChannel != null) supabase.removeChannel(globalChannel!);
    if (userDataChannel != null) supabase.removeChannel(userDataChannel!);
    if (sellerOrdersChannel != null) supabase.removeChannel(sellerOrdersChannel!);
    if (userOrdersChannel != null) supabase.removeChannel(userOrdersChannel!);
    if (chatChannel != null) supabase.removeChannel(chatChannel!);
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

Future<void> _showNotification(FlutterLocalNotificationsPlugin localNotifications, Map<dynamic, dynamic> newRecord) async {
  try {
    await localNotifications.show(
      id: newRecord['notification_id']?.hashCode ?? DateTime.now().millisecond,
      title: newRecord['notification_title'] ?? 'AGA Notification',
      body: newRecord['notification_message'] ?? 'New notification update.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_priority_alerts',
          'Emergency & System Alerts',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@drawable/aga_gasan_app_logo_rounded',
          ticker: 'ticker',
          ongoing: false,
          autoCancel: true,
        ),
      ),
    );
  } catch(error) {
    Utility().printLog("NOTIFICATION ERROR: ${error.toString()}");
  }
}

Future<void> _showLimitedNotification(FlutterLocalNotificationsPlugin localNotifications, String title, String body) async {
  try {
    await localNotifications.show(
      id: title.hashCode + body.hashCode + DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_priority_alerts',
          'Notifications',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@drawable/aga_gasan_app_logo_rounded',
          ticker: 'ticker',
          ongoing: false,
          autoCancel: true,
        ),
      ),
    );
  } catch(error) {
    Utility().printLog("LIMITED NOTIFICATION ERROR: ${error.toString()}");
  }
}

Future<void> _showSellerOrderNotification(FlutterLocalNotificationsPlugin localNotifications, String title, String body, String orderId) async {
  try {
    await localNotifications.show(
      id: orderId.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'seller_order_alerts',
          'New Orders',
          channelDescription: 'Alerts when your shop receives a new order.',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@drawable/aga_gasan_app_logo_rounded',
          ticker: 'New order',
          ongoing: false,
          autoCancel: true,
        ),
      ),
    );
  } catch (error) {
    Utility().printLog("SELLER ORDER NOTIFICATION ERROR: ${error.toString()}");
  }
}

Future<void> _showChatNotification(FlutterLocalNotificationsPlugin localNotifications, String title, String body, String tag) async {
  try {
    await localNotifications.show(
      id: tag.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'Messages',
          channelDescription: 'New chat messages.',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@drawable/aga_gasan_app_logo_rounded',
          ticker: 'New message',
          ongoing: false,
          autoCancel: true,
        ),
      ),
    );
  } catch (error) {
    Utility().printLog("CHAT NOTIFICATION ERROR: ${error.toString()}");
  }
}

Future<void> _showUserOrderNotification(FlutterLocalNotificationsPlugin localNotifications, String title, String body, String tag) async {
  try {
    await localNotifications.show(
      id: tag.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'user_order_updates',
          'Order Updates',
          channelDescription: 'Updates on your orders (preparing, ready, out for delivery).',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@drawable/aga_gasan_app_logo_rounded',
          ticker: 'Order update',
          ongoing: false,
          autoCancel: true,
        ),
      ),
    );
  } catch (error) {
    Utility().printLog("USER ORDER NOTIFICATION ERROR: ${error.toString()}");
  }
}

class NotificationBackgroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initialize() async {
    const AndroidNotificationChannel backgroundChannel = AndroidNotificationChannel(
      'background_service_channel',
      'App Background Service',
      description: 'Keeps the app connected to receive emergency alerts.',
      importance: Importance.low,
    );

    const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
      'high_priority_alerts',
      'Emergency & System Alerts',
      description: 'High priority notifications from the AGA Port Tracker.',
      importance: Importance.max,
    );

    const AndroidNotificationChannel sellerOrderChannel = AndroidNotificationChannel(
      'seller_order_alerts',
      'New Orders',
      description: 'Alerts when your shop receives a new order.',
      importance: Importance.max,
    );

    const AndroidNotificationChannel userOrderChannel = AndroidNotificationChannel(
      'user_order_updates',
      'Order Updates',
      description: 'Updates on your orders (preparing, ready, out for delivery).',
      importance: Importance.max,
    );

    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_messages',
      'Messages',
      description: 'New chat messages.',
      importance: Importance.max,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(backgroundChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alertChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(sellerOrderChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(userOrderChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chatChannel);

    // Android 13+ requires runtime POST_NOTIFICATIONS permission, otherwise
    // notifications are silently dropped — which is why orders never popped.
    try {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: false,
        notificationChannelId: 'background_service_channel',
        initialNotificationTitle: 'AGA',
        initialNotificationContent: 'Monitoring for critical updates...',
        foregroundServiceNotificationId: 111,
      ),

      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}
