import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/js.dart' as js;

class WebPushNotificationService {
  WebPushNotificationService._();

  static final instance = WebPushNotificationService._();
  static const vapidKey =
      'BFBw3qXL551kS8bOQHrglPDYx-LZgoxAYgimOZAQRctfjbJ3qvkO4IS9_8SY6lofG9p3XyIg2zOluBXMI98amc0';

  bool _initialized = false;
  String? _currentUserId;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> initializeForUser(String userId) async {
    if (!kIsWeb || userId.isEmpty) return;

    try {
      if (vapidKey.length < 80 || !vapidKey.startsWith('B')) {
        throw StateError(
          'Invalid Firebase Web Push public VAPID key. Copy the full public '
          'key from Firebase Console > Project Settings > Cloud Messaging > '
          'Web Push certificates.',
        );
      }

      if (!_initialized) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyDbtxsf5VEBGcTj789fW8-FH0A_CTDWO-8',
            authDomain: 'aga-mobile.firebaseapp.com',
            projectId: 'aga-mobile',
            storageBucket: 'aga-mobile.firebasestorage.app',
            messagingSenderId: '235079847465',
            appId: '1:235079847465:web:8192d90601703c1554d638',
            measurementId: 'G-TCL1CDW3L0',
          ),
        );
        _initialized = true;
        FirebaseMessaging.onMessage.listen((message) {
          debugPrint('Foreground web FCM message received: ${message.data}');
          final title =
              message.notification?.title ?? message.data['title'] ?? 'AGA';
          final body =
              message.notification?.body ??
              message.data['body'] ??
              'You have a new notification.';
          final notificationId =
              message.data['message_id'] ??
              message.data['order_id'] ??
              DateTime.now().microsecondsSinceEpoch.toString();
          if (html.Notification.permission == 'granted') {
            js.context.callMethod('showAgaNotification', [
              title,
              body,
              notificationId,
            ]);
          }
        });
      }

      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken(vapidKey: vapidKey);
      if (token == null) {
        throw StateError('Firebase returned no web FCM token.');
      }
      _currentUserId = userId;
      _currentToken = token;
      await _saveToken(userId, token);

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        (token) {
          final activeUserId = _currentUserId;
          if (activeUserId == null || activeUserId.isEmpty) return;
          _currentToken = token;
          _saveToken(activeUserId, token);
        },
        onError: (error) => debugPrint('Web FCM token refresh failed: $error'),
      );
      debugPrint('Web FCM token registered for user $userId.');
    } catch (error, stackTrace) {
      debugPrint('Web push registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    final db = Supabase.instance.client;
    final row = await db
        .from('user_data')
        .select('web_fcm_tokens')
        .eq('user_id', userId)
        .maybeSingle();
    final tokens = row?['web_fcm_tokens'] is List
        ? List<String>.from(row!['web_fcm_tokens'])
        : <String>[];
    if (!tokens.contains(token)) tokens.add(token);
    await db
        .from('user_data')
        .update({'web_fcm_tokens': tokens})
        .eq('user_id', userId);
  }

  Future<void> unregisterCurrentUser() async {
    if (!kIsWeb) return;
    final userId =
        _currentUserId ?? Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final token =
          _currentToken ?? await messaging.getToken(vapidKey: vapidKey);
      if (token != null && token.isNotEmpty) {
        final db = Supabase.instance.client;
        final row = await db
            .from('user_data')
            .select('web_fcm_tokens')
            .eq('user_id', userId)
            .maybeSingle();
        final tokens = row?['web_fcm_tokens'] is List
            ? List<String>.from(row!['web_fcm_tokens'])
            : <String>[];
        tokens.removeWhere((savedToken) => savedToken == token);
        await db
            .from('user_data')
            .update({'web_fcm_tokens': tokens})
            .eq('user_id', userId);
      }
    } catch (error) {
      debugPrint('Web FCM token cleanup failed: $error');
    } finally {
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      _currentUserId = null;
      _currentToken = null;
    }
  }
}
