import 'package:flutter/material.dart';

class AiChatbotScreen extends StatelessWidget {
  const AiChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0F1F), Color(0xFF1F2840)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Text(
            'Welcome to the AI Chatbot!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
