// Verify OpenRouter keys from project-root `.env`.
// Usage (from repo root): dart run tool/openrouter_key_check.dart
import 'dart:convert';
import 'dart:io';

const _url = 'https://openrouter.ai/api/v1/chat/completions';

Map<String, String> _loadDotEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path — copy .env.example to .env and add keys.');
    return {};
  }
  final map = <String, String>{};
  for (final raw in file.readAsLinesSync()) {
    var line = raw.trimRight();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    map[key] = value;
  }
  return map;
}

Future<void> _testKey({
  required String label,
  required String apiKey,
  required String model,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(_url);
    final req = await client.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer $apiKey');
    req.headers.set('HTTP-Referer', 'https://github.com/pdh-flutter');
    req.headers.set('X-Title', 'PDH key check');

    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': 'What is today\'s date? Reply with one short sentence.',
        },
      ],
    });
    req.write(body);

    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      stderr.writeln('$label FAILED HTTP ${res.statusCode}: $text');
      return;
    }
    final decoded = jsonDecode(text);
    final choices = (decoded as Map)['choices'] as List?;
    final msg = choices?.isNotEmpty == true
        ? (choices!.first as Map)['message'] as Map?
        : null;
    final content = msg?['content'];
    stdout.writeln('$label OK (${res.statusCode}): $content');
  } finally {
    client.close(force: true);
  }
}

Future<void> main() async {
  final root = Directory.current.path;
  final envPath = '$root${Platform.pathSeparator}.env';
  final env = _loadDotEnv(envPath);
  if (env.isEmpty) {
    exitCode = 2;
    return;
  }

  final model = (env['OPENROUTER_MODEL'] ?? 'google/gemini-2.0-flash-001').trim();
  final k1 = env['OPENROUTER_API_KEY_PRIMARY']?.trim();
  final k2 = env['OPENROUTER_API_KEY_SECONDARY']?.trim();

  if (k1 == null || k1.isEmpty) {
    stderr.writeln('OPENROUTER_API_KEY_PRIMARY missing in .env');
    exit(2);
  }
  if (k2 == null || k2.isEmpty) {
    stderr.writeln('OPENROUTER_API_KEY_SECONDARY missing in .env');
    exit(2);
  }

  stdout.writeln('Using model: $model\n');
  await _testKey(label: 'PRIMARY', apiKey: k1, model: model);
  await _testKey(label: 'SECONDARY', apiKey: k2, model: model);
}
