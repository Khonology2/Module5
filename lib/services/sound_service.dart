import 'package:flutter/services.dart';

class SoundService {
  static Future<void> playChime() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
