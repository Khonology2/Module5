import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdh/config/env_config.dart';
import 'dart:async';

/// Service to handle backend API calls for token authentication
/// This service calls a backend endpoint to create Firebase custom tokens
///
/// Backend URL is hardcoded to: https://personal-development-backend.onrender.com
class BackendAuthService {
  BackendAuthService._internal();
  static final BackendAuthService instance = BackendAuthService._internal();
  static const Duration _httpTimeout = Duration(seconds: 90);
  static const List<Duration> _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];

  /// Backend API base URL for token authentication
  static String get _backendBaseUrl {
    final envUrl = EnvConfig.backendUrl;
    if (envUrl != null && envUrl.isNotEmpty) {
      debugPrint('Using env backend URL: $envUrl');
      return envUrl;
    }
    const String prodUrl = 'https://personal-development-backend.onrender.com';
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1') {
        const String devUrl = 'http://127.0.0.1:8000';
        debugPrint('Using local backend URL: $devUrl');
        return devUrl;
      }
    }
    debugPrint('Using production backend URL: $prodUrl');
    return prodUrl;
  }

  /// Backend base URL for use by firebase config fetch (no hardcoded keys on frontend).
  static String get backendBaseUrl => _backendBaseUrl;

  /// Fetches Firebase web client config from backend (projectId from service account JSON, apiKey/appId from env).
  /// Returns null if backend does not provide apiKey/appId or request fails.
  static Future<Map<String, dynamic>?> getFirebaseConfig() async {
    if (!kIsWeb) return null;
    try {
      final uri = Uri.parse('$backendBaseUrl/firebase-config');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      if (data == null) return null;
      final apiKey = data['apiKey']?.toString();
      final appId = data['appId']?.toString();
      final messagingSenderId = data['messagingSenderId']?.toString();
      if (apiKey == null ||
          apiKey.isEmpty ||
          appId == null ||
          appId.isEmpty ||
          messagingSenderId == null ||
          messagingSenderId.isEmpty) {
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _postWithRetry(
    String url,
    Map<String, dynamic> body,
  ) async {
    http.Response? lastResponse;
    for (var i = 0; i <= _retryDelays.length; i++) {
      try {
        final attemptWatch = Stopwatch()..start();
        debugPrint(
          'HTTP POST attempt ${i + 1}/${_retryDelays.length + 1} to $url',
        );
        final res = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(
              _httpTimeout,
              onTimeout: () {
                throw TimeoutException('Request timeout');
              },
            );
        attemptWatch.stop();
        debugPrint(
          'HTTP POST attempt ${i + 1} completed with status ${res.statusCode} in ${attemptWatch.elapsedMilliseconds} ms',
        );
        return res;
      } catch (e) {
        if (e is TimeoutException) {
          debugPrint('HTTP POST timeout on attempt ${i + 1} to $url');
        } else {
          debugPrint('HTTP POST error on attempt ${i + 1} to $url: $e');
        }
        if (e is TimeoutException) {
          await warmUpBackend();
        }
        if (i == _retryDelays.length) {
          rethrow;
        }
        await Future.delayed(_retryDelays[i]);
      }
    }
    return lastResponse!;
  }

  /// Get Firebase custom token from backend using the JWT token
  /// This allows us to sign in users without passwords
  ///
  /// The backend validates the JWT token, queries Firestore, and generates
  /// a Firebase custom token for secure auto-login.
  Future<String?> getCustomTokenFromBackend(String jwtToken) async {
    final baseUrl = _backendBaseUrl;

    try {
      final stopwatch = Stopwatch()..start();
      debugPrint('Custom token request started');
      // Call the /validate-token endpoint
      final endpointUrl = '$baseUrl/validate-token';
      debugPrint('Calling backend endpoint: $endpointUrl');

      final response = await _postWithRetry(endpointUrl, {'token': jwtToken});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Parse firebase_token from the new response format
        final firebaseToken = data['firebase_token'] as String?;
        if (firebaseToken == null || firebaseToken.isEmpty) {
          debugPrint(
            'Backend API returned 200 but firebase_token is missing or empty',
          );
          stopwatch.stop();
          debugPrint(
            'Custom token request completed in ${stopwatch.elapsedMilliseconds} ms',
          );
          return null;
        }
        debugPrint('Successfully received Firebase custom token from backend');
        stopwatch.stop();
        debugPrint(
          'Custom token request completed in ${stopwatch.elapsedMilliseconds} ms',
        );
        return firebaseToken;
      } else {
        // Parse error response if available
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          final error = errorData['error'] as String? ?? 'Unknown error';
          final detail = errorData['detail'] as String? ?? response.body;
          debugPrint(
            'Backend API error: ${response.statusCode} - $error: $detail',
          );
        } catch (_) {
          debugPrint(
            'Backend API error: ${response.statusCode} - ${response.body}',
          );
        }
        stopwatch.stop();
        debugPrint(
          'Custom token request completed in ${stopwatch.elapsedMilliseconds} ms',
        );
        return null;
      }
    } on TimeoutException catch (e) {
      debugPrint('Network timeout during custom token request: $e');
      return null;
    } catch (e) {
      debugPrint('Error getting custom token from backend: $e');
      return null;
    }
  }

  /// Sign in user with custom token from backend
  Future<UserCredential?> signInWithCustomToken(String jwtToken) async {
    try {
      final customToken = await getCustomTokenFromBackend(jwtToken);
      if (customToken == null) {
        return null;
      }

      final userCredential = await FirebaseAuth.instance.signInWithCustomToken(
        customToken,
      );
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with custom token: $e');
      return null;
    }
  }

  /// Validate token with backend API
  /// Returns the full response including firebase_token, user_id, email, and roles
  Future<Map<String, dynamic>?> validateTokenWithBackend(String token) async {
    final baseUrl = _backendBaseUrl;

    try {
      final stopwatch = Stopwatch()..start();
      debugPrint('Token validation started');
      final endpointUrl = '$baseUrl/validate-token';
      debugPrint('Calling backend validation endpoint: $endpointUrl');

      final response = await _postWithRetry(endpointUrl, {'token': token});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('Token validated successfully by backend');
        stopwatch.stop();
        debugPrint(
          'Token validation completed in ${stopwatch.elapsedMilliseconds} ms',
        );
        return data;
      } else {
        // Parse error response if available
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          final error = errorData['error'] as String? ?? 'Unknown error';
          final detail = errorData['detail'] as String? ?? response.body;
          debugPrint(
            'Backend validation error: ${response.statusCode} - $error: $detail',
          );
        } catch (_) {
          debugPrint(
            'Backend validation error: ${response.statusCode} - ${response.body}',
          );
        }
        stopwatch.stop();
        debugPrint(
          'Token validation completed in ${stopwatch.elapsedMilliseconds} ms',
        );
        return null;
      }
    } on TimeoutException catch (e) {
      debugPrint('Network timeout during token validation: $e');
      return null;
    } catch (e) {
      debugPrint('Error validating token with backend: $e');
      return null;
    }
  }

  /// Call authentication callback endpoint on backend
  /// This notifies the backend that authentication is complete and user is being navigated
  Future<bool> callAuthCallback({
    required String userId,
    required String email,
    required String role,
    required bool authenticated,
  }) async {
    final baseUrl = _backendBaseUrl;

    try {
      final endpointUrl = '$baseUrl/auth-callback';
      debugPrint('Calling auth callback endpoint: $endpointUrl');

      final response = await _postWithRetry(endpointUrl, {
        'user_id': userId,
        'email': email,
        'role': role,
        'authenticated': authenticated,
      });

      if (response.statusCode == 200) {
        debugPrint('Auth callback processed successfully');
        return true;
      } else {
        debugPrint(
          'Auth callback error: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error calling auth callback: $e');
      return false;
    }
  }

  Future<void> warmUpBackend() async {
    final baseUrl = _backendBaseUrl;
    final url = '$baseUrl/health';
    try {
      debugPrint('Warming up backend: $url');
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
