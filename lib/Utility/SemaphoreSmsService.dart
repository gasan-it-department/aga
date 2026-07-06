import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SemaphoreSmsResult {
  const SemaphoreSmsResult({
    required this.sent,
    required this.code,
    this.httpStatus,
    this.providerStatus,
  });

  final bool sent;
  final String code;
  final int? httpStatus;
  final String? providerStatus;
}

class SemaphoreSmsService {
  static const String _apiKey = '6b7c3da819342a5edb57904a46b81c65';
  static const String senderName = 'MARINDUQUE';
  static final Uri _messagesUrl = Uri.parse(
    'https://semaphore.co/api/v4/messages',
  );

  static String? normalizePhilippineMobile(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    value = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    if (value.startsWith('+')) {
      value = '+${value.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    } else {
      value = value.replaceAll(RegExp(r'[^0-9]'), '');
    }

    if (value.startsWith('+6309') && value.length == 14) {
      value = '+63${value.substring(4)}';
    }
    if (value.startsWith('6309') && value.length == 13) {
      value = '+63${value.substring(3)}';
    }
    if (value.startsWith('+63') && value.length == 13) return value;
    if (value.startsWith('63') && value.length == 12) return '+$value';
    if (value.startsWith('09') && value.length == 11) {
      return '+63${value.substring(1)}';
    }
    if (value.startsWith('9') && value.length == 10) return '+63$value';
    return null;
  }

  Future<SemaphoreSmsResult> sendOrderPlacedToSeller({
    required String sellerNumber,
    required String orderId,
  }) async {
    final traceId = '${orderId}_${DateTime.now().millisecondsSinceEpoch}';
    final normalizedNumber = normalizePhilippineMobile(sellerNumber);
    _log(
      traceId,
      'START order_id="$orderId" platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} '
      'seller_number=${_maskNumber(sellerNumber)} '
      'normalized=${normalizedNumber == null ? '<invalid>' : _maskNumber(normalizedNumber)}',
    );

    if (orderId.trim().isEmpty) {
      _log(traceId, 'SKIPPED code=empty_order_id');
      return const SemaphoreSmsResult(sent: false, code: 'empty_order_id');
    }
    if (normalizedNumber == null) {
      _log(traceId, 'SKIPPED code=invalid_seller_number');
      return const SemaphoreSmsResult(
        sent: false,
        code: 'invalid_seller_number',
      );
    }

    if (kIsWeb) {
      _log(
        traceId,
        'WEB_WARNING direct request may be blocked by Semaphore CORS policy',
      );
    }

    final message =
        'New AGA order ${orderId.trim()} placed. Open Seller Orders to review.';
    final stopwatch = Stopwatch()..start();
    try {
      _log(
        traceId,
        'REQUEST method=POST endpoint=${_messagesUrl.host}${_messagesUrl.path} '
        'sender=$senderName number=${_maskNumber(normalizedNumber)} '
        'message_length=${message.length}',
      );
      final response = await http
          .post(
            _messagesUrl,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {
              'apikey': _apiKey,
              'number': normalizedNumber,
              'message': message,
              'sendername': senderName,
            },
          )
          .timeout(const Duration(seconds: 15));
      stopwatch.stop();

      final provider = _parseProviderResponse(response.body);
      final providerStatus = provider.status ?? 'unknown';
      final rejectedStatuses = {'failed', 'rejected', 'cancelled', 'canceled'};
      final sent =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          provider.hasMessage &&
          !rejectedStatuses.contains(providerStatus.toLowerCase());

      _log(
        traceId,
        'RESPONSE http=${response.statusCode} elapsed_ms=${stopwatch.elapsedMilliseconds} '
        'sent=$sent provider_status=$providerStatus '
        'message_id=${provider.messageId ?? '<none>'}',
      );
      if (!sent) {
        _log(
          traceId,
          'REJECTED code=provider_rejected body=${_safeBody(response.body)}',
        );
      }
      return SemaphoreSmsResult(
        sent: sent,
        code: sent ? 'sent' : 'provider_rejected',
        httpStatus: response.statusCode,
        providerStatus: providerStatus,
      );
    } on TimeoutException catch (error, stackTrace) {
      stopwatch.stop();
      _log(
        traceId,
        'TIMEOUT elapsed_ms=${stopwatch.elapsedMilliseconds} error=$error',
      );
      debugPrintStack(
        label: '[SemaphoreSMS][$traceId] Timeout stack',
        stackTrace: stackTrace,
      );
      return const SemaphoreSmsResult(sent: false, code: 'timeout');
    } catch (error, stackTrace) {
      stopwatch.stop();
      _log(
        traceId,
        'NETWORK_ERROR elapsed_ms=${stopwatch.elapsedMilliseconds} '
        'type=${error.runtimeType} error=$error',
      );
      debugPrintStack(
        label: '[SemaphoreSMS][$traceId] Network stack',
        stackTrace: stackTrace,
      );
      return const SemaphoreSmsResult(sent: false, code: 'network_error');
    }
  }

  static _SemaphoreProviderResponse _parseProviderResponse(String body) {
    if (body.trim().isEmpty) return const _SemaphoreProviderResponse();
    try {
      final decoded = jsonDecode(body);
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        final message = Map<String, dynamic>.from(decoded.first as Map);
        return _SemaphoreProviderResponse(
          hasMessage: true,
          status: message['status']?.toString(),
          messageId: message['message_id']?.toString(),
        );
      }
    } catch (_) {}
    return const _SemaphoreProviderResponse();
  }

  static String _safeBody(String body) {
    final redacted = body
        .replaceAll(RegExp(r'\+?63\d{10}|09\d{9}'), '<phone>')
        .replaceAll(_apiKey, '<api-key>');
    return redacted.length <= 500
        ? redacted
        : '${redacted.substring(0, 500)}...';
  }

  static String _maskNumber(String raw) {
    final value = raw.trim();
    if (value.length <= 4) return value.isEmpty ? '<empty>' : '****';
    return '${'*' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  static void _log(String traceId, String message) {
    debugPrint('[SemaphoreSMS][$traceId] $message');
  }
}

class _SemaphoreProviderResponse {
  const _SemaphoreProviderResponse({
    this.hasMessage = false,
    this.status,
    this.messageId,
  });

  final bool hasMessage;
  final String? status;
  final String? messageId;
}
