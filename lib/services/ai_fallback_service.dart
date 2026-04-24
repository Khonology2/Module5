import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:pdh/services/backend_auth_service.dart';

/// Tries Firebase AI first; on failure uses backend Gemini API fallback.
/// Backend requires GEMINI_API_KEY in backend/app/.env.
class AiFallbackService {
  AiFallbackService._();
  static const Duration _timeout = Duration(seconds: 60);

  static String get _baseUrl => BackendAuthService.backendBaseUrl;

  /// Generate text via backend Gemini API. Use when Firebase AI throws.
  /// [prompt] – user message; [systemInstruction] – optional system/context.
  static Future<String> generateViaBackend({
    required String prompt,
    String? systemInstruction,
  }) async {
    final uri = Uri.parse('$_baseUrl/ai/generate');
    final body = <String, dynamic>{
      'prompt': prompt,
      if (systemInstruction != null && systemInstruction.isNotEmpty)
        'system_instruction': systemInstruction,
    };
    try {
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) {
        final err = jsonDecode(res.body) as Map<String, dynamic>?;
        final detail = err?['detail']?.toString() ?? res.body;
        throw Exception('DeepSeek fallback: $detail');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      final text = data?['text']?.toString() ?? '';
      if (kIsWeb) debugPrint('AiFallbackService: DeepSeek fallback succeeded');
      return text;
    } catch (e) {
      debugPrint('AiFallbackService: DeepSeek fallback failed: $e');
      rethrow;
    }
  }

  /// Try Firebase AI first; on any failure call backend Gemini API. Use this for simple single-prompt flows.
  static Future<String> generateTextWithFallback({
    required String userPrompt,
    String? systemInstruction,
  }) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: systemInstruction != null
            ? Content.text(systemInstruction)
            : null,
      );
      final response =
          await model.generateContent([Content.text(userPrompt)]);
      return response.text?.trim() ?? '';
    } catch (_) {
      return await generateViaBackend(
        prompt: userPrompt,
        systemInstruction: systemInstruction,
      );
    }
  }
}
