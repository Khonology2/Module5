import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;

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
  });

  final String firebaseToken;
  final String userId;
  final String email;
  final List<String> roles;
  final String? pdhRole;
  final String? theme;

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
  static const Duration _aiTimeout = Duration(seconds: 90);
  static const int _maxAttempts = 2;

  /// Base URL for PDH API (auth, Firebase config, AI proxy).
  static String get apiBaseUrl => _baseUrl;

  static const String _configuredBackendUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
  );

  static String get _baseUrl {
    final configured = _configuredBackendUrl.trim();
    if (configured.isNotEmpty) {
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }

    // Local dev (Flutter web on :6xxxx, API on :8000): always hit loopback API.
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final isLocalWebOrigin = origin.contains('localhost') ||
          origin.contains('127.0.0.1') ||
          origin.isEmpty ||
          origin == 'null';
      if (!isLocalWebOrigin) {
        // Production web build without --dart-define: API may share the site origin.
        return origin;
      }
    }

    return 'http://127.0.0.1:8000';
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
    final body = jsonEncode({'token': token});
    final response = await _postWithRetry(_uri('/validate-token'), body);
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

  /// Proxies OpenRouter through the backend so API keys stay in `backend/app/.env`.
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

  Future<http.Response> _postWithRetry(
    Uri uri,
    String body, {
    bool retryOnHttpFailure = true,
    Duration timeout = _timeout,
  }) async {
    BackendAuthException? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
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
        final timeoutError = BackendAuthException(
          message: 'Request timed out while contacting backend.',
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
