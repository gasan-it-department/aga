import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

const String _backgroundServiceChannelId =
    'background_service_silent_channel_v2';
const String _notificationRefreshTokenKey = 'aga_notification_refresh_token';
const Duration _notificationBackfillWindow = Duration(hours: 1);

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();

  await SupabaseUtility().loadDeveloperMode();

  await Supabase.initialize(
    url: SupabaseUtility().getSupabaseProjectURL(),
    anonKey: SupabaseUtility().getSupabaseAnonKey(),
  );

  final supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/aga_gasan_app_logo_rounded');
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await localNotifications.initialize(settings: initializationSettings);

  RealtimeChannel? globalChannel;
  RealtimeChannel? userDataChannel;
  RealtimeChannel? sellerOrdersChannel;
  RealtimeChannel? userOrdersChannel;
  RealtimeChannel? chatChannel;
  StreamSubscription<List<ConnectivityResult>>? connectivitySub;
  StreamSubscription<Position>? gpsStream;
  Timer? serviceHealthTimer;

  Future<void> disconnectNotificationChannels() async {
    final channels = <RealtimeChannel?>[
      globalChannel,
      userDataChannel,
      sellerOrdersChannel,
      userOrdersChannel,
      chatChannel,
    ];
    globalChannel = null;
    userDataChannel = null;
    sellerOrdersChannel = null;
    userOrdersChannel = null;
    chatChannel = null;
    for (final channel in channels) {
      if (channel != null) {
        try {
          await supabase.removeChannel(channel);
        } catch (_) {}
      }
    }
  }

  Future<String?> authenticateNotificationUser() async {
    await prefs.reload();
    final expectedUserId = prefs.getString('user_id')?.trim() ?? '';
    final refreshToken =
        await secureStorage.read(key: _notificationRefreshTokenKey) ?? '';
    if (expectedUserId.isEmpty || refreshToken.isEmpty) {
      Utility().printLog(
        'Notification background auth skipped: no active user session.',
      );
      return null;
    }

    try {
      final response = await supabase.auth.setSession(refreshToken);
      final session = response.session;
      final authenticatedUserId = session?.user.id ?? '';
      if (session == null || authenticatedUserId != expectedUserId) {
        Utility().printLog(
          'Notification background auth rejected: expected=$expectedUserId actual=$authenticatedUserId',
        );
        return null;
      }
      if (session.refreshToken != refreshToken) {
        await secureStorage.write(
          key: _notificationRefreshTokenKey,
          value: session.refreshToken,
        );
      }
      Utility().printLog(
        'Notification background authenticated for user $expectedUserId.',
      );
      return expectedUserId;
    } catch (error) {
      Utility().printLog('Notification background auth failed: $error');
      return null;
    }
  }

  Future<String?> currentNotificationUserId() async {
    await prefs.reload();
    final userId = prefs.getString('user_id')?.trim() ?? '';
    if (userId.isEmpty || supabase.auth.currentUser?.id != userId) return null;
    return userId;
  }

  Future<void> keepAndroidServiceForeground({
    String title = 'AGA',
    String content = 'AGA background process running...',
  }) async {
    if (service is AndroidServiceInstance) {
      await service.setAsForegroundService();
      service.setForegroundNotificationInfo(title: title, content: content);
    }
  }

  await keepAndroidServiceForeground();

  Future<void> startLocationTracking({
    required String vehicleId,
    required String schema,
    String? refreshToken,
  }) async {
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await supabase.auth.setSession(refreshToken);
      } catch (e) {
        Utility().printLog("Failed to authenticate location broadcaster: $e");
      }
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Utility().printLog("Location broadcaster stopped: GPS is disabled.");
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      Utility().printLog(
        "Location broadcaster stopped: location permission denied.",
      );
      return;
    }

    await prefs.setString('tracking_vehicle_id', vehicleId);
    await prefs.setString('tracking_schema', schema);
    if (service is AndroidServiceInstance) {
      await service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: "Active Dispatch Tracking",
        content: "Starting live location broadcast...",
      );
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    await gpsStream?.cancel();
    gpsStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        try {
          await supabase
              .schema(schema)
              .from('vehicles')
              .update({
                'vehicle_current_coordinates': {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                },
              })
              .eq('vehicle_id', vehicleId);
          Utility().printLog(
            "Broadcast vehicle $vehicleId: ${position.latitude}, ${position.longitude}",
          );
        } catch (e) {
          Utility().printLog("Failed to update background location: $e");
        }

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Active Dispatch Tracking",
            content:
                "Broadcasting: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}",
          );
        }
      },
      onError: (error) {
        Utility().printLog("Location stream error: $error");
      },
    );
  }

  Future<void> updateLastSeenEpoch(int newEpoch) async {
    if (newEpoch > 0) {
      await prefs.setInt('last_notification_epoch', newEpoch);
    }
  }

  int _notificationEpoch(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();

    final text = value.toString().trim();
    if (text.isEmpty) return 0;

    final numeric = int.tryParse(text);
    if (numeric != null) return numeric;

    return DateTime.tryParse(text)?.millisecondsSinceEpoch ?? 0;
  }

  bool _isRecentNotificationEpoch(int epoch) {
    if (epoch <= 0) return false;
    final age = DateTime.now().millisecondsSinceEpoch - epoch;
    return age >= 0 && age <= _notificationBackfillWindow.inMilliseconds;
  }

  bool _isRecentNotificationValue(dynamic value) {
    return _isRecentNotificationEpoch(_notificationEpoch(value));
  }

  // --- Helper: Seen Personal Notification IDs ---
  List<String> getSeenLimitedIds() =>
      prefs.getStringList('seen_limited_ids') ?? [];

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
    final vehicleId = event?['vehicle_id']?.toString();
    if (vehicleId == null || vehicleId.isEmpty) return;
    await startLocationTracking(
      vehicleId: vehicleId,
      schema: event?['schema']?.toString() ?? SupabaseUtility().getSchema(),
      refreshToken: event?['refresh_token']?.toString(),
    );
  });

  service.on('stop_location_tracking').listen((event) async {
    await gpsStream?.cancel();
    gpsStream = null;
    await prefs.remove('tracking_vehicle_id');
    await prefs.remove('tracking_schema');

    if (service is AndroidServiceInstance) {
      await keepAndroidServiceForeground();
    }
  });

  // =======================================================================
  // NOTIFICATION SYNC LOGIC (WITH EXPLICIT SCHEMA FIX)
  // =======================================================================
  Future<void> syncMissedNotifications() async {
    try {
      final activeUserId = await currentNotificationUserId();
      if (activeUserId == null) return;
      await prefs.reload();

      // 1. SYNC GLOBAL NOTIFICATIONS
      int? lastSeenEpoch = prefs.getInt('last_notification_epoch');
      if (lastSeenEpoch == null) {
        await updateLastSeenEpoch(DateTime.now().millisecondsSinceEpoch);
      } else {
        String currentUserZipCode =
            prefs.getString("preferred_notification_municipality_zipcode") ??
            "0000";

        // FIXED: Added .schema()
        final globalResponse = await supabase
            .schema(SupabaseUtility().getSchema())
            .from('global_notification')
            .select()
            .gt('notification_date', lastSeenEpoch)
            .order('notification_date', ascending: true);

        for (var record in globalResponse) {
          String source = record["notification_source"]?.toString() ?? "";
          String originZip =
              record["notification_origin_zipcode"]?.toString() ?? "0000";
          final int recordEpoch = _notificationEpoch(
            record["notification_date"],
          );

          bool shouldShow =
              (source != "mdrrmo") ||
              (currentUserZipCode == "0000" || currentUserZipCode == originZip);

          if (shouldShow && _isRecentNotificationEpoch(recordEpoch)) {
            await _showNotification(localNotifications, record);
            await Future.delayed(const Duration(milliseconds: 500));
          }
          await updateLastSeenEpoch(recordEpoch);
        }
      }

      // 2. SYNC LIMITED (PERSONAL) NOTIFICATIONS
      final String? userId = prefs.getString('user_id');
      if (userId == activeUserId) {
        // FIXED: Added .schema()
        final userResponse = await supabase
            .schema(SupabaseUtility().getSchema())
            .from('user_data')
            .select('limited_notifications')
            .eq('user_id', activeUserId)
            .maybeSingle();

        if (userResponse != null &&
            userResponse['limited_notifications'] != null) {
          final List<dynamic> notifications =
              userResponse['limited_notifications'];
          final List<String> seenIds = getSeenLimitedIds();

          for (var i = notifications.length - 1; i >= 0; i--) {
            final note = notifications[i];
            final String noteId = note['id']?.toString() ?? "";
            final bool recent =
                _isRecentNotificationValue(note['created_at']) ||
                _isRecentNotificationValue(note['date_sent']) ||
                _isRecentNotificationValue(note['notification_date']) ||
                _isRecentNotificationValue(note['timestamp']);

            if (noteId.isNotEmpty && !seenIds.contains(noteId) && recent) {
              await _showLimitedNotification(
                localNotifications,
                note['title'] ?? 'Notice',
                note['message'] ?? 'New update',
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
      final userId = await currentNotificationUserId();
      if (userId == null) return;

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

      sellerOrdersChannel = supabase.channel(
        '${SupabaseUtility().getSchema()}:orders:$sellerId',
      );
      sellerOrdersChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: SupabaseUtility().getSchema(),
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_seller_id',
              value: sellerId,
            ),
            callback: (payload) async {
              if (await currentNotificationUserId() != userId) return;
              final newRecord = payload.newRecord;
              if ((newRecord['order_seller_id']?.toString() ?? '') !=
                  sellerId) {
                return;
              }
              final rowOrderId =
                  newRecord['order_id']?.toString() ?? 'New Order';
              final groupId =
                  newRecord['order_group_id']?.toString().trim() ?? '';
              final orderReference = groupId.isNotEmpty ? groupId : rowOrderId;
              final seenKey = 'seen_seller_order_${orderReference}_placed';
              if (prefs.getBool(seenKey) == true) return;
              await prefs.setBool(seenKey, true);
              final qty = newRecord['order_quantity']?.toString() ?? '1';
              final total = newRecord['order_total_price']?.toString() ?? '';
              final body = total.isNotEmpty
                  ? "Qty $qty · ₱$total · Tap to view in Seller Orders."
                  : "Qty $qty · Tap to view in Seller Orders.";
              await _showSellerOrderNotification(
                localNotifications,
                "New order received",
                body,
                orderReference,
              );
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: SupabaseUtility().getSchema(),
            table: 'orders',
            callback: (payload) async {
              if (await currentNotificationUserId() != userId) return;
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;
              if ((newRecord['order_seller_id']?.toString() ?? '') !=
                  sellerId) {
                return;
              }

              final newStatus =
                  newRecord['order_status']?.toString().trim().toLowerCase() ??
                  '';
              final oldStatus =
                  oldRecord['order_status']?.toString().trim().toLowerCase() ??
                  '';
              if (newStatus != 'cancelled' && newStatus != 'canceled') return;
              if (oldStatus.isNotEmpty && oldStatus == newStatus) return;

              final rowOrderId = newRecord['order_id']?.toString() ?? '';
              final groupId =
                  newRecord['order_group_id']?.toString().trim() ?? '';
              final orderReference = groupId.isNotEmpty ? groupId : rowOrderId;
              final seenKey = 'seen_seller_order_${orderReference}_cancelled';
              if (prefs.getBool(seenKey) == true) return;
              await prefs.setBool(seenKey, true);

              Utility().printLog(
                'background seller order cancelled: seller_id=$sellerId order=$orderReference',
              );
              await _showSellerOrderNotification(
                localNotifications,
                'Order cancelled by buyer',
                'Order $orderReference was cancelled. Tap to view Seller Orders.',
                '$orderReference-cancelled',
              );
            },
          )
          .subscribe();
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
      final userId = await currentNotificationUserId();
      if (userId == null) return;

      userOrdersChannel = supabase.channel(
        '${SupabaseUtility().getSchema()}:user_orders:$userId',
      );
      userOrdersChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: SupabaseUtility().getSchema(),
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_user_id',
              value: userId,
            ),
            callback: (payload) async {
              if (await currentNotificationUserId() != userId) return;
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;
              final rowUserId =
                  newRecord['order_user_id']?.toString().trim() ?? '';
              if (rowUserId != userId) return;
              final newStatus = newRecord['order_status']?.toString() ?? '';
              final oldStatus = oldRecord['order_status']?.toString() ?? '';
              if (newStatus.isEmpty || newStatus == oldStatus) return;

              String? title;
              String body = "Tap to view your orders.";
              switch (newStatus) {
                case 'placed':
                  title = "Order placed";
                  break;
                case 'preparing':
                  title = "Your order is being prepared";
                  break;
                case 'ready for pickup':
                case 'ready_for_pickup':
                case 'ready':
                  title = "Your order is ready for pickup";
                  break;
                case 'out for delivery':
                case 'out_for_delivery':
                  title = "Your order is out for delivery";
                  break;
                case 'completed':
                  title = "Your order is completed";
                  break;
                case 'cancelled':
                case 'canceled':
                  title = "Your order was cancelled";
                  break;
                default:
                  title = "Order updated: ${newStatus.toUpperCase()}";
              }

              final rowOrderId = newRecord['order_id']?.toString() ?? '';
              final groupId =
                  newRecord['order_group_id']?.toString().trim() ?? '';
              final orderReference = groupId.isNotEmpty ? groupId : rowOrderId;
              final seenKey = 'seen_user_order_${orderReference}_$newStatus';
              if (prefs.getBool(seenKey) == true) return;
              await prefs.setBool(seenKey, true);

              await _showUserOrderNotification(
                localNotifications,
                title,
                body,
                '$orderReference-$newStatus',
              );
            },
          )
          .subscribe();
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
      final userId = await currentNotificationUserId();
      if (userId == null) return;
      await prefs.reload();
      final sellerId = prefs.getString('seller_id');

      chatChannel = supabase.channel(
        '${SupabaseUtility().getSchema()}:chat_messages:$userId',
      );
      chatChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: SupabaseUtility().getSchema(),
            table: 'chat_messages',
            callback: (payload) async {
              if (await currentNotificationUserId() != userId) return;
              final r = payload.newRecord;
              final senderId = r['message_sender_id']?.toString() ?? '';
              if (senderId == userId) return; // own message

              final convId = r['message_conversation_id']?.toString() ?? '';
              if (convId.isEmpty) return;

              final messageId = r['message_id']?.toString() ?? '';
              final seenKey = 'seen_chat_msg_$messageId';
              await prefs.reload();
              if (messageId.isNotEmpty && prefs.getBool(seenKey) == true) {
                return;
              }

              // Verify this user is a participant (buyer or store owner).
              Map<String, dynamic>? conv;
              try {
                final result = await supabase
                    .schema(SupabaseUtility().getSchema())
                    .from('chat_conversations')
                    .select('conversation_buyer_id, conversation_seller_id')
                    .eq('conversation_id', convId)
                    .maybeSingle();
                if (result != null) {
                  conv = Map<String, dynamic>.from(result);
                }
              } catch (error) {
                Utility().printLog('Chat conversation lookup failed: $error');
              }
              if (conv == null) {
                Utility().printLog(
                  'Chat notification skipped: inaccessible conversation $convId.',
                );
                return;
              }
              final isBuyer =
                  conv['conversation_buyer_id']?.toString() == userId;
              final isSeller =
                  sellerId != null &&
                  sellerId.isNotEmpty &&
                  conv['conversation_seller_id']?.toString() == sellerId;
              if (!isBuyer && !isSeller) return;

              if (messageId.isNotEmpty) await prefs.setBool(seenKey, true);
              final body =
                  (r['message_body']?.toString().trim().isNotEmpty ?? false)
                  ? r['message_body'].toString()
                  : '📷 Photo';
              await _showChatNotification(
                localNotifications,
                'New message',
                body,
                messageId.isNotEmpty ? messageId : convId,
              );
            },
          )
          .subscribe((status, error) {
            Utility().printLog(
              'Background chat channel: $status${error == null ? '' : ' error=$error'}',
            );
          });
    } catch (e) {
      Utility().printLog("Error subscribing chat channel: $e");
    }
  }

  Future<void> connectToSupabase() async {
    if (globalChannel != null) {
      supabase.removeChannel(globalChannel!);
      globalChannel = null;
    }
    if (userDataChannel != null) {
      supabase.removeChannel(userDataChannel!);
      userDataChannel = null;
    }

    final userId = await currentNotificationUserId();
    if (userId == null) return;

    // Global Channel
    globalChannel = supabase.channel(
      '${SupabaseUtility().getSchema()}:global_notification',
    );
    globalChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: SupabaseUtility().getSchema(),
          table: 'global_notification',
          callback: (payload) async {
            if (await currentNotificationUserId() != userId) return;
            await prefs.reload();
            String currentUserZipCode =
                prefs.getString(
                  "preferred_notification_municipality_zipcode",
                ) ??
                "0000";
            final newRecord = payload.newRecord;

            String source = newRecord["notification_source"]?.toString() ?? "";
            String originZip =
                newRecord["notification_origin_zipcode"]?.toString() ?? "0000";
            final int recordEpoch = _notificationEpoch(
              newRecord["notification_date"],
            );

            if (source != "mdrrmo" ||
                (currentUserZipCode == "0000" ||
                    currentUserZipCode == originZip)) {
              _showNotification(localNotifications, newRecord);
            }
            await updateLastSeenEpoch(recordEpoch);
          },
        )
        .subscribe();

    // User Data Channel
    userDataChannel = supabase.channel(
      '${SupabaseUtility().getSchema()}:user_data',
    );
    userDataChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: SupabaseUtility().getSchema(),
          table: 'user_data',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            if (await currentNotificationUserId() != userId) return;
            await prefs.reload();
            final newRecord = payload.newRecord;
            final currentUserId = prefs.getString('user_id') ?? '';
            final rowUserId = newRecord['user_id']?.toString() ?? '';
            if (currentUserId.isEmpty || rowUserId != currentUserId) return;
            if (newRecord.containsKey('limited_notifications') &&
                newRecord['limited_notifications'] != null) {
              try {
                final dynamic rawData = newRecord['limited_notifications'];
                if (rawData is List && rawData.isNotEmpty) {
                  final Map<String, dynamic> latest = Map<String, dynamic>.from(
                    rawData.first,
                  );
                  final String noteId = latest['id']?.toString() ?? "";
                  final bool recent =
                      _isRecentNotificationValue(latest['created_at']) ||
                      _isRecentNotificationValue(latest['date_sent']) ||
                      _isRecentNotificationValue(latest['notification_date']) ||
                      _isRecentNotificationValue(latest['timestamp']);

                  if (!getSeenLimitedIds().contains(noteId) && recent) {
                    _showLimitedNotification(
                      localNotifications,
                      latest['title'] ?? 'Notice',
                      latest['message'] ?? 'New update',
                    );
                    await markLimitedIdAsSeen(noteId);
                  }
                }
              } catch (e) {
                Utility().printLog(
                  "Error parsing limited_notifications List: $e",
                );
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> refreshAllNotificationChannels() async {
    await disconnectNotificationChannels();
    final userId = await authenticateNotificationUser();
    if (userId == null) return;
    await connectToSupabase();
    await connectSellerOrdersChannel();
    await connectUserOrdersChannel();
    await connectChatChannel();
    await syncMissedNotifications();
    Utility().printLog(
      'Notification background channels ready for user $userId.',
    );
  }

  await refreshAllNotificationChannels();

  final recoveredVehicleId = prefs.getString('tracking_vehicle_id');
  if (recoveredVehicleId != null && recoveredVehicleId.isNotEmpty) {
    startLocationTracking(
      vehicleId: recoveredVehicleId,
      schema:
          prefs.getString('tracking_schema') ?? SupabaseUtility().getSchema(),
    );
  }

  connectivitySub = Connectivity().onConnectivityChanged.listen((
    List<ConnectivityResult> results,
  ) async {
    if (!results.contains(ConnectivityResult.none)) {
      await refreshAllNotificationChannels();
    }
  });

  serviceHealthTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
    try {
      await refreshAllNotificationChannels();
    } catch (e) {
      Utility().printLog("Background service health check failed: $e");
    }
  });

  service.on('refresh_seller_channel').listen((event) {
    refreshAllNotificationChannels();
  });

  service.on('refresh_user_orders_channel').listen((event) {
    refreshAllNotificationChannels();
  });

  service.on('refresh_chat_channel').listen((event) {
    refreshAllNotificationChannels();
  });

  service.on('refresh_notification_channels').listen((event) async {
    await refreshAllNotificationChannels();
  });

  service.on('notification_auth_changed').listen((event) async {
    final userId = event?['user_id']?.toString().trim() ?? '';
    final refreshToken = event?['refresh_token']?.toString() ?? '';
    if (userId.isEmpty || refreshToken.isEmpty) {
      Utility().printLog(
        'Notification auth change ignored: incomplete session data.',
      );
      return;
    }
    await prefs.setString('user_id', userId);
    await secureStorage.write(
      key: _notificationRefreshTokenKey,
      value: refreshToken,
    );
    await refreshAllNotificationChannels();
  });

  service.on('notification_auth_cleared').listen((event) async {
    await disconnectNotificationChannels();
    await prefs.remove('user_id');
    await prefs.remove('seller_id');
    await secureStorage.delete(key: _notificationRefreshTokenKey);
    Utility().printLog('Notification background user context cleared.');
  });

  service.on('stopService').listen((event) {
    serviceHealthTimer?.cancel();
    connectivitySub?.cancel();
    gpsStream?.cancel();
    disconnectNotificationChannels();
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

Future<void> _showNotification(
  FlutterLocalNotificationsPlugin localNotifications,
  Map<dynamic, dynamic> newRecord,
) async {
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
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  } catch (error) {
    Utility().printLog("NOTIFICATION ERROR: ${error.toString()}");
  }
}

Future<void> _showLimitedNotification(
  FlutterLocalNotificationsPlugin localNotifications,
  String title,
  String body,
) async {
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
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  } catch (error) {
    Utility().printLog("LIMITED NOTIFICATION ERROR: ${error.toString()}");
  }
}

Future<void> _showSellerOrderNotification(
  FlutterLocalNotificationsPlugin localNotifications,
  String title,
  String body,
  String orderId,
) async {
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
          onlyAlertOnce: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  } catch (error) {
    Utility().printLog("SELLER ORDER NOTIFICATION ERROR: ${error.toString()}");
  }
}

Future<void> _showChatNotification(
  FlutterLocalNotificationsPlugin localNotifications,
  String title,
  String body,
  String tag,
) async {
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
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  } catch (error) {
    Utility().printLog("CHAT NOTIFICATION ERROR: ${error.toString()}");
  }
}

Future<void> _showUserOrderNotification(
  FlutterLocalNotificationsPlugin localNotifications,
  String title,
  String body,
  String tag,
) async {
  try {
    await localNotifications.show(
      id: tag.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'user_order_updates',
          'Order Updates',
          channelDescription:
              'Updates on your orders (preparing, ready, out for delivery).',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@drawable/aga_gasan_app_logo_rounded',
          ticker: 'Order update',
          ongoing: false,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  } catch (error) {
    Utility().printLog("USER ORDER NOTIFICATION ERROR: ${error.toString()}");
  }
}

class NotificationBackgroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> setAuthenticatedUser(Session session) async {
    if (kIsWeb) return;
    final userId = session.user.id.trim();
    final refreshToken = session.refreshToken;
    if (userId.isEmpty || refreshToken == null || refreshToken.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await _secureStorage.write(
      key: _notificationRefreshTokenKey,
      value: refreshToken,
    );
    if (await _service.isRunning()) {
      _service.invoke('notification_auth_changed', {
        'user_id': userId,
        'refresh_token': refreshToken,
      });
    }
  }

  Future<void> clearAuthenticatedUser() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('seller_id');
    await _secureStorage.delete(key: _notificationRefreshTokenKey);
    if (await _service.isRunning()) {
      _service.invoke('notification_auth_cleared');
    }
  }

  Future<void> initialize() async {
    const AndroidNotificationChannel backgroundChannel =
        AndroidNotificationChannel(
          _backgroundServiceChannelId,
          'App Background Service',
          description: 'Keeps AGA connected for background updates.',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );

    const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
      'high_priority_alerts',
      'Emergency & System Alerts',
      description: 'High priority notifications from the AGA Port Tracker.',
      importance: Importance.max,
    );

    const AndroidNotificationChannel sellerOrderChannel =
        AndroidNotificationChannel(
          'seller_order_alerts',
          'New Orders',
          description: 'Alerts when your shop receives a new order.',
          importance: Importance.max,
        );

    const AndroidNotificationChannel userOrderChannel =
        AndroidNotificationChannel(
          'user_order_updates',
          'Order Updates',
          description:
              'Updates on your orders (preparing, ready, out for delivery).',
          importance: Importance.max,
        );

    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_messages',
      'Messages',
      description: 'New chat messages.',
      importance: Importance.max,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: AndroidInitializationSettings(
            '@drawable/aga_gasan_app_logo_rounded',
          ),
          iOS: DarwinInitializationSettings(),
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(backgroundChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alertChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(sellerOrderChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(userOrderChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(chatChannel);

    // Android 13+ requires runtime POST_NOTIFICATIONS permission, otherwise
    // notifications are silently dropped — which is why orders never popped.
    try {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _backgroundServiceChannelId,
        initialNotificationTitle: 'AGA',
        initialNotificationContent: 'AGA background process running...',
        foregroundServiceNotificationId: 111,
        foregroundServiceTypes: [
          AndroidForegroundType.dataSync,
          AndroidForegroundType.location,
        ],
      ),

      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    if (!await _service.isRunning()) {
      await _service.startService();
    }
  }
}
