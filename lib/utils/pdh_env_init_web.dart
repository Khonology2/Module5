import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Web builds must not call [DotEnv.load] — it HTTP-fetches `assets/.env` and 404s
/// when those files are intentionally excluded from the bundle.
Future<void> initializePdhEnv() async {
  dotenv.testLoad(fileInput: '');
}
