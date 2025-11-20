import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Service to handle token extraction from URL
/// All token validation is now handled by the backend API
class TokenAuthService {
  TokenAuthService._internal();
  static final TokenAuthService instance = TokenAuthService._internal();

  /// Extract token from URL query parameters
  /// Supports both web (dart:html) and mobile (deep links)
  /// Automatically handles URL encoding/decoding
  static Future<String?> extractTokenFromUrl() async {
    try {
      if (kIsWeb) {
        // For web, use Uri to parse current URL
        final uri = Uri.base;

        // Try to get token from query parameters
        String? token = uri.queryParameters['token'];

        // If token is found, decode it (in case it's URL-encoded)
        if (token != null && token.isNotEmpty) {
          // Uri.queryParameters already decodes URL-encoded values, but let's ensure it's clean
          token = Uri.decodeComponent(token);
          debugPrint(
            'Token extracted from query parameters: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
          );
          return token;
        }

        // Also check hash fragment for SPA routing (common in single-page apps)
        final hash = uri.fragment;
        if (hash.isNotEmpty) {
          // Try to parse hash as query string
          if (hash.contains('token=')) {
            final hashParams = Uri.splitQueryString(hash);
            token = hashParams['token'];
            if (token != null && token.isNotEmpty) {
              token = Uri.decodeComponent(token);
              debugPrint(
                'Token extracted from hash fragment: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
              );
              return token;
            }
          }
        }

        // Also check the full URL string in case token is embedded differently
        final fullUrl = uri.toString();
        if (fullUrl.contains('token=')) {
          final urlUri = Uri.parse(fullUrl);
          token = urlUri.queryParameters['token'];
          if (token != null && token.isNotEmpty) {
            token = Uri.decodeComponent(token);
            debugPrint(
              'Token extracted from full URL: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
            );
            return token;
          }
        }

        debugPrint('No token found in URL');
        return null;
      } else {
        // For mobile, check if we have a stored initial link
        // This would be set when app is opened via deep link
        // For now, we'll need to implement platform-specific handling
        // You can use uni_links package or handle via MethodChannel
        return null;
      }
    } catch (e) {
      debugPrint('Error extracting token from URL: $e');
      return null;
    }
  }

  /// Extract token from a specific URL string (useful for deep links)
  static String? extractTokenFromUrlString(String urlString) {
    try {
      final uri = Uri.parse(urlString);
      return uri.queryParameters['token'];
    } catch (e) {
      debugPrint('Error extracting token from URL string: $e');
      return null;
    }
  }
}
