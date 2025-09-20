import 'package:flutter/material.dart';

class AiChatbotScreen extends StatelessWidget {
  const AiChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chatbot', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFC10D00),
        iconTheme: const IconThemeData(color: Colors.white), // Set back button color to white
      ),
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
