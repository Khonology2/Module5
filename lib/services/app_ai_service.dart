import 'package:flutter/foundation.dart';
import 'package:pdh/services/backend_auth_service.dart';

/// One chat message for [AppAiService.generate] (chat roles: user | assistant).
class AiChatTurn {
  const AiChatTurn.user(this.content) : role = 'user';

  const AiChatTurn.assistant(this.content) : role = 'assistant';

  final String role;
  final String content;
}

/// All in-app LLM calls are proxied through the PDH backend (`POST /ai/chat`).
/// The backend reads its provider keys from `backend/app/.env`.
class AppAiService {
  AppAiService._();

  /// [systemInstruction] is sent as the system prompt. [turns] are user/assistant
  /// messages in order. The backend prefers Azure OpenAI when configured.
  static Future<String> generate({
    String? systemInstruction,
    required List<AiChatTurn> turns,
  }) async {
    final messages = <Map<String, String>>[];
    for (final t in turns) {
      final trimmed = t.content.trim();
      if (trimmed.isEmpty) continue;
      final role = t.role == 'assistant' ? 'assistant' : 'user';
      messages.add({'role': role, 'content': t.content});
    }

    if (messages.isEmpty) {
      throw StateError('AI request has no message content.');
    }

    try {
      if (kDebugMode) {
        debugPrint(
          'AppAiService: POST ${BackendAuthService.apiBaseUrl}/ai/chat '
          '(${messages.length} message(s))',
        );
      }
      return await BackendAuthService.instance.generateAiChat(
        systemInstruction: systemInstruction,
        messages: messages,
      );
    } on BackendAuthException catch (e) {
      debugPrint('AppAiService: backend AI failed (${e.code}): ${e.message}');
      if (e.code == 'network_error' || e.code == 'timeout') {
        throw Exception(
          'Cannot reach the AI server. Start the backend (e.g. uvicorn in backend/) '
          'or check BACKEND_BASE_URL. ${e.message}',
        );
      }
      if (e.statusCode == 503 || e.code == 'backend_unavailable') {
        throw Exception(
          'AI is not configured on the server. Add AZURE_OPENAI_API_KEY, '
          'AZURE_OPENAI_API_ENDPOINT, and AZURE_OPENAI_MODEL to backend/app/.env '
          'and restart the API. ${e.message}',
        );
      }
      throw Exception(e.message);
    } catch (e) {
      debugPrint('AppAiService: unexpected error: $e');
      rethrow;
    }
  }
}
