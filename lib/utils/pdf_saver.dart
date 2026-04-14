// Conditional export: re-exports the appropriate implementation for the platform
export 'pdf_saver_io.dart' if (dart.library.html) 'pdf_saver_web.dart';

// This file re-exports `Future<String?> savePdfBytes(String fileName, List<int> bytes)`
