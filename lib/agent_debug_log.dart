// #region agent log
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _agentEndpoint =
    'http://127.0.0.1:7442/ingest/5ce4d2d7-964e-4f5e-9ec9-c91584821692';
const _agentSessionId = '2f31f2';

void agentDebugLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
  String runId = 'pre-fix',
}) {
  if (kReleaseMode) {
    return;
  }
  final payload = <String, Object?>{
    'sessionId': _agentSessionId,
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  final line = jsonEncode(payload);
  debugPrint('AGENT_LOG $line');
  // ignore: avoid_print
  print('AGENT_LOG $line');
  try {
    http
        .post(
          Uri.parse(_agentEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': _agentSessionId,
          },
          body: line,
        )
        .catchError((Object _) => http.Response('', 500));
  } catch (_) {}
}
// #endregion
