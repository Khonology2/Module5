import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pdh/utils/openrouter_env_merge.dart';

/// VM/desktop/mobile: optional local `.env` files (never bundled for web release).
Future<void> initializePdhEnv() async {
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
    await dotenv.load(fileName: 'backend/app/.env', isOptional: true);
  } catch (e) {
    debugPrint('dotenv load (io): $e');
    dotenv.testLoad(fileInput: '');
  }
  mergeOpenRouterFromPlatformEnvironment();
  mergeOpenRouterFromBackendRepoDotenv();
}
