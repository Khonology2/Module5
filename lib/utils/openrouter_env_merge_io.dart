import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const _openRouterKeys = [
  'OPENROUTER_API_KEY_PRIMARY',
  'OPENROUTER_API_KEY_SECONDARY',
  'OPENROUTER_MODEL',
];

/// Parses a minimal KEY=value `.env` file (no multiline values).
Map<String, String> _parseDotenvLines(String contents) {
  final map = <String, String>{};
  for (final raw in contents.split(RegExp(r'\r?\n'))) {
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

/// Fills missing OpenRouter keys from [Platform.environment] (VM / desktop / tests).
/// Does not override values already set by [dotenv.load] or `--dart-define` merge.
void mergeOpenRouterFromPlatformEnvironment() {
  for (final key in _openRouterKeys) {
    final fromPlatform = Platform.environment[key]?.trim();
    if (fromPlatform == null || fromPlatform.isEmpty) continue;
    final existing = dotenv.maybeGet(key)?.trim();
    if (existing == null || existing.isEmpty) {
      dotenv.env[key] = fromPlatform;
    }
  }
}

/// If OpenRouter keys are still empty, load `backend/app/.env` from the process
/// working directory (repo root when you run `flutter run`).
///
/// Flutter only auto-loads a **project root** `.env`; backend keys often live in
/// `backend/app/.env` — this merges those without copying secrets into the web bundle.
void mergeOpenRouterFromBackendRepoDotenv() {
  final primary = dotenv.maybeGet('OPENROUTER_API_KEY_PRIMARY')?.trim();
  if (primary != null && primary.isNotEmpty) return;

  final candidates = <String>[
    // Normal: `flutter run` with cwd = repo root
    '${Directory.current.path}${Platform.pathSeparator}backend${Platform.pathSeparator}app${Platform.pathSeparator}.env',
    // Some IDEs / scripts cwd one level up
    '${Directory.current.path}${Platform.pathSeparator}app${Platform.pathSeparator}.env',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      final parsed = _parseDotenvLines(file.readAsStringSync());
      for (final key in _openRouterKeys) {
        final v = parsed[key]?.trim();
        if (v == null || v.isEmpty) continue;
        final existing = dotenv.maybeGet(key)?.trim();
        if (existing == null || existing.isEmpty) {
          dotenv.env[key] = v;
        }
      }
      if (dotenv.maybeGet('OPENROUTER_API_KEY_PRIMARY')?.trim().isNotEmpty == true) {
        debugPrint('OpenRouter: merged keys from ${file.path}');
      }
      return;
    } catch (e) {
      debugPrint('OpenRouter: skipped reading $path ($e)');
    }
  }
}
