/// Shared URL cleanup for SSO tokens (browser bar + [Uri.base]).
class UriTokenStrip {
  UriTokenStrip._();

  static bool uriHasTokenQuery(Uri u) {
    if (u.queryParameters.containsKey('token')) return true;
    final frag = u.fragment.trim();
    if (frag.isEmpty) return false;
    final normalized = frag.startsWith('/') ? frag : '/$frag';
    try {
      final inner = Uri.parse(normalized);
      return inner.queryParameters.containsKey('token');
    } catch (_) {
      return false;
    }
  }

  static Uri stripTokenFromUri(Uri u) {
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
      } catch (_) {}
    }

    return Uri(
      scheme: u.scheme,
      userInfo: u.userInfo,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: u.path,
      queryParameters: topQuery.isEmpty ? null : topQuery,
      fragment: newFragment,
    );
  }
}
