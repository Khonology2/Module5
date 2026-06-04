void agentDebugLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
  String runId = 'pre-fix',
}) {
  // Logging helper intentionally disabled in the app runtime.
  // The old agent trace output is kept out of the browser console and terminal.
}
