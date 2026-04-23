import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
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
  static const int _maxAttempts = 2;

  static String get _baseUrl {
    const configured = String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000',
    );
    final normalizedConfigured = configured.endsWith('/')
        ? configured.substring(0, configured.length - 1)
        : configured;

    final isLocalDefault =
        normalizedConfigured == 'http://127.0.0.1:8000' ||
        normalizedConfigured == 'http://localhost:8000';
    if (!isLocalDefault) return normalizedConfigured;

    if (kIsWeb) {
      // Deployment-safe fallback: if no explicit BACKEND_BASE_URL is injected,
      // use the current web origin instead of localhost.
      final origin = Uri.base.origin;
      if (origin.isNotEmpty &&
          origin != 'null' &&
          !origin.contains('localhost') &&
          !origin.contains('127.0.0.1')) {
        return origin;
      }
    }

    return normalizedConfigured;
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

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

  Future<http.Response> _postWithRetry(
    Uri uri,
    String body, {
    bool retryOnHttpFailure = true,
  }) async {
    BackendAuthException? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(_timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
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
