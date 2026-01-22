// ignore_for_file: prefer_function_declarations_over_variables

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js; // Use dart:js for JS interop

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show visibleForTesting;

class SpeechRecognitionService {
  static final SpeechRecognitionService _instance =
      SpeechRecognitionService._internal();

  factory SpeechRecognitionService() {
    return _instance;
  }

  SpeechRecognitionService._internal() {
    if (kIsWeb) {
      // Use dart:js to expose a Dart function to JavaScript
      // Create a wrapper function that JavaScript can call
      js.context.callMethod('eval', [
        '''
        window.flutterSpeechCommand = function(command) {
          // This will be handled by the Dart callback
          if (window._dartSpeechCallback) {
            window._dartSpeechCallback(command);
          }
        };
        ''',
      ]);

      // Store the Dart callback that will be called from JavaScript
      // Using JsObject to set the property
      final callback = (String command) {
        _commandController.add(command);
      };
      js.context['_dartSpeechCallback'] = callback;
    }
  }

  final _commandController = StreamController<String>.broadcast();
  Stream<String> get speechCommands => _commandController.stream;

  void startSpeechRecognition() {
    if (kIsWeb) {
      // Call JavaScript function using dart:js
      js.context.callMethod('startSpeechRecognition', []);
    }
  }

  void stopSpeechRecognition() {
    if (kIsWeb) {
      // Call JavaScript function using dart:js
      js.context.callMethod('stopSpeechRecognition', []);
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
