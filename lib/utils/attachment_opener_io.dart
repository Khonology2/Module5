import 'package:url_launcher/url_launcher.dart';

Future<bool> openAttachmentUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri);
}

