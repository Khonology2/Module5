enum LearningVideoPlayerType {
  directVideo,
  embeddedWeb,
  webPage,
}

class LearningVideoUrl {
  LearningVideoUrl._();

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static String? normalize(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('//')) {
      url = 'https:$url';
    } else if (!url.contains('://')) {
      if (url.startsWith('/')) {
        url = 'https://www.udemy.com$url';
      } else {
        url = 'https://$url';
      }
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    return _preferUdemyLearnUrl(uri).toString();
  }

  static Uri _preferUdemyLearnUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!host.contains('udemy.com')) return uri;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments[0] == 'course') {
      final courseSlug = segments[1];
      if (segments.length >= 4 &&
          segments[2] == 'learn' &&
          segments[3] == 'lecture') {
        return uri;
      }
      if (segments.contains('learn')) {
        return uri;
      }
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: '/course/$courseSlug/learn/',
      );
    }
    return uri;
  }

  static LearningVideoPlayerType playerTypeFor(String? rawUrl) {
    final normalized = normalize(rawUrl ?? '');
    if (normalized == null) return LearningVideoPlayerType.webPage;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return LearningVideoPlayerType.webPage;

    final path = uri.path.toLowerCase();
    if (_isDirectVideoPath(path)) {
      return LearningVideoPlayerType.directVideo;
    }

    final host = uri.host.toLowerCase();
    if (host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('vimeo.com')) {
      return LearningVideoPlayerType.embeddedWeb;
    }

    return LearningVideoPlayerType.webPage;
  }

  static bool _isDirectVideoPath(String path) {
    return path.endsWith('.mp4') ||
        path.endsWith('.m3u8') ||
        path.endsWith('.webm') ||
        path.endsWith('.mov');
  }

  static String? embedUrlFor(String? rawUrl) {
    final normalized = normalize(rawUrl ?? '');
    if (normalized == null) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;

    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be')) {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (id.isNotEmpty) {
        return 'https://www.youtube.com/embed/$id?rel=0';
      }
    }
    if (host.contains('youtube.com')) {
      final videoId = uri.queryParameters['v'];
      if (videoId != null && videoId.isNotEmpty) {
        return 'https://www.youtube.com/embed/$videoId?rel=0';
      }
      if (uri.pathSegments.contains('embed') && uri.pathSegments.length >= 2) {
        return normalized;
      }
    }
    if (host.contains('vimeo.com')) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final id = segments.last;
        if (RegExp(r'^\d+$').hasMatch(id)) {
          return 'https://player.vimeo.com/video/$id';
        }
      }
    }
    return normalized;
  }

  static String get desktopUserAgent => _desktopUserAgent;

  static bool shouldKeepNavigationInApp(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return true;
    return host.contains('udemy.com') ||
        host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('vimeo.com') ||
        host.contains('player.vimeo.com');
  }
}
