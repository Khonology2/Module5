import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service to handle backend API calls for token authentication
/// This service calls a backend endpoint to create Firebase custom tokens
///
/// Backend URL is hardcoded to: https://pdh-backend.onrender.com
class BackendAuthService {
  BackendAuthService._internal();
  static final BackendAuthService instance = BackendAuthService._internal();

  /// Backend API base URL for token authentication
  /// Hardcoded to use the production backend URL: https://pdh-backend.onrender.com
  static String get _backendBaseUrl {
    // Hardcoded production backend URL
    const String backendUrl = 'https://pdh-backend.onrender.com';
    debugPrint('Using hardcoded backend URL: $backendUrl');
    return backendUrl;
  }

  /// Get Firebase custom token from backend using the JWT token
  /// This allows us to sign in users without passwords
  ///
  /// The backend validates the JWT token, queries Firestore, and generates
  /// a Firebase custom token for secure auto-login.
  Future<String?> getCustomTokenFromBackend(String jwtToken) async {
    final baseUrl = _backendBaseUrl;

    try {
      // Call the /validate-token endpoint
      final endpointUrl = '$baseUrl/validate-token';
      debugPrint('Calling backend endpoint: $endpointUrl');

      final response = await http
          .post(
            Uri.parse(endpointUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': jwtToken}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Parse firebase_token from the new response format
        final firebaseToken = data['firebase_token'] as String?;
        if (firebaseToken == null || firebaseToken.isEmpty) {
          debugPrint(
            'Backend API returned 200 but firebase_token is missing or empty',
          );
          return null;
        }
        debugPrint('Successfully received Firebase custom token from backend');
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
        return null;
      }
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
      final endpointUrl = '$baseUrl/validate-token';
      debugPrint('Calling backend validation endpoint: $endpointUrl');

      final response = await http
          .post(
            Uri.parse(endpointUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('Token validated successfully by backend');
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
        return null;
      }
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

      final response = await http
          .post(
            Uri.parse(endpointUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'email': email,
              'role': role,
              'authenticated': authenticated,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

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
}
