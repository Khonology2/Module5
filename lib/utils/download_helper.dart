// Conditional facade for download helpers
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart' as impl;

void downloadJsonFile(String filename, String jsonContent) {
  impl.downloadJsonFile(filename, jsonContent);
}


