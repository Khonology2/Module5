import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:pdh/utils/pdh_backend_url_reader.dart';

class BackendAuthException implements Exception {
  BackendAuthException({
    required this.message,
    this.statusCode,
    this.code = 'backend_error',
    this.retryable = false,
  });

  final String message;
  final int? statusCode;
  final String code;
  final bool retryable;

  @override
  String toString() => 'BackendAuthException($code, $statusCode): $message';
}

class ValidateTokenResponse {
  const ValidateTokenResponse({
    required this.firebaseToken,
    required this.userId,
    required this.email,
    required this.roles,
    this.pdhRole,
    this.theme,
    this.displayName,
  });

  final String firebaseToken;
  final String userId;
  final String email;
  final List<String> roles;
  final String? pdhRole;
  final String? theme;
  final String? displayName;

  factory ValidateTokenResponse.fromJson(Map<String, dynamic> json) {
    final rolesRaw = json['roles'];
    final roles = rolesRaw is List
        ? rolesRaw.map((e) => e.toString()).toList()
        : <String>[];

    return ValidateTokenResponse(
      firebaseToken: (json['firebase_token'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      roles: roles,
      pdhRole: json['pdh_role']?.toString(),
      theme: json['theme']?.toString(),
      displayName: json['display_name']?.toString(),
    );
  }
}

class AuthCallbackPayload {
  const AuthCallbackPayload({
    required this.userId,
    required this.email,
    required this.role,
    required this.authenticated,
  });

  final String userId;
  final String? email;
  final String? role;
  final bool authenticated;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'role': role,
      'authenticated': authenticated,
    };
  }
}

class FirebaseConfigResponse {
  const FirebaseConfigResponse({
    required this.projectId,
    required this.authDomain,
    required this.storageBucket,
    required this.apiKey,
    required this.appId,
    this.messagingSenderId,
  });

  final String projectId;
  final String authDomain;
  final String storageBucket;
  final String apiKey;
  final String appId;
  final String? messagingSenderId;

  bool get isComplete =>
      projectId.isNotEmpty &&
      authDomain.isNotEmpty &&
      storageBucket.isNotEmpty &&
      apiKey.isNotEmpty &&
      appId.isNotEmpty;

  factory FirebaseConfigResponse.fromJson(Map<String, dynamic> json) {
    return FirebaseConfigResponse(
      projectId: (json['projectId'] ?? '').toString(),
      authDomain: (json['authDomain'] ?? '').toString(),
      storageBucket: (json['storageBucket'] ?? '').toString(),
      apiKey: (json['apiKey'] ?? '').toString(),
      appId: (json['appId'] ?? '').toString(),
      messagingSenderId: json['messagingSenderId']?.toString(),
    );
  }
}

class BackendAuthService {
  BackendAuthService._();

  static final BackendAuthService instance = BackendAuthService._();
  static const Duration _timeout = Duration(seconds: 12);
  static const Duration _mutationTimeout = Duration(seconds: 45);
  static const Duration _validateTokenTimeout = Duration(seconds: 45);
  static const Duration _aiTimeout = Duration(seconds: 90);
  static const int _maxAttempts = 2;
  static const int _mutationMaxAttempts = 3;

  /// Base URL for PDH API (auth, Firebase config, AI proxy).
  static String get apiBaseUrl => _baseUrl;

  static const String _configuredBackendUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
  );

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String get _baseUrl {
    final configured = _normalizeBaseUrl(_configuredBackendUrl);
    if (configured.isNotEmpty) return configured;

    if (kIsWeb) {
      final fromMeta = _normalizeBaseUrl(readBackendBaseUrlFromWebMeta() ?? '');
      if (fromMeta.isNotEmpty) return fromMeta;

      final origin = Uri.base.origin;
      final isLocalWebOrigin = origin.contains('localhost') ||
          origin.contains('127.0.0.1') ||
          origin.isEmpty ||
          origin == 'null';
      if (isLocalWebOrigin) {
        return 'http://127.0.0.1:8000';
      }
    }

    return 'http://127.0.0.1:8000';
  }

  static bool get hasExplicitBackendUrl {
    if (_configuredBackendUrl.trim().isNotEmpty) return true;
    if (kIsWeb) {
      final meta = (readBackendBaseUrlFromWebMeta() ?? '').trim();
      if (meta.isNotEmpty) return true;
    }
    return false;
  }

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$p');
  }

  void _logBackendRequest(String method, Uri uri, {int? statusCode, String? note}) {
    if (!kDebugMode) return;
    final status = statusCode != null ? ' -> $statusCode' : '';
    final extra = note != null ? ' ($note)' : '';
    // ignore: avoid_print
    print('[PDH API] $method $uri$status$extra');
  }

  Future<ValidateTokenResponse> validateTokenWithBackend(String token) async {
    if (kIsWeb && !hasExplicitBackendUrl) {
      final origin = Uri.base.origin;
      final isLocal = origin.contains('localhost') ||
          origin.contains('127.0.0.1') ||
          origin.isEmpty ||
          origin == 'null';
      if (!isLocal) {
        throw BackendAuthException(
          message:
              'Backend API URL is not configured for this build. Set GitHub secret BACKEND_BASE_URL to your Render Python API URL and redeploy.',
          code: 'backend_not_configured',
        );
      }
    }

    final body = jsonEncode({'token': token});
    final response = await _postWithRetry(
      _uri('/validate-token'),
      body,
      timeout: _validateTokenTimeout,
    );
    final decoded = _decodeBody(response.body);
    final model = ValidateTokenResponse.fromJson(decoded);

    if (model.firebaseToken.isEmpty) {
      throw BackendAuthException(
        message: 'Missing firebase token in backend response.',
        statusCode: response.statusCode,
        code: 'invalid_response',
      );
    }

    return model;
  }

  Future<void> callAuthCallback(AuthCallbackPayload payload) async {
    final body = jsonEncode(payload.toJson());
    final response = await _postWithRetry(
      _uri('/auth-callback'),
      body,
      retryOnHttpFailure: false,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(statusCode: response.statusCode, body: response.body);
    }
  }

  Future<FirebaseConfigResponse> getFirebaseConfig() async {
    http.Response response;
    try {
      response = await http.get(_uri('/firebase-config')).timeout(_timeout);
    } on TimeoutException {
      throw BackendAuthException(
        message: 'Timed out while fetching Firebase config from backend.',
        code: 'timeout',
        retryable: true,
      );
    } catch (_) {
      throw BackendAuthException(
        message: 'Unable to reach backend for Firebase config.',
        code: 'network_error',
        retryable: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(statusCode: response.statusCode, body: response.body);
    }

    return FirebaseConfigResponse.fromJson(_decodeBody(response.body));
  }

  /// Proxies the backend AI provider through the server so API keys stay in
  /// `backend/app/.env`.
  Future<String> generateAiChat({
    String? systemInstruction,
    required List<Map<String, String>> messages,
  }) async {
    if (messages.isEmpty) {
      throw BackendAuthException(
        message: 'AI request has no messages.',
        code: 'bad_request',
      );
    }

    final body = jsonEncode({
      'system_instruction': systemInstruction,
      'messages': messages,
    });

    final uri = _uri('/ai/chat');
    _logBackendRequest('POST', uri, note: '${messages.length} message(s)');

    final response = await _postWithRetry(
      uri,
      body,
      timeout: _aiTimeout,
    );

    _logBackendRequest(
      'POST',
      uri,
      statusCode: response.statusCode,
      note: 'AI response ${response.body.length} bytes',
    );

    final decoded = _decodeBody(response.body);
    final text = (decoded['text'] ?? '').toString().trim();
    if (text.isEmpty) {
      throw BackendAuthException(
        message: 'Backend returned empty AI response.',
        code: 'invalid_response',
      );
    }
    return text;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Duration? timeout,
  }) async {
    final uri = _uri(path);
    final effectiveTimeout = timeout ?? _timeout;
    try {
      final response = await http.get(uri).timeout(effectiveTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _mapHttpError(statusCode: response.statusCode, body: response.body);
      }
      return _decodeBody(response.body);
    } on TimeoutException {
      throw BackendAuthException(
        message: 'Request timed out while contacting backend.',
        code: 'timeout',
        retryable: true,
      );
    } catch (e) {
      if (e is BackendAuthException) rethrow;
      throw BackendAuthException(
        message: 'Network error while contacting backend.',
        code: 'network_error',
        retryable: true,
      );
    }
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final uri = _uri(path);
    http.Response response;
    try {
      response = await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw BackendAuthException(
        message: 'Request timed out while contacting backend.',
        code: 'timeout',
        retryable: true,
      );
    } catch (_) {
      throw BackendAuthException(
        message: 'Network error while contacting backend.',
        code: 'network_error',
        retryable: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(statusCode: response.statusCode, body: response.body);
    }
    return _decodeBody(response.body);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> payload, {
    Duration? timeout,
    int? maxAttempts,
  }) async {
    final response = await _postWithRetry(
      _uri(path),
      jsonEncode(payload),
      timeout: timeout ?? _mutationTimeout,
      maxAttempts: maxAttempts ?? _mutationMaxAttempts,
    );
    return _decodeBody(response.body);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _patchWithRetry(
      _uri(path),
      jsonEncode(payload),
      timeout: _mutationTimeout,
      maxAttempts: _mutationMaxAttempts,
    );
    return _decodeBody(response.body);
  }

  Future<Map<String, dynamic>> getUser(String userId) {
    return getJson('/users/$userId');
  }

  Future<Map<String, dynamic>> getUserSettings(String userId) {
    return getJson('/users/$userId/settings');
  }

  Future<Map<String, dynamic>> updateUserSettings(
    String userId,
    Map<String, dynamic> payload,
  ) {
    return putJson('/users/$userId/settings', payload);
  }

  Future<Map<String, dynamic>> updateUserProfile(
    String userId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/users/$userId', payload);
  }

  Future<Map<String, dynamic>> getOnboarding(String userId) {
    return getJson('/onboarding/$userId');
  }

  /// Returns onboarding record or empty map when not found (PostgreSQL).
  Future<Map<String, dynamic>> tryGetOnboarding(String userId) async {
    try {
      return await getOnboarding(userId);
    } on BackendAuthException catch (e) {
      if (e.statusCode == 404) return {};
      rethrow;
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> listOnboarding({
    String? email,
    int limit = 500,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };
    final decoded = await getJson('/onboarding?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> updateOnboarding(
    String userId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/onboarding/$userId', payload);
  }

  Future<Map<String, dynamic>> patchGoal(
    String goalId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/goals/$goalId', payload);
  }

  Future<List<Map<String, dynamic>>> getGoals({
    String? userId,
    String? goalId,
    String? status,
    int limit = 200,
  }) async {
    final query = <String, String>{
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      if (goalId != null && goalId.isNotEmpty) 'goal_id': goalId,
      if (status != null && status.isNotEmpty) 'status': status,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/goals?${Uri(queryParameters: query).query}');
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> patchAuditEntry(
    String entryId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/audit-entries/$entryId', payload);
  }

  Future<Map<String, dynamic>> createAuditEntry(
    Map<String, dynamic> payload,
  ) {
    return postJson('/audit-entries', payload);
  }

  Future<Map<String, dynamic>> getAuditEntry(String entryId) {
    return getJson('/audit-entries/$entryId');
  }

  Future<List<Map<String, dynamic>>> getAuditEntries({
    String? userId,
    String? department,
    String? status,
    String? goalId,
    String? entryId,
    int limit = 200,
  }) async {
    final query = <String, String>{
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      if (department != null && department.isNotEmpty) 'department': department,
      if (status != null && status.isNotEmpty) 'status': status,
      if (goalId != null && goalId.isNotEmpty) 'goal_id': goalId,
      if (entryId != null && entryId.isNotEmpty) 'entry_id': entryId,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/audit-entries?${Uri(queryParameters: query).query}');
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createActivity(
    String userId,
    Map<String, dynamic> payload,
  ) {
    return postJson('/activities/$userId', payload);
  }

  Future<List<Map<String, dynamic>>> getActivities(
    String userId, {
    int limit = 50,
  }) async {
    final decoded = await getJson('/activities/$userId?limit=$limit');
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createApprovedGoalAudit(
    Map<String, dynamic> payload,
  ) {
    return postJson('/approved-goals-audit', payload);
  }

  Future<List<Map<String, dynamic>>> getApprovedGoalAudits({
    String? userId,
    String? employeeId,
    String? goalId,
    int limit = 500,
  }) async {
    final query = <String, String>{
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      if (employeeId != null && employeeId.isNotEmpty) 'employee_id': employeeId,
      if (goalId != null && goalId.isNotEmpty) 'goal_id': goalId,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/approved-goals-audit?${Uri(queryParameters: query).query}');
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> getApprovedGoalAudit(String goalId) {
    return getJson('/approved-goals-audit/$goalId');
  }

  Future<List<Map<String, dynamic>>> getAuditTimeline(
    String entryId, {
    int limit = 100,
  }) async {
    final decoded = await getJson('/audit-entries/$entryId/timeline?limit=$limit');
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> addAuditTimelineEvent(
    String entryId,
    Map<String, dynamic> payload,
  ) {
    return postJson('/audit-entries/$entryId/timeline', payload);
  }

  Future<List<Map<String, dynamic>>> getBadges(
    String userId, {
    int limit = 500,
  }) async {
    final decoded = await getJson('/badges/$userId?limit=$limit');
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> upsertBadge(
    String userId,
    String badgeId,
    Map<String, dynamic> payload,
  ) {
    return postJson('/badges/$userId/$badgeId', payload);
  }

  Future<Map<String, dynamic>> patchBadge(
    String userId,
    String badgeId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/badges/$userId/$badgeId', payload);
  }

  Future<List<Map<String, dynamic>>> getAlerts(
    String userId, {
    int limit = 100,
  }) async {
    final decoded = await getJson('/alerts/$userId?limit=$limit');
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createAlert(
    String userId,
    Map<String, dynamic> payload,
  ) {
    return postJson('/alerts/$userId', payload);
  }

  Future<List<Map<String, dynamic>>> getRepositories(String userId) async {
    final decoded = await getJson('/repositories/$userId');
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> getAllRepositories() async {
    final decoded = await getJson('/repositories');
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> upsertRepository(
    String userId,
    Map<String, dynamic> payload,
  ) {
    return postJson('/repositories/$userId', payload);
  }

  List<Map<String, dynamic>> _itemsFromResponse(
    Map<String, dynamic> decoded,
  ) {
    final list = decoded['items'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> listUsers({
    String? role,
    String? department,
    int limit = 500,
  }) async {
    final query = <String, String>{
      if (role != null && role.isNotEmpty) 'role': role,
      if (department != null && department.isNotEmpty) 'department': department,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/users?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<List<String>> getDeletedAccountIds({int limit = 2000}) async {
    final decoded = await getJson('/deleted-accounts?limit=$limit');
    final list = decoded['items'];
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createGoal(Map<String, dynamic> payload) {
    return postJson('/goals', payload);
  }

  Future<void> deleteGoal(String goalId) async {
    final uri = _uri('/goals/$goalId');
    final response = await http.delete(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(statusCode: response.statusCode, body: response.body);
    }
  }

  Future<List<Map<String, dynamic>>> getMilestones({
    String? goalId,
    String? userId,
    int limit = 500,
  }) async {
    final query = <String, String>{
      if (goalId != null && goalId.isNotEmpty) 'goal_id': goalId,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/milestones?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> createMilestone(Map<String, dynamic> payload) {
    return postJson('/milestones', payload);
  }

  Future<Map<String, dynamic>> patchMilestone(
    String milestoneId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/milestones/$milestoneId', payload);
  }

  Future<void> deleteMilestone(String milestoneId) async {
    final uri = _uri('/milestones/$milestoneId');
    final response = await http.delete(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(statusCode: response.statusCode, body: response.body);
    }
  }

  Future<List<Map<String, dynamic>>> getMilestoneEvidence({
    String? goalId,
    String? milestoneId,
    String? userId,
    int limit = 500,
  }) async {
    final query = <String, String>{
      if (goalId != null && goalId.isNotEmpty) 'goal_id': goalId,
      if (milestoneId != null && milestoneId.isNotEmpty) 'milestone_id': milestoneId,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/milestone-evidence?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> createMilestoneEvidence(
    Map<String, dynamic> payload,
  ) {
    return postJson('/milestone-evidence', payload);
  }

  Future<Map<String, dynamic>> patchMilestoneEvidence(
    String itemId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/milestone-evidence/$itemId', payload);
  }

  Future<List<Map<String, dynamic>>> getEvidenceFiles({
    String? goalId,
    String? auditEntryId,
    String? userId,
    int limit = 500,
  }) async {
    final query = <String, String>{
      if (goalId != null && goalId.isNotEmpty) 'goal_id': goalId,
      if (auditEntryId != null && auditEntryId.isNotEmpty) 'audit_entry_id': auditEntryId,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/evidence-files?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> createEvidenceFile(
    Map<String, dynamic> payload,
  ) {
    return postJson('/evidence-files', payload);
  }

  Future<Map<String, dynamic>> patchEvidenceFile(
    String itemId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/evidence-files/$itemId', payload);
  }

  Future<void> deleteEvidenceFile(String itemId) async {
    final uri = _uri('/evidence-files/$itemId');
    final response = await http.delete(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(statusCode: response.statusCode, body: response.body);
    }
  }

  Future<Map<String, dynamic>> patchAlert(
    String userId,
    String alertId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/alerts/$userId/$alertId', payload);
  }

  Future<List<Map<String, dynamic>>> patchAlertsBatch(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final decoded = await patchJson('/alerts/$userId/batch', payload);
    return _itemsFromResponse(decoded);
  }

  Future<List<Map<String, dynamic>>> getSeasons({
    String? userId,
    String? status,
    String? seasonId,
    int limit = 200,
  }) async {
    final query = <String, String>{
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (seasonId != null && seasonId.isNotEmpty) 'season_id': seasonId,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/seasons?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> getSeason(String seasonId) {
    return getJson('/seasons/$seasonId');
  }

  Future<Map<String, dynamic>> createSeason(Map<String, dynamic> payload) {
    return postJson('/seasons', payload);
  }

  Future<Map<String, dynamic>> patchSeason(
    String seasonId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/seasons/$seasonId', payload);
  }

  Future<void> deleteSeason(String seasonId) async {
    final uri = _uri('/seasons/$seasonId');
    final response = await http.delete(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(statusCode: response.statusCode, body: response.body);
    }
  }

  Future<List<Map<String, dynamic>>> getOneOnOneMeetings({
    String? employeeId,
    String? managerId,
    String? meetingId,
    int limit = 200,
  }) async {
    final query = <String, String>{
      if (employeeId != null && employeeId.isNotEmpty) 'employee_id': employeeId,
      if (managerId != null && managerId.isNotEmpty) 'manager_id': managerId,
      if (meetingId != null && meetingId.isNotEmpty) 'meeting_id': meetingId,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/one-on-one-meetings?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> createOneOnOneMeeting(
    Map<String, dynamic> payload,
  ) {
    return postJson('/one-on-one-meetings', payload);
  }

  Future<Map<String, dynamic>> patchOneOnOneMeeting(
    String meetingId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/one-on-one-meetings/$meetingId', payload);
  }

  Future<List<Map<String, dynamic>>> getManagerActions(
    String managerId, {
    int limit = 500,
  }) async {
    final decoded = await getJson('/manager-actions/$managerId?limit=$limit');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> createManagerAction(
    String managerId,
    Map<String, dynamic> payload,
  ) {
    return postJson('/manager-actions/$managerId', payload);
  }

  static const Duration _learningDashboardTimeout = Duration(seconds: 90);

  Future<Map<String, dynamic>> getLearningManagerDashboard(
    String managerId, {
    int limit = 500,
  }) {
    final query = Uri(queryParameters: {
      'manager_id': managerId,
      'limit': limit.toString(),
    }).query;
    return getJson(
      '/learning-manager-dashboard?$query',
      timeout: _learningDashboardTimeout,
    );
  }

  Future<List<Map<String, dynamic>>> getLearningTutorials(
    String managerId, {
    String? status,
    int limit = 500,
  }) async {
    final query = <String, String>{
      'manager_id': managerId,
      'limit': limit.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final decoded = await getJson(
      '/learning-tutorials?${Uri(queryParameters: query).query}',
    );
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> createLearningTutorial(
    Map<String, dynamic> payload,
  ) {
    return postJson(
      '/learning-tutorials',
      payload,
      timeout: const Duration(seconds: 120),
      maxAttempts: 2,
    );
  }

  Future<Map<String, dynamic>> patchLearningTutorial(
    String tutorialId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/learning-tutorials/$tutorialId', payload);
  }

  Future<Map<String, dynamic>> getLearningTutorial(String tutorialId) {
    return getJson('/learning-tutorials/$tutorialId');
  }

  Future<List<Map<String, dynamic>>> getLearningAssignments({
    String? managerId,
    String? employeeUserId,
    String? status,
    int limit = 500,
    bool enrichTutorial = false,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      if (managerId != null && managerId.isNotEmpty) 'manager_id': managerId,
      if (employeeUserId != null && employeeUserId.isNotEmpty)
        'employee_user_id': employeeUserId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (enrichTutorial) 'enrich_tutorial': 'true',
    };
    final decoded = await getJson(
      '/learning-assignments?${Uri(queryParameters: query).query}',
    );
    return _itemsFromResponse(decoded);
  }

  Future<List<Map<String, dynamic>>> getLearningAssignmentsForEmployee(
    String employeeUserId, {
    String? status,
    int limit = 500,
    bool enrichTutorial = true,
  }) {
    return getLearningAssignments(
      employeeUserId: employeeUserId,
      status: status,
      limit: limit,
      enrichTutorial: enrichTutorial,
    );
  }

  Future<Map<String, dynamic>> createLearningAssignment(
    Map<String, dynamic> payload,
  ) {
    return postJson('/learning-assignments', payload);
  }

  Future<Map<String, dynamic>> patchLearningAssignment(
    String assignmentId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/learning-assignments/$assignmentId', payload);
  }

  Future<List<Map<String, dynamic>>> getDailyActivities(
    String userId, {
    int limit = 400,
  }) async {
    final decoded = await getJson('/daily-activities/$userId?limit=$limit');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> createDailyActivity(
    String userId,
    Map<String, dynamic> payload,
  ) {
    return postJson('/daily-activities/$userId', payload);
  }

  Future<Map<String, dynamic>> patchDailyActivity(
    String userId,
    String activityId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/daily-activities/$userId/$activityId', payload);
  }

  Future<Map<String, dynamic>> patchUserStreak(
    String userId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/users/$userId/streak', payload);
  }

  Future<List<Map<String, dynamic>>> getGoalDailyProgress({
    String? goalId,
    String? userId,
    int limit = 500,
  }) async {
    final query = <String, String>{
      if (goalId != null && goalId.isNotEmpty) 'goal_id': goalId,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/goal-daily-progress?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> createGoalDailyProgress(
    Map<String, dynamic> payload,
  ) {
    return postJson('/goal-daily-progress', payload);
  }

  Future<List<Map<String, dynamic>>> getPointEvents({
    String? userId,
    int limit = 500,
  }) async {
    final query = <String, String>{
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'limit': limit.toString(),
    };
    final decoded = await getJson('/point-events?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> createPointEvent(Map<String, dynamic> payload) {
    return postJson('/point-events', payload);
  }

  Future<List<Map<String, dynamic>>> getCollectionItems(
    String collection, {
    String? userId,
    String? goalId,
    String? status,
    String? action,
    bool includeActions = false,
    int limit = 500,
  }) async {
    final query = <String, String>{
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      if (goalId != null && goalId.isNotEmpty) 'goal_id': goalId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (action != null && action.isNotEmpty) 'action': action,
      if (includeActions) 'include_actions': 'true',
      'limit': limit.toString(),
    };
    final decoded = await getJson('/collections/$collection?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<Map<String, dynamic>> getCollectionItem(
    String collection,
    String itemId,
  ) {
    return getJson('/collections/$collection/$itemId');
  }

  Future<Map<String, dynamic>> createCollectionItem(
    String collection,
    Map<String, dynamic> payload,
  ) {
    return postJson('/collections/$collection', payload);
  }

  Future<Map<String, dynamic>> patchCollectionItem(
    String collection,
    String itemId,
    Map<String, dynamic> payload,
  ) {
    return patchJson('/collections/$collection/$itemId', payload);
  }

  Future<void> deleteCollectionItem(String collection, String itemId) async {
    final uri = _uri('/collections/$collection/$itemId');
    final response = await http.delete(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(statusCode: response.statusCode, body: response.body);
    }
  }

  Future<List<Map<String, dynamic>>> getAuditEntriesWithActions({
    String? userId,
    String? department,
    String? status,
    String? goalId,
    String? action,
    bool includeActions = true,
    int limit = 200,
  }) async {
    final query = <String, String>{
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      if (department != null && department.isNotEmpty) 'department': department,
      if (status != null && status.isNotEmpty) 'status': status,
      if (goalId != null && goalId.isNotEmpty) 'goal_id': goalId,
      if (action != null && action.isNotEmpty) 'action': action,
      if (includeActions) 'include_actions': 'true',
      'limit': limit.toString(),
    };
    final decoded = await getJson('/audit-entries?${Uri(queryParameters: query).query}');
    return _itemsFromResponse(decoded);
  }

  Future<void> deleteRepository(String userId, String repoId) async {
    final uri = _uri('/repositories/$userId/$repoId');
    http.Response response;
    try {
      response = await http.delete(uri).timeout(_timeout);
    } on TimeoutException {
      throw BackendAuthException(
        message: 'Request timed out while contacting backend.',
        code: 'timeout',
        retryable: true,
      );
    } catch (_) {
      throw BackendAuthException(
        message: 'Network error while contacting backend.',
        code: 'network_error',
        retryable: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpError(statusCode: response.statusCode, body: response.body);
    }
  }

  Future<http.Response> _patchWithRetry(
    Uri uri,
    String body, {
    bool retryOnHttpFailure = true,
    Duration timeout = _mutationTimeout,
    int maxAttempts = _mutationMaxAttempts,
  }) async {
    BackendAuthException? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (attempt > 1 && kDebugMode) {
          _logBackendRequest('PATCH', uri, note: 'retry $attempt');
        }
        final response = await http
            .patch(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        if (kDebugMode) {
          _logBackendRequest('PATCH', uri, statusCode: response.statusCode);
        }

        final mapped = _mapHttpError(
          statusCode: response.statusCode,
          body: response.body,
        );
        if (!retryOnHttpFailure ||
            !mapped.retryable ||
            attempt == maxAttempts) {
          throw mapped;
        }
        lastError = mapped;
      } on TimeoutException {
        final timeoutError = BackendAuthException(
          message: 'Request timed out while contacting backend.',
          code: 'timeout',
          retryable: true,
        );
        if (attempt == maxAttempts) throw timeoutError;
        lastError = timeoutError;
      } on BackendAuthException {
        rethrow;
      } catch (_) {
        final networkError = BackendAuthException(
          message: 'Network error while contacting backend.',
          code: 'network_error',
          retryable: true,
        );
        if (attempt == maxAttempts) throw networkError;
        lastError = networkError;
      }

      await Future.delayed(Duration(milliseconds: 400 * attempt));
    }

    throw lastError ??
        BackendAuthException(message: 'Backend request failed unexpectedly.');
  }

  Future<http.Response> _postWithRetry(
    Uri uri,
    String body, {
    bool retryOnHttpFailure = true,
    Duration timeout = _timeout,
    int maxAttempts = _maxAttempts,
  }) async {
    BackendAuthException? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (attempt > 1 && kDebugMode) {
          _logBackendRequest('POST', uri, note: 'retry $attempt');
        }
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        if (kDebugMode) {
          _logBackendRequest('POST', uri, statusCode: response.statusCode);
        }

        final mapped = _mapHttpError(
          statusCode: response.statusCode,
          body: response.body,
        );
        if (!retryOnHttpFailure ||
            !mapped.retryable ||
            attempt == _maxAttempts) {
          throw mapped;
        }
        lastError = mapped;
      } on TimeoutException {
        final apiHint = hasExplicitBackendUrl
            ? ' ($_baseUrl)'
            : ' — set BACKEND_BASE_URL to your Python API (not the static web URL).';
        final timeoutError = BackendAuthException(
          message:
              'Request timed out while contacting backend$apiHint',
          code: 'timeout',
          retryable: true,
        );
        if (attempt == _maxAttempts) throw timeoutError;
        lastError = timeoutError;
      } on BackendAuthException {
        rethrow;
      } catch (_) {
        final networkError = BackendAuthException(
          message: 'Network error while contacting backend.',
          code: 'network_error',
          retryable: true,
        );
        if (attempt == _maxAttempts) throw networkError;
        lastError = networkError;
      }

      await Future.delayed(Duration(milliseconds: 300 * attempt));
    }

    throw lastError ??
        BackendAuthException(message: 'Backend request failed unexpectedly.');
  }

  BackendAuthException _mapHttpError({
    required int statusCode,
    required String body,
  }) {
    final parsed = _decodeBodySafe(body);
    final detail = (parsed?['detail'] ?? parsed?['error'] ?? '')
        .toString()
        .trim();
    final fallbackDetail = detail.isEmpty
        ? 'Request failed with $statusCode.'
        : detail;

    switch (statusCode) {
      case 400:
        return BackendAuthException(
          message: 'Invalid token request. $fallbackDetail',
          statusCode: statusCode,
          code: 'bad_request',
        );
      case 401:
        return BackendAuthException(
          message:
              'Your SSO token is invalid or expired. Please request a new login link.',
          statusCode: statusCode,
          code: 'invalid_token',
        );
      case 403:
        return BackendAuthException(
          message: 'Your account is inactive. Please contact support.',
          statusCode: statusCode,
          code: 'inactive_user',
        );
      case 404:
        return BackendAuthException(
          message: 'User account was not found in backend records.',
          statusCode: statusCode,
          code: 'user_not_found',
        );
      case 408:
      case 429:
      case 500:
      case 502:
      case 503:
      case 504:
        return BackendAuthException(
          message: 'Backend is temporarily unavailable. Please try again.',
          statusCode: statusCode,
          code: 'backend_unavailable',
          retryable: true,
        );
      default:
        return BackendAuthException(
          message: fallbackDetail,
          statusCode: statusCode,
          code: 'backend_error',
        );
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      return jsonMap;
    } catch (_) {
      throw BackendAuthException(
        message: 'Failed to parse backend response.',
        code: 'invalid_response',
      );
    }
  }

  Map<String, dynamic>? _decodeBodySafe(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
