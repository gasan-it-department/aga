import 'dart:convert';

import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';
import 'package:gasan_port_tracker/Utility/BuildStatus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseExternalAuthBridge {
  static const String _testBaseUrl =
      'https://gmitp-development-8xhiry.laravel.cloud';
  static const String _liveBaseUrl = 'https://gasanmarinduque.xyz';
  static const String _laravelSanctumTokenKey = 'laravel_sanctum_token';
  static const String _currentUserIdKey = 'external_auth_current_user_id';
  static const String _currentTokenKey = 'external_auth_current_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static bool get _useTestApi =>
      BuildStatus().isDebugMode() || SupabaseUtility.isDeveloperMode;

  static String get _baseUrl => _useTestApi ? _testBaseUrl : _liveBaseUrl;
  static String get _endpoint => '$_baseUrl/api/v1/auth/supabase';
  static String get _submissionContextEndpoint =>
      '$_baseUrl/api/v1/community-reports/submission-context';
  static String get _communityReportsEndpoint =>
      '$_baseUrl/api/v1/community-reports';
  static String get _supportTicketsEndpoint =>
      '$_baseUrl/api/v1/support-tickets';
  static String get _announcementsEndpoint => '$_baseUrl/api/v1/announcements';
  static String get _eventsEndpoint => '$_baseUrl/api/v1/events';

  static String resolveAssetUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    if (trimmed.startsWith('/')) {
      return '$_baseUrl$trimmed';
    }
    return '$_baseUrl/$trimmed';
  }

  Future<http.Response> authenticate({
    String deviceName = 'AGA Android App',
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final supabaseToken = session?.accessToken;
      final userId = session?.user.id;

      if (supabaseToken == null) {
        throw Exception('No Supabase session token found.');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('No Supabase user found.');
      }

      Utility().printLog(
        'External auth bridge request: endpoint=$_endpoint user_id=$userId device=$deviceName',
      );

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'access_token': supabaseToken,
          'device_name': deviceName,
        }),
      );

      Utility().printLog('External auth bridge status: ${response.statusCode}');
      Utility().printLog('External auth bridge body: ${response.body}');
      await _storeTokenFromResponse(userId: userId, response: response);
      return response;
    } catch (e, stacktrace) {
      Utility().printLog('External auth bridge failed: $e');
      Utility().printLog('External auth bridge stacktrace: $stacktrace');
      rethrow;
    }
  }

  Future<http.Response> getCommunityReportSubmissionContext() async {
    final token =
        await _secureStorage.read(key: _laravelSanctumTokenKey) ??
        await getCurrentToken();

    if (token == null || token.isEmpty) {
      throw Exception('No Laravel Sanctum token found.');
    }

    final response = await http.get(
      Uri.parse(_submissionContextEndpoint),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Municipality-Slug': 'gasan-4905',
      },
    );

    Utility().printLog(
      'Community report submission context status: ${response.statusCode}',
    );
    Utility().printLog(
      'Community report submission context body: ${response.body}',
    );
    Utility().printLog(
      'Community report submission context response: endpoint=$_submissionContextEndpoint status=${response.statusCode} body=${response.body}',
    );

    return response;
  }

  Future<http.Response> submitCommunityReport(
    Map<String, dynamic> payload,
    List<XFile> evidencePhotos,
  ) async {
    final token =
        await _secureStorage.read(key: _laravelSanctumTokenKey) ??
        await getCurrentToken();

    if (token == null || token.isEmpty) {
      throw Exception('No Laravel Sanctum token found.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_communityReportsEndpoint),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Municipality-Slug': 'gasan-4905',
    });
    request.fields.addAll(
      payload.map((key, value) {
        if (key == 'is_anonymous') {
          return MapEntry(key, value == true ? '1' : '0');
        }
        return MapEntry(key, value?.toString() ?? '');
      }),
    );

    for (final photo in evidencePhotos) {
      request.files.add(
        await http.MultipartFile.fromPath('evidence_photos[]', photo.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    Utility().printLog(
      'Community report submit status: ${response.statusCode}',
    );
    Utility().printLog('Community report submit body: ${response.body}');
    return response;
  }

  Future<http.Response> getCommunityReports() async {
    final token =
        await _secureStorage.read(key: _laravelSanctumTokenKey) ??
        await getCurrentToken();

    if (token == null || token.isEmpty) {
      throw Exception('No Laravel Sanctum token found.');
    }

    final response = await http.get(
      Uri.parse(_communityReportsEndpoint),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Municipality-Slug': 'gasan-4905',
      },
    );

    Utility().printLog('Community reports status: ${response.statusCode}');
    Utility().printLog('Community reports body: ${response.body}');
    return response;
  }

  Future<http.Response> getCommunityReportDetails(String reportId) async {
    final token =
        await _secureStorage.read(key: _laravelSanctumTokenKey) ??
        await getCurrentToken();

    if (token == null || token.isEmpty) {
      throw Exception('No Laravel Sanctum token found.');
    }

    final response = await http.get(
      Uri.parse('$_communityReportsEndpoint/$reportId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Municipality-Slug': 'gasan-4905',
      },
    );

    Utility().printLog(
      'Community report details status: ${response.statusCode}',
    );
    Utility().printLog('Community report details body: ${response.body}');
    return response;
  }

  Future<http.Response> getSupportTicketSubmissionContext() async {
    final token = await _requireLaravelToken();

    final response = await http.get(
      Uri.parse('$_supportTicketsEndpoint/submission-context'),
      headers: _laravelHeaders(token),
    );

    Utility().printLog(
      'Support ticket submission context status: ${response.statusCode}',
    );
    Utility().printLog(
      'Support ticket submission context body: ${response.body}',
    );
    return response;
  }

  Future<http.Response> getSupportTickets({
    int page = 1,
    int perPage = 10,
  }) async {
    final token = await _requireLaravelToken();
    final uri = Uri.parse(_supportTicketsEndpoint).replace(
      queryParameters: {
        'page': page.clamp(1, 999999).toString(),
        'per_page': perPage.clamp(1, 100).toString(),
      },
    );

    final response = await http.get(uri, headers: _laravelHeaders(token));

    Utility().printLog('Support tickets status: ${response.statusCode}');
    Utility().printLog('Support tickets body: ${response.body}');
    return response;
  }

  Future<http.Response> submitSupportTicket(
    Map<String, dynamic> payload,
  ) async {
    final token = await _requireLaravelToken();

    final response = await http.post(
      Uri.parse(_supportTicketsEndpoint),
      headers: _laravelHeaders(token, jsonBody: true),
      body: jsonEncode(payload),
    );

    Utility().printLog('Support ticket submit status: ${response.statusCode}');
    Utility().printLog('Support ticket submit body: ${response.body}');
    return response;
  }

  Future<http.Response> getSupportTicketDetails(String supportTicket) async {
    final token = await _requireLaravelToken();

    final response = await http.get(
      Uri.parse('$_supportTicketsEndpoint/$supportTicket'),
      headers: _laravelHeaders(token),
    );

    Utility().printLog('Support ticket details status: ${response.statusCode}');
    Utility().printLog('Support ticket details body: ${response.body}');
    return response;
  }

  Future<http.Response> replySupportTicket(
    String supportTicket,
    Map<String, dynamic> payload,
  ) async {
    final token = await _requireLaravelToken();

    final response = await http.post(
      Uri.parse('$_supportTicketsEndpoint/$supportTicket/replies'),
      headers: _laravelHeaders(token, jsonBody: true),
      body: jsonEncode(payload),
    );

    Utility().printLog('Support ticket reply status: ${response.statusCode}');
    Utility().printLog('Support ticket reply body: ${response.body}');
    return response;
  }

  Future<http.Response> reopenSupportTicket(String supportTicket) async {
    final token = await _requireLaravelToken();

    final response = await http.post(
      Uri.parse('$_supportTicketsEndpoint/$supportTicket/reopen'),
      headers: _laravelHeaders(token),
    );

    Utility().printLog('Support ticket reopen status: ${response.statusCode}');
    Utility().printLog('Support ticket reopen body: ${response.body}');
    return response;
  }

  Future<http.Response> getAnnouncements({
    int page = 1,
    int perPage = 10,
  }) async {
    final uri = Uri.parse(_announcementsEndpoint).replace(
      queryParameters: {
        'page': page.clamp(1, 999999).toString(),
        'per_page': perPage.clamp(1, 100).toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Municipality-Slug': 'gasan-4905',
      },
    );

    Utility().printLog('Announcements status: ${response.statusCode}');
    Utility().printLog('Announcements body: ${response.body}');
    return response;
  }

  Future<http.Response> getAnnouncementDetails(String announcementId) async {
    final response = await http.get(
      Uri.parse('$_announcementsEndpoint/$announcementId'),
      headers: {
        'Accept': 'application/json',
        'X-Municipality-Slug': 'gasan-4905',
      },
    );

    Utility().printLog('Announcement details status: ${response.statusCode}');
    Utility().printLog('Announcement details body: ${response.body}');
    return response;
  }

  Future<http.Response> getEvents({int page = 1, int perPage = 20}) async {
    final uri = Uri.parse(_eventsEndpoint).replace(
      queryParameters: {
        'page': page.clamp(1, 999999).toString(),
        'per_page': perPage.clamp(1, 100).toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Municipality-Slug': 'gasan-4905',
      },
    );

    Utility().printLog('Events status: ${response.statusCode}');
    Utility().printLog('Events body: ${response.body}');
    return response;
  }

  Future<http.Response> getEventDetails(String eventId) async {
    final response = await http.get(
      Uri.parse('$_eventsEndpoint/$eventId'),
      headers: {
        'Accept': 'application/json',
        'X-Municipality-Slug': 'gasan-4905',
      },
    );

    Utility().printLog('Event details status: ${response.statusCode}');
    Utility().printLog('Event details body: ${response.body}');
    return response;
  }

  Future<void> _storeTokenFromResponse({
    required String userId,
    required http.Response response,
  }) async {
    if (response.statusCode < 200 || response.statusCode >= 300) return;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return;

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return;

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) return;

    await _secureStorage.write(key: _tokenKeyForUser(userId), value: token);
    await _secureStorage.write(key: _laravelSanctumTokenKey, value: token);
    await _secureStorage.write(key: _currentUserIdKey, value: userId);
    await _secureStorage.write(key: _currentTokenKey, value: token);

    Utility().printLog('External auth bridge token stored for user: $userId');
  }

  Future<String?> getCurrentToken() {
    return _secureStorage.read(key: _currentTokenKey);
  }

  Future<String> _requireLaravelToken() async {
    final token =
        await _secureStorage.read(key: _laravelSanctumTokenKey) ??
        await getCurrentToken();

    if (token == null || token.isEmpty) {
      throw Exception('No Laravel Sanctum token found.');
    }

    return token;
  }

  Map<String, String> _laravelHeaders(String token, {bool jsonBody = false}) {
    return {
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Municipality-Slug': 'gasan-4905',
    };
  }

  Future<String?> getTokenForUser(String userId) {
    return _secureStorage.read(key: _tokenKeyForUser(userId));
  }

  Future<void> clearCurrentToken() async {
    await _secureStorage.delete(key: _laravelSanctumTokenKey);
    await _secureStorage.delete(key: _currentUserIdKey);
    await _secureStorage.delete(key: _currentTokenKey);
  }

  static String _tokenKeyForUser(String userId) {
    return 'external_auth_token_$userId';
  }
}
