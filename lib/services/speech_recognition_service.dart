import 'dart:async';
import 'dart:js_interop'; // Modern replacement for dart:js
import 'package:web/web.dart' as web; // Modern replacement for dart:html
import 'package:js/js_util.dart' as js_util; // Import for js_util

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show visibleForTesting;

class SpeechRecognitionService {
  static final SpeechRecognitionService _instance = SpeechRecognitionService._internal();

  factory SpeechRecognitionService() {
    return _instance;
  }

  SpeechRecognitionService._internal() {
    if (kIsWeb) {
      // Use js_interop to expose a Dart function to JavaScript
      js_util.setProperty(
        web.window as JSAny,
        'flutterSpeechCommand'.toJS,
        ((JSString command) {
          _commandController.add(command.toDart);
        }).toJS,
      );
    }
  }

  final _commandController = StreamController<String>.broadcast();
  Stream<String> get speechCommands => _commandController.stream;

  void startSpeechRecognition() {
    if (kIsWeb) {
      js_util.callMethod(web.window as JSAny, 'startSpeechRecognition'.toJS, []);
    }
  }

  void stopSpeechRecognition() {
    if (kIsWeb) {
      js_util.callMethod(web.window as JSAny, 'stopSpeechRecognition'.toJS, []);
    }
  }

  // Define command mappings
  final Map<String, String> commandRoutes = {
    // Baseline Navigation
    "khonopal go to home": "/",
    "khonopal sign in": "/sign_in",
    "khonopal register account": "/register",
    "khonopal open settings": "/settings",
    "khonopal go back": "back",
    "khonopal go to dashboard": "/dashboard", // context-aware

    // Employee Role
    "khonopal show my plan": "/my_pdp",
    "khonopal view my goals": "/my_goal_workspace",
    "khonopal open employee dashboard": "/employee_dashboard",
    "khonopal go to employee portal": "/employee_portal",
    "khonopal check my progress": "/progress_visuals",
    "khonopal show my badges": "/badges_points",
    "khonopal open alerts": "/alerts_nudges",
    "khonopal check nudges": "/alerts_nudges",
    "khonopal open repository": "/repository_audit",

    // Manager Role
    "khonopal open manager dashboard": "/dashboard",
    "khonopal go to manager portal": "/manager_portal",
    "khonopal review team goals": "/manager_review_team_dashboard",
    "khonopal check team progress": "/progress_visuals",
    "khonopal show leaderboard": "/leaderboard",
    "khonopal start season challenge": "/season_challenge",

    // Gamification
    "khonopal open leaderboard": "/leaderboard",
    "khonopal show my points": "/badges_points",
    "khonopal show gamification": "/gamification",

    // Chatbot Commands
    "khonopal talk to khonopal": "/ai_chatbot",
    "khonopal open chatbot": "/ai_chatbot",
    "khonopal clear chat history": "clear_chat",
    "khonopal read last message": "read_last",
    "khonopal send message": "send_message",
    "khonopal proofread this": "proofread",
    "khonopal change voice": "change_voice",

    // Global Quick Actions
    "khonopal start new goal": "create_goal",
    "khonopal search for": "search",
    "khonopal log out": "logout",
    "khonopal go home": "/",
  };

  void dispose() {
    _commandController.close();
  }

  // For testing purposes only
  @visibleForTesting
  void simulateSpeechCommand(String command) {
    _commandController.add(command);
  }
}


