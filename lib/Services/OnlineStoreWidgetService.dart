import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnlineStoreWidgetService {
  static const MethodChannel _channel = MethodChannel(
    'aga/online_store_widget',
  );
  static const String _ordersKey = 'online_store_widget_new_orders';
  static const String _messagesKey = 'online_store_widget_messages';
  static const String _storeNameKey = 'online_store_widget_store_name';

  static Future<void> update({
    required int newOrders,
    required int messages,
    String storeName = 'Online Store',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ordersKey, newOrders);
    await prefs.setInt(_messagesKey, messages);
    await prefs.setString(_storeNameKey, storeName);

    if (kIsWeb || !Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('updateStoreWidget', {
        'new_orders': newOrders,
        'messages': messages,
        'store_name': storeName,
      });
    } catch (error) {
      debugPrint('Online store widget update failed: $error');
    }
  }
}
