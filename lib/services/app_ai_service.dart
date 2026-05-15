import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// One chat message for [AppAiService.generate] (OpenRouter roles: user | assistant).
class AiChatTurn {
  const AiChatTurn.user(this.content) : role = 'user';

  const AiChatTurn.assistant(this.content) : role = 'assistant';

  final String role;
  final String content;
}

/// All in-app LLM calls go through [OpenRouter](https://openrouter.ai/) using keys from
/// `.env` or compile-time defines (`OPENROUTER_API_KEY_PRIMARY`, etc.).
///
/// This module intentionally does **not** depend on `firebase_ai`, so the app never
/// invokes Google Vertex `GenerativeService` (which your GCP project may block).
class AppAiService {
  AppAiService._();

  static const _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  static String get _model {
    final m = dotenv.maybeGet('OPENROUTER_MODEL')?.trim();
    if (m != null && m.isNotEmpty) return m;
    return 'google/gemini-2.0-flash-001';
  }

  static List<String> _apiKeysInOrder() {
    final a = dotenv.maybeGet('OPENROUTER_API_KEY_PRIMARY')?.trim();
    final b = dotenv.maybeGet('OPENROUTER_API_KEY_SECONDARY')?.trim();
    return [a, b].whereType<String>().where((k) => k.isNotEmpty).toList();
  }

  static String _messageBodyText(Object? content) {
    if (content is String && content.trim().isNotEmpty) {
      return content;
    }
    if (content is List) {
      final buf = StringBuffer();
      for (final block in content) {
        if (block is Map<String, dynamic>) {
          if (block['type'] == 'text' && block['text'] is String) {
            buf.write(block['text']);
          }
        }
      }
      return buf.toString();
    }
    return '';
  }

  /// [systemInstruction] is sent as OpenRouter `system`. [turns] are `user` / `assistant`
  /// messages in order (after the optional system message).
  static Future<String> generate({
    String? systemInstruction,
    required List<AiChatTurn> turns,
  }) async {
    final keys = _apiKeysInOrder();
    if (keys.isEmpty) {
      throw StateError(
        'Missing OpenRouter keys. Add OPENROUTER_API_KEY_PRIMARY to `.env` '
        '(see `.env.example`), or pass --dart-define=OPENROUTER_API_KEY_PRIMARY=... '
        'when building.',
      );
    }

    final messages = <Map<String, String>>[];

    final sys = systemInstruction?.trim();
    if (sys != null && sys.isNotEmpty) {
      messages.add({'role': 'system', 'content': sys});
    }

    for (final t in turns) {
      final trimmed = t.content.trim();
      if (trimmed.isEmpty) continue;
      messages.add({'role': t.role, 'content': t.content});
    }

    Object? lastError;
    for (final key in keys) {
      try {
        return await _postChatCompletion(apiKey: key, messages: messages);
      } catch (e, st) {
        lastError = e;
        debugPrint('AppAiService: key failed ($e)\n$st');
      }
    }
    throw Exception('OpenRouter: all API keys failed. Last error: $lastError');
  }

  static Future<String> _postChatCompletion({
    required String apiKey,
    required List<Map<String, String>> messages,
  }) async {
    final res = await http.post(
      Uri.parse(_openRouterUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/pdh-flutter',
        'X-Title': 'PDH',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected JSON: ${res.body}');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('No choices in response: ${res.body}');
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('Invalid choice: ${res.body}');
    }
    final msg = first['message'];
    if (msg is! Map<String, dynamic>) {
      throw Exception('No message: ${res.body}');
    }
    final body = _messageBodyText(msg['content']);
    if (body.trim().isEmpty) {
      throw Exception('Empty model content: ${res.body}');
    }
    return body;
  }
}
