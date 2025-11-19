import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service to handle backend API calls for token authentication
/// This service calls a backend endpoint to create Firebase custom tokens
///
/// To configure your backend URL, set the BACKEND_API_URL environment variable
/// or update the _backendBaseUrl constant below.
/// If no backend URL is configured, the service will return null for custom token requests.
class BackendAuthService {
  BackendAuthService._internal();
  static final BackendAuthService instance = BackendAuthService._internal();

  /// Backend API base URL for token authentication
  /// Set this to your actual backend API URL, or leave as null if not using backend
  /// Example: 'https://api.yourdomain.com/api' or 'https://your-backend-api.com/api'
  ///
  /// You can also set this via environment variable BACKEND_API_URL
  static String? get _backendBaseUrl {
    // Get backend URL from .env file
    // Checks for BACKEND_API_URL first, then falls back to BACKEND_URL
    try {
      final envBackendUrl =
          dotenv.env['BACKEND_API_URL'] ?? dotenv.env['BACKEND_URL'];
      if (envBackendUrl != null && envBackendUrl.isNotEmpty) {
        debugPrint(
          'Backend URL loaded from environment variable: $envBackendUrl',
        );
        return envBackendUrl;
      } else {
        debugPrint('BACKEND_URL or BACKEND_API_URL not found in .env file');
      }
    } catch (e) {
      debugPrint('Error reading backend URL from .env: $e');
    }

    // Return null if not configured (service will handle gracefully)
    return null;
  }

  /// Get Firebase custom token from backend using the JWT token
  /// This allows us to sign in users without passwords
  /// Returns null if backend URL is not configured
  ///
  /// The backend validates the JWT token, queries Firestore, and generates
  /// a Firebase custom token for secure auto-login.
  Future<String?> getCustomTokenFromBackend(String jwtToken) async {
    final baseUrl = _backendBaseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      debugPrint(
        'Backend API URL not configured. Skipping custom token request.',
      );
      return null;
    }

    try {
      // Call the /validate-token endpoint
      final response = await http
          .post(
            Uri.parse('$baseUrl/validate-token'),
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

  /// Validate token with backend (optional - if you want backend validation)
  /// Returns false if backend URL is not configured
  Future<bool> validateTokenWithBackend(String token) async {
    final baseUrl = _backendBaseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      debugPrint('Backend API URL not configured. Skipping token validation.');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/validate-token'),
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
        return data['valid'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error validating token with backend: $e');
      return false;
    }
  }
}
