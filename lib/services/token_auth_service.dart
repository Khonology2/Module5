import 'package:flutter/foundation.dart';

class TokenAuthExtractionResult {
  const TokenAuthExtractionResult({required this.token, required this.source});

  final String? token;
  final String source;
}

class TokenAuthService {
  TokenAuthService._();

  static String _sanitizeToken(String? value) {
    final token = value?.trim() ?? '';
    if (token.isEmpty) {
      return '';
    }
    return token;
  }

  static TokenAuthExtractionResult extractTokenFromUri([Uri? uri]) {
    final target = uri ?? Uri.base;

    final queryToken = _sanitizeToken(target.queryParameters['token']);
    if (queryToken.isNotEmpty) {
      return TokenAuthExtractionResult(token: queryToken, source: 'query');
    }

    final fragment = target.fragment.trim();
    if (fragment.isNotEmpty) {
      final hashToken = _extractTokenFromFragment(fragment);
      if (hashToken != null && hashToken.isNotEmpty) {
        return TokenAuthExtractionResult(token: hashToken, source: 'hash');
      }
    }

    final fullToken = _extractTokenFromFullUrl(target.toString());
    if (fullToken != null && fullToken.isNotEmpty) {
      return TokenAuthExtractionResult(token: fullToken, source: 'full-url');
    }

    return const TokenAuthExtractionResult(token: null, source: 'none');
  }

  static bool hasTokenInCurrentUrl() {
    if (!kIsWeb) return false;
    return extractTokenFromUri().token != null;
  }

  static String? _extractTokenFromFragment(String fragment) {
    var parsed = fragment;
    if (parsed.startsWith('/')) {
      parsed = parsed.substring(1);
    }
    final normalized = parsed.startsWith('?') ? parsed : '?$parsed';

    try {
      final uri = Uri.parse(normalized);
      return _sanitizeToken(uri.queryParameters['token']);
    } catch (_) {
      return null;
    }
  }

  static String? _extractTokenFromFullUrl(String fullUrl) {
    final marker = 'token=';
    final idx = fullUrl.indexOf(marker);
    if (idx < 0) return null;

    final tokenStart = idx + marker.length;
    if (tokenStart >= fullUrl.length) return null;

    var tokenEnd = fullUrl.length;
    final ampIdx = fullUrl.indexOf('&', tokenStart);
    if (ampIdx >= 0) tokenEnd = ampIdx;

    final hashIdx = fullUrl.indexOf('#', tokenStart);
    if (hashIdx >= 0 && hashIdx < tokenEnd) tokenEnd = hashIdx;

    final raw = fullUrl.substring(tokenStart, tokenEnd);
    return _sanitizeToken(Uri.decodeComponent(raw));
  }
}
