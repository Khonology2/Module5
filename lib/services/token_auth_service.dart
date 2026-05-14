import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
    final trimmed = fragment.trim();
    if (trimmed.isEmpty) return null;

    final asPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    try {
      final asUri = Uri.parse(asPath);
      final fromPath = _sanitizeToken(asUri.queryParameters['token']);
      if (fromPath.isNotEmpty) return fromPath;
    } catch (_) {}

    var parsed = trimmed;
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

  /// Normalizes the hash portion so `manager_portal?...` and `/manager_portal?...` compare equal.
  static String normalizeWebHashFragment(String fragment) {
    final t = fragment.trim();
    if (t.isEmpty) return '';
    return t.startsWith('/') ? t : '/$t';
  }

  static bool webHashFragmentEquals(String expectedLeadingSlashPath) {
    if (!kIsWeb) return false;
    final cur = normalizeWebHashFragment(Uri.base.fragment);
    final exp = normalizeWebHashFragment(expectedLeadingSlashPath);
    if (cur == exp) return true;
    try {
      final uCur = Uri.parse(cur);
      final uExp = Uri.parse(exp);
      if (uCur.path != uExp.path) return false;
      final sCur = uCur.queryParameters['screen'];
      final sExp = uExp.queryParameters['screen'];
      if (sCur == null && sExp == null) return true;
      return sCur == sExp;
    } catch (_) {
      return false;
    }
  }

  /// Removes `token` from the top-level query and from the hash fragment query (web only).
  /// Call after a successful SSO token login so the secret does not stay in the address bar.
  static void stripTokenFromCurrentWebUrl({bool replace = true}) {
    if (!kIsWeb) return;
    if (!hasTokenInCurrentUrl()) return;

    try {
      final u = Uri.base;
      final topQuery = Map<String, String>.from(u.queryParameters)..remove('token');

      var newFragment = u.fragment;
      final frag = u.fragment.trim();
      if (frag.isNotEmpty) {
        final normalized = frag.startsWith('/') ? frag : '/$frag';
        try {
          final inner = Uri.parse(normalized);
          final innerQuery = Map<String, String>.from(inner.queryParameters)
            ..remove('token');
          final rebuilt = Uri(
            path: inner.path.isEmpty ? '/' : inner.path,
            queryParameters: innerQuery.isEmpty ? null : innerQuery,
          );
          newFragment =
              '${rebuilt.path}${rebuilt.hasQuery ? '?${rebuilt.query}' : ''}';
        } catch (_) {
          // Leave fragment unchanged if parsing fails.
        }
      }

      final clean = Uri(
        scheme: u.scheme,
        userInfo: u.userInfo,
        host: u.host,
        port: u.hasPort ? u.port : null,
        path: u.path,
        queryParameters: topQuery.isEmpty ? null : topQuery,
        fragment: newFragment,
      );
      SystemNavigator.routeInformationUpdated(uri: clean, replace: replace);
    } catch (e) {
      debugPrint('stripTokenFromCurrentWebUrl failed: $e');
    }
  }
}
