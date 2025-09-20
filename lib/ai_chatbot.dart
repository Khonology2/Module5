import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:pdh/models/user_profile.dart';
import 'package:pdh/services/database_service.dart';
// ignore: unused_import
import 'package:pdh/firebase_options.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';

class AiChatbotScreen extends StatefulWidget {
  const AiChatbotScreen({super.key});

  @override
  State<AiChatbotScreen> createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends State<AiChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  late GenerativeModel _model;
  final ScrollController _scrollController = ScrollController();
  late VideoPlayerController _videoController;
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _initializeGenerativeModel();
    _videoController = VideoPlayerController.asset('assets/videos/chat_bot_animation-vmake.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.play();
        setState(() {});
      });
    _loadUserProfileAndSetGreeting();
  }

  Future<void> _loadUserProfileAndSetGreeting() async {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';
    if (user != null) {
      // Try to get display name from Firebase Auth first
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        userName = user.displayName!;
      } else {
        // Fallback to Firestore for full name if displayName is null or empty
        try {
          final userProfile = await DatabaseService.getUserProfile(user.uid);
          userName = userProfile.displayName.isNotEmpty ? userProfile.displayName : 'User';
        } catch (e) {
          // ignore: avoid_print
          print('Error fetching user profile: $e');
          userName = 'User'; // Default to 'User' on error
        }
      }
    }
    setState(() {
      _messages.add(ChatMessage(text: 'Hello, $userName I am KhonoPal how can I help you today?', isUser: false));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _initializeGenerativeModel() {
    _model = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messageController.clear();
      _isThinking = true; // Set thinking state to true
    });
    _scrollToBottom(); // Scroll to bottom after adding user message

    try {
      final prompt = [Content.text(text)];
      final response = await _model.generateContent(prompt);
      setState(() {
        _messages.add(ChatMessage(text: response.text ?? 'No response', isUser: false));
        _isThinking = false; // Set thinking state to false after response
      });
      _videoController.play(); // Ensure video keeps playing
      _scrollToBottom(); // Scroll to bottom after adding AI response
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
        _isThinking = false; // Set thinking state to false on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // title: const Text('KhonoPal AI', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/dashboard');
          },
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'Chatbot_BG.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0F1F), Color(0x001F2840)], // Slightly transparent gradient over image
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length + (_isThinking ? 1 : 0), // Add extra item for thinking indicator
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _ThinkingIndicator();
                      }
                      final message = _messages[index];
                      return ChatBubble(message: message, videoController: _videoController,);
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Send a message...',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: const Color(0xFFC10D00),
            child: Image.asset(
              'assets/Send_Paper Plane/Send_Plane_Red Badge_White.png',
              width: 62.0, // Adjust width as needed
              height: 62.0, // Adjust height as needed
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VideoPlayerController? videoController;

  const ChatBubble({super.key, required this.message, this.videoController});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser && videoController != null && videoController!.value.isInitialized) ...[
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.transparent,
              child: ClipOval(
                child: SizedBox(
                  width: 40, // Adjust as needed
                  height: 40, // Adjust as needed
                  child: AspectRatio(
                    aspectRatio: videoController!.value.aspectRatio,
                    child: VideoPlayer(videoController!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15.0),
                topRight: const Radius.circular(15.0),
                bottomLeft: message.isUser ? const Radius.circular(15.0) : const Radius.circular(0.0),
                bottomRight: message.isUser ? const Radius.circular(0.0) : const Radius.circular(15.0),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: (message.isUser ? const Color(0xFFC10D00) : Colors.grey[700])?.withAlpha((255 * 0.6).round()),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(15.0),
                      topRight: const Radius.circular(15.0),
                      bottomLeft: message.isUser ? const Radius.circular(15.0) : const Radius.circular(0.0),
                      bottomRight: message.isUser ? const Radius.circular(0.0) : const Radius.circular(15.0),
                    ),
                  ),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  child: Text(
                    message.text,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 3.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[700]?.withAlpha((255 * 0.6).round()),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15.0),
            topRight: Radius.circular(15.0),
            bottomLeft: Radius.circular(0.0),
            bottomRight: Radius.circular(15.0),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final int dotCount = _animation.value.floor();
            final String dots = '.' * dotCount;
            return Text(
              'KhonoPal is Thinking$dots',
              style: const TextStyle(color: Colors.white),
            );
          },
        ),
      ),
    );
  }
}
