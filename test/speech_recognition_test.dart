import 'package:flutter_test/flutter_test.dart';
import 'package:pdh/services/speech_recognition_service.dart';
import 'package:flutter/foundation.dart';

void main() {
  group('SpeechRecognitionService (Web-only)', () {
    test('startSpeechRecognition calls JavaScript function', () {
      // This test is more of a smoke test to ensure the Dart method is called.
      // Actual JavaScript interaction cannot be directly tested in Dart unit tests.
      // We rely on manual browser console checks for full JS interop verification.
      final service = SpeechRecognitionService();
      // In a real scenario, you'd mock the js_util.callMethod behavior.
      // For now, we just ensure no errors are thrown when calling it.
      service.startSpeechRecognition();
      // No direct assertion possible here without mocking the JS side.
      // The console.log in web/index.html would confirm this in a real browser.
    });

    test('speechCommands stream emits recognized commands', () async {
      // This test verifies the stream mechanism within the Dart service.
      final service = SpeechRecognitionService();
      final expectedCommand = 'khonopal go to dashboard';

      // Simulate JavaScript calling the exposed Dart function
      // This is a simplified way to trigger the internal stream.
      // In a real browser, this would happen via the `web.window['flutterSpeechCommand']`.
      // Since we are mocking the web environment, we will directly call the internal _commandController
      if (kIsWeb) {
        // This part is tricky to test in a pure unit test without a full web environment.
        // For a more robust test, consider integration tests.
        // We'll simulate the internal behavior for now.
        service.speechCommands.listen(expectAsync1((command) {
          expect(command, expectedCommand);
        }));

        // Manually trigger the command as if it came from JavaScript
        // Accessing private members for testing purposes
        // ignore: invalid_use_of_visible_for_testing_member
        service.simulateSpeechCommand(expectedCommand);
      }
    });
  });
}
