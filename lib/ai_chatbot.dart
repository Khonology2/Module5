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
import'package:pdh/context_maps/manager_maps/dashboard_context.dart'; // Update the import path
import 'package:pdh/context_maps/manager_maps/progress_visuals_context.dart';
import 'package:pdh/context_maps/manager_maps/alerts_nudges_context.dart';
import 'package:pdh/context_maps/manager_maps/leaderboard_context.dart';
import 'package:pdh/context_maps/manager_maps/repository_audit_context.dart';
import 'package:pdh/context_maps/manager_maps/settings_privacy_context.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import for shared preferences
import 'dart:convert'; // Import for JSON encoding/decoding

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
  String _selectedMode = 'General Chat'; // New state variable for selected mode
  bool _isThinking = false; // Re-introduce thinking state

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
    _loadChatHistory(); // Load chat history when the screen initializes
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
    // Initialize GenerativeModel without system instructions by default
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      // systemInstruction will be set dynamically in _sendMessage
    );
  }

  void _startTypewriterAnimation(ChatMessage message) async {
    final fullText = message.fullText ?? '';
    setState(() {
      message.text = ''; // Start with empty text
    });

    for (int i = 0; i < fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 20)); // Adjust typing speed here
      if (!mounted) return; // Check if widget is still mounted before calling setState
      setState(() {
        message.text = fullText.substring(0, i + 1);
      });
      _scrollToBottom(); // Scroll to bottom with each character
    }
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
    _saveChatHistory(); // Save chat after adding user message

    try {
      // Dynamically set system instruction based on _selectedMode
      String? currentSystemInstruction;
      switch (_selectedMode) {
        case 'Dashboard Mode':
          currentSystemInstruction = DashboardContext.managerDashboardContext;
          break;
        case 'Progress Visuals Mode':
          currentSystemInstruction = ProgressVisualsContext.progressVisualsContext;
          break;
        case 'Alerts & Nudges Mode':
          currentSystemInstruction = AlertsNudgesContext.alertsNudgesContext;
          break;
        case 'Leaderboard Mode':
          currentSystemInstruction = LeaderboardContext.leaderboardContext;
          break;
        case 'Repository & Audit Mode':
          currentSystemInstruction = RepositoryAuditContext.repositoryAuditContext;
          break;
        case 'Settings & Privacy Mode':
          currentSystemInstruction = SettingsPrivacyContext.settingsPrivacyContext;
          break;
        case 'General Chat':
        default:
          currentSystemInstruction = null; // No system instruction for general chat
          break;
      }

      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: currentSystemInstruction != null ? Content.text(currentSystemInstruction) : null,
      );

      final prompt = [Content.text(text)];
      final response = await _model.generateContent(prompt);
      
      final aiMessage = ChatMessage(text: '', isUser: false, fullText: response.text ?? 'No response');
      setState(() {
        _messages.add(aiMessage);
        _isThinking = false; // Set thinking state to false after response is received
      });
      _scrollToBottom(); // Scroll to bottom after adding new message container
      _startTypewriterAnimation(aiMessage);
      _videoController.play(); // Ensure video keeps playing
      _saveChatHistory(); // Save chat after AI response
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
        toolbarHeight: 70.0, // Increased toolbar height
        leadingWidth: 70.0, // Adjust leading width
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
              'assets/20250919_1708_Futuristic Red Tech Design_remix_01k5h86tdef65aerhqpqthxd5d.png',
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
                    itemCount: _messages.length + (_isThinking ? 1 : 0), // Adjust itemCount
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isThinking) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0), // Add horizontal padding
      child: Container(
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
                  hintText: _getHintTextForMode(),
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white70),
                    onPressed: () {
                      _showModeSelectionSheet(context);
                    },
                  ),
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
      ),
    );
  }

  String _getHintTextForMode() {
    switch (_selectedMode) {
      case 'Dashboard Mode':
        return 'Ask anything about the Manager Review Team Dashboard...';
      case 'Progress Visuals Mode':
        return 'Ask anything about Progress Visuals...';
      case 'Alerts & Nudges Mode':
        return 'Ask anything about Alerts & Nudges...';
      case 'Leaderboard Mode':
        return 'Ask anything about the Leaderboard...';
      case 'Repository & Audit Mode':
        return 'Ask anything about Repository & Audit...';
      case 'Settings & Privacy Mode':
        return 'Ask anything about Settings & Privacy...';
      case 'General Chat':
      default:
        return 'Send a message...';
    }
  }

  void _showModeSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              // ignore: deprecated_member_use
              color: Colors.grey[850]?.withOpacity(0.7),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Select AI Mode',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.dashboard, color: Colors.white70),
                      title: Text('Dashboard Mode', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setState(() {
                          _selectedMode = 'Dashboard Mode';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.show_chart, color: Colors.white70),
                      title: Text('Progress Visuals', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setState(() {
                          _selectedMode = 'Progress Visuals Mode';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.notifications_active, color: Colors.white70),
                      title: Text('Alerts & Nudges', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setState(() {
                          _selectedMode = 'Alerts & Nudges Mode';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.leaderboard, color: Colors.white70),
                      title: Text('Leaderboard', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setState(() {
                          _selectedMode = 'Leaderboard Mode';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.security, color: Colors.white70),
                      title: Text('Repository & Audit', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setState(() {
                          _selectedMode = 'Repository & Audit Mode';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.settings, color: Colors.white70),
                      title: Text('Settings & Privacy', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setState(() {
                          _selectedMode = 'Settings & Privacy Mode';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.chat_bubble_outline, color: Colors.white70),
                      title: Text('General Chat', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setState(() {
                          _selectedMode = 'General Chat';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_sweep, color: Colors.white70),
                      title: Text('Clear History Chat', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _clearChatHistory(); // Call the new method to clear chat history
                        Navigator.pop(context);
                      },
                    ),
                    // Add more modes here if needed
                    // SizedBox(height: MediaQuery.of(context).padding.bottom), // Adjust for safe area
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _clearChatHistory() {
    setState(() {
      if (_messages.isNotEmpty) {
        final firstGreeting = _messages.firstWhere((msg) => !msg.isUser); // Assuming the first AI message is the greeting
        _messages.clear();
        _messages.add(firstGreeting);
      }
      _messageController.clear();
      _isThinking = false;
    });
    _scrollToBottom();
    _saveChatHistory(); // Save the updated (cleared) chat history
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedMessages = json.encode(_messages.map((msg) => {'text': msg.text, 'isUser': msg.isUser, 'fullText': msg.fullText}).toList());
    await prefs.setString('chatHistory', encodedMessages);
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedMessages = prefs.getString('chatHistory');
    if (encodedMessages != null && encodedMessages.isNotEmpty) {
      final List<dynamic> decodedMessages = json.decode(encodedMessages);
      setState(() {
        _messages.clear();
        _messages.addAll(decodedMessages.map((msg) => ChatMessage(text: msg['text'], isUser: msg['isUser'], fullText: msg['fullText'])).toList());
      });
    } else {
      // If no history or empty, ensure the initial greeting is set
      _loadUserProfileAndSetGreeting();
    }
  }
}

class ChatMessage {
  String text; // Made mutable for typewriter effect
  final bool isUser;
  final String? fullText; // Stores the complete text for AI messages

  ChatMessage({required this.text, required this.isUser, this.fullText});
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
  late Animation<double> _leftAnimation;
  late Animation<double> _heightAnimation;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700), // Adjusted duration to match CSS
    )..repeat(reverse: true); // Repeat with reverse to match alternate animation

    _leftAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 0.5), // Stays at 0% for first half
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 0.5), // Moves to 100% for second half
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _heightAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 43.0, end: 10.0), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 43.0), weight: 0.5),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _widthAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 15.0, end: 40.0), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: 40.0, end: 15.0), weight: 0.5),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double desiredWidth = screenWidth * 0.4; // Adjust this value to make it smaller
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
        constraints: BoxConstraints(maxWidth: desiredWidth),
        child: SizedBox(
          height: 48, // Fixed height for the loader animation
          width: desiredWidth - 24, // Adjust width considering padding
          child: Stack(
            children: [
              // Background text
              const Center(
                child: Text(
                  'KhonoPal is Thinking',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              // First animated bar
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final currentLeft = _leftAnimation.value * (desiredWidth - 24 - 15); // Adjust for bar width
                  final currentHeight = _heightAnimation.value;
                  final currentWidth = _widthAnimation.value;
                  return Positioned(
                    left: currentLeft,
                    top: (_leftAnimation.value < 0.5) ? (48 - currentHeight) / 2 : 0, // Top/Bottom logic for alternating effect
                    bottom: (_leftAnimation.value >= 0.5) ? (48 - currentHeight) / 2 : 0,
                    child: Container(
                      width: currentWidth,
                      height: currentHeight,
                      color: const Color(0xFFC10D00), // Red color for the loader
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
