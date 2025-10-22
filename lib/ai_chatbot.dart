// ignore_for_file: use_build_context_synchronously

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
import 'package:pdh/context_maps/khonopal_context.dart'; // Import the new KhonoPalContext
import 'package:shared_preferences/shared_preferences.dart'; // Import for shared preferences
import 'dart:convert'; // Import for JSON encoding/decoding
import 'package:flutter_tts/flutter_tts.dart'; // Import for Text-to-Speech
import 'package:flutter/services.dart'; // Import for Clipboard

class AiChatbotScreen extends StatefulWidget {
  final String? prompt; // Optional initial prompt
  final Function(String)?
  onResult; // Callback for when a result is generated and should be returned
  const AiChatbotScreen({super.key, this.prompt, this.onResult});

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
  late FlutterTts flutterTts;
  String? _lastAiResponse; // To store the last AI response
  bool _isSpeaking = false; // To track if TTS is active
  List<dynamic> _voices = []; // List of available voices
  String? _selectedVoiceId; // ID of the currently selected voice
  final TextEditingController _voiceSearchController =
      TextEditingController(); // Controller for voice search
  List<dynamic> _filteredVoices = []; // List of voices filtered by search
  bool _isSummarizeMode = false; // New state variable for summarize mode

  // Updated list of quick actions for context-based answers
  final List<Map<String, String>> _quickActions = [
    {'text': 'What is KhonoPal Mode?', 'promptKey': 'khonopal_mode'},
    {
      'text': 'How does the Manager Dashboard work?',
      'promptKey': 'manager_dashboard',
    },
    {'text': 'Tell me about Alerts & Nudges?', 'promptKey': 'alerts_nudges'},
    {
      'text': 'What are the features of the Leaderboard?',
      'promptKey': 'leaderboard_features',
    },
    {
      'text': 'How can I track my Progress Visuals?',
      'promptKey': 'progress_visuals',
    },
    {
      'text': 'Explain the Repository & Audit screen.',
      'promptKey': 'repository_audit',
    },
    {
      'text': 'What privacy settings are available?',
      'promptKey': 'privacy_settings',
    },
    {'text': 'How does voice selection work?', 'promptKey': 'voice_selection'},
    {'text': 'What is General Chat mode?', 'promptKey': 'general_chat'},
  ];

  // Map to store system prompts for quick actions
  final Map<String, String> _quickActionSystemPrompts = {
    'khonopal_mode':
        'Explain the purpose and functionalities of KhonoPal Mode within the application.',
    'manager_dashboard':
        'Describe the key features and functionalities of the Manager Dashboard, including what information managers can view and actions they can perform.',
    'alerts_nudges':
        'Elaborate on the Alerts & Nudges system, explaining how it works, what kind of alerts/nudges users receive, and their benefits.',
    'leaderboard_features':
        'Detail the features of the Leaderboard, such as how points are earned, how rankings are displayed, and any competitive elements.',
    'progress_visuals':
        'Explain how users can track their progress through visual representations in the app, including what metrics are shown and how they are visualized.',
    'repository_audit':
        'Provide a comprehensive overview of the Repository & Audit screen, including its purpose, what data it displays, and its utility for users.',
    'privacy_settings':
        'List and describe the available privacy settings in the application, explaining what data is protected and how users can manage their privacy.',
    'voice_selection':
        'Describe the process and options for voice selection in the AI Chatbot, including how to search for voices and what customization is available.',
    'general_chat':
        'Explain that General Chat mode allows for free-form conversation without specific application context, and how it differs from KhonoPal mode.',
  };

  // New state variable to control quick actions visibility
  bool _showQuickActions = true;

  @override
  void initState() {
    super.initState();
    _initializeGenerativeModel();
    _videoController =
        VideoPlayerController.asset(
            'assets/videos/chat_bot_animation-vmake.mp4',
          )
          ..initialize().then((_) {
            _videoController.setLooping(true);
            _videoController.play();
            setState(() {});
          });
    // Corrected order: Load chat history before setting greeting
    _loadChatHistory(); // Load chat history when the screen initializes
    _loadUserProfileAndSetGreeting();
    flutterTts = FlutterTts();
    _initTts();
    _getVoices(); // Fetch available voices
    _voiceSearchController.addListener(
      _filterVoices,
    ); // Listen for search input changes

    // Ensure quick actions are visible when the screen is initialized
    _showQuickActions = true; // Initialize to true here

    // If a prompt is provided, send it automatically
    if (widget.prompt != null && widget.prompt!.isNotEmpty) {
      _sendMessage(initialPrompt: widget.prompt);
      _showQuickActions =
          false; // Hide quick actions if an initial prompt is sent
    }
  }

  void _filterVoices() {
    setState(() {
      if (_voiceSearchController.text.isEmpty) {
        _filteredVoices = List.from(
          _voices,
        ); // If search is empty, show all voices
      } else {
        _filteredVoices = _voices
            .where(
              (voice) =>
                  voice['name']!.toLowerCase().contains(
                    _voiceSearchController.text.toLowerCase(),
                  ) ||
                  voice['locale']!.toLowerCase().contains(
                    _voiceSearchController.text.toLowerCase(),
                  ),
            )
            .toList();
      }
    });
  }

  Future<void> _getVoices() async {
    // Ensure fetchedVoices is not null. It might be null on some platforms or in some scenarios.
    List<dynamic> fetchedVoices = (await flutterTts.getVoices) ?? [];
    _voices = []; // Initialize _voices as a growable list
    _voices.addAll(fetchedVoices); // Add all fetched voices

    // Directly use fetchedVoices for allVoices.
    // The fallback has been removed to ensure only platform-provided voices are shown.
    List<dynamic> allVoices = List.from(_voices);

    if (allVoices.isNotEmpty) {
      setState(() {
        // Use null-aware operators to safely access properties and provide default values
        _selectedVoiceId =
            allVoices.firstWhere(
                  (voice) =>
                      (voice['locale'] as String?)?.startsWith('en') ?? false,
                  orElse: () => allVoices.first,
                )['name']
                as String?;

        final selectedVoiceLocale =
            allVoices.firstWhere(
                  (voice) => (voice['name'] as String?) == _selectedVoiceId,
                  orElse: () => {
                    'locale': 'en-US',
                  }, // Provide a default locale if not found
                )['locale']
                as String? ??
            'en-US'; // Default to 'en-US' if locale is null

        if (_selectedVoiceId != null) {
          flutterTts.setVoice({
            'name': _selectedVoiceId!,
            'locale': selectedVoiceLocale,
          });
        }
      });
    }
    setState(() {
      _filteredVoices = List.from(
        _voices,
      ); // Initialize _filteredVoices with all voices
    });
  }

  void _initTts() {
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(1.0); // Increased speech rate
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(1.0);
  }

  void _toggleSummarizeMode() {
    setState(() {
      _isSummarizeMode = !_isSummarizeMode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSummarizeMode
              ? 'Summarize mode enabled!'
              : 'Summarize mode disabled!',
        ),
      ),
    );
  }

  Future _speak(String text) async {
    setState(() {
      _isSpeaking = true;
    });
    await flutterTts.speak(text);
    setState(() {
      _isSpeaking = false;
    });
  }

  Future _stop() async {
    await flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
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
          userName = userProfile.displayName.isNotEmpty
              ? userProfile.displayName
              : 'User';
        } catch (e) {
          // ignore: avoid_print
          print('Error fetching user profile: $e');
          userName = 'User'; // Default to 'User' on error
        }
      }
    }
    // Only add greeting if messages list is empty (i.e., no history loaded)
    if (_messages.isEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Hello, $userName I am KhonoPal how can I help you today?',
            isUser: false,
            isGreeting: true,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _videoController.dispose();
    _messageController.dispose(); // Dispose controller
    flutterTts.stop(); // Stop any ongoing speech
    flutterTts.awaitSpeakCompletion(true); // Ensure all speech is stopped
    _voiceSearchController.dispose(); // Dispose voice search controller
    _saveChatHistory(); // Save chat history when the screen is disposed
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
      await Future.delayed(
        const Duration(microseconds: 100),
      ); // Adjusted to be much faster
      if (!mounted)
        // ignore: curly_braces_in_flow_control_structures
        return; // Check if widget is still mounted before calling setState
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

  Future<void> _sendMessage({
    String? initialPrompt,
    String? messageContent,
    String? selectedModeOverride,
  }) async {
    String text =
        messageContent ??
        _messageController.text
            .trim(); // Use messageContent if provided, otherwise controller text
    if (text.isEmpty) return;

    // Input validation for text length
    if (text.length > 256) {
      // Approximate token limit
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Text is too long for proofreading (max 256 characters).',
          ),
        ),
      );
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messageController.clear();
      _isThinking = true; // Set thinking state to true
    });
    _scrollToBottom(); // Scroll to bottom after adding user message
    _saveChatHistory(); // Save chat after adding user message

    String textToSendToGemini = text;

    String pdpSystemInstruction =
        "You are an AI assistant specialized in creating personal development plans. Generate a comprehensive and actionable development plan based on the user's input. The plan should include specific goals, recommended resources (e.g., courses, books, certifications, mentors), and actionable steps with timelines. Focus on career aspirations and skill development.";

    try {
      // Dynamically set system instruction based on _selectedMode, selectedModeOverride or if it's a PDP request
      String? currentSystemInstruction;
      if (initialPrompt != null) {
        currentSystemInstruction = pdpSystemInstruction;
      } else {
        String actualSelectedMode = selectedModeOverride ?? _selectedMode;

        // Check if the message is a quick action and get its specific prompt
        String? quickActionPromptKey = _quickActions.firstWhere(
          (action) => action['text'] == text,
          orElse: () => {},
        )['promptKey'];

        if (quickActionPromptKey != null &&
            _quickActionSystemPrompts.containsKey(quickActionPromptKey)) {
          currentSystemInstruction =
              _quickActionSystemPrompts[quickActionPromptKey];
        } else {
          switch (actualSelectedMode) {
            case 'KhonoPal Mode': // KhonoPal Mode
              currentSystemInstruction = KhonoPalContext.khonopalContext;
              break;
            case 'General Chat': // General Chat mode
              currentSystemInstruction =
                  null; // No system instruction for general chat
              break;
            default: // Fallback to KhonoPal context if an unexpected mode is encountered
              currentSystemInstruction = KhonoPalContext.khonopalContext;
              break;
          }
        }
      }

      // Add summarization instruction if _isSummarizeMode is true
      if (_isSummarizeMode) {
        if (currentSystemInstruction != null) {
          currentSystemInstruction +=
              "\n\nPlease summarize the response to 3-4 lines.";
        } else {
          currentSystemInstruction =
              "Summarize the following response to 3-4 lines.";
        }
      }

      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: currentSystemInstruction != null
            ? Content.text(currentSystemInstruction)
            : null,
      );

      final prompt = [Content.text(textToSendToGemini)];
      final response = await _model.generateContent(prompt);

      String cleanedResponseText =
          response.text?.replaceAll('*', '') ?? 'No response';
      final aiMessage = ChatMessage(
        text: '',
        isUser: false,
        fullText: cleanedResponseText,
      );
      setState(() {
        _messages.add(aiMessage);
        _isThinking =
            false; // Set thinking state to false after response is received
        _lastAiResponse = cleanedResponseText; // Store the last AI response
      });
      _scrollToBottom(); // Scroll to bottom after adding new message container
      _startTypewriterAnimation(aiMessage);
      _videoController.play(); // Ensure video keeps playing
      _saveChatHistory(); // Save chat after AI response

      // If there's an onResult callback and a PDP was generated, send it back
      if (widget.onResult != null &&
          currentSystemInstruction == pdpSystemInstruction) {
        widget.onResult!(cleanedResponseText);
        Navigator.pop(context); // Pop the chatbot screen after generating PDP
      }
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
            Navigator.pop(context);
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
                colors: [
                  Color(0xFF0A0F1F),
                  Color(0x001F2840),
                ], // Slightly transparent gradient over image
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
                    itemCount:
                        _messages.length +
                        (_isThinking ? 1 : 0), // Adjust itemCount
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isThinking) {
                        return _ThinkingIndicator();
                      }
                      final message = _messages[index];
                      return ChatBubble(
                        message: message,
                        videoController: _videoController,
                      );
                    },
                  ),
                ),
                // Conditionally display quick actions
                if (_showQuickActions) _buildQuickActions(),
                _buildMessageInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New method to build quick action buttons
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8.0, // Space between quick action buttons
        runSpacing: 8.0, // Space between lines of quick action buttons
        children: _quickActions.map((action) {
          return TextButton(
            onPressed: () {
              setState(() {
                _showQuickActions =
                    false; // Hide quick actions when one is selected
              });
              // Send the quick action text to the chatbot
              _sendMessage(
                messageContent: action['text'],
                selectedModeOverride: 'KhonoPal Mode',
              ); // Pass selectedModeOverride
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white10, // A subtle background
              foregroundColor: Colors.white, // White text
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0), // Rounded corners
                side: BorderSide(color: Colors.white30), // Light border
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
            ),
            child: Text(
              action['text']!,
              style: const TextStyle(fontSize: 14.0),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
      ), // Add horizontal padding
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  prefixIcon: IconButton(
                    // Only the plus icon here
                    icon: Image.asset(
                      'assets/Plus_Addition.png',
                      width: 62.0,
                      height: 62.0,
                    ),
                    onPressed: () {
                      _showModeSelectionSheet(context);
                    },
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            // Moved Summarize Button outside TextField
            IconButton(
              icon: Image.asset(
                'assets/Document_Upload.png',
                width: 62.0,
                height: 62.0,
              ), // Increased size to match Plus_Addition icon
              onPressed: _toggleSummarizeMode,
            ),
            // Moved Text-to-speech button (AI Voice Playback) outside TextField
            IconButton(
              icon: Image.asset(
                'assets/1.Audio Sound.png', // Updated to use the new asset
                width: 62.0, // Increased size to match Plus_Addition icon
                height: 62.0, // Increased size to match Plus_Addition icon
                color: _isSpeaking
                    ? const Color(0xFFC10D00)
                    : ((_lastAiResponse != null && !_isThinking)
                          ? Colors.white70
                          : Colors.grey),
              ),
              onPressed: (_lastAiResponse != null && !_isThinking)
                  ? () {
                      if (_isSpeaking) {
                        _stop();
                      } else if (_lastAiResponse != null) {
                        _speak(_lastAiResponse!);
                      }
                    }
                  : null,
            ),
            const SizedBox(width: 8.0),
            FloatingActionButton(
              onPressed: () => _sendMessage(),
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
      case 'KhonoPal Mode':
        return 'Ask anything within the app...';
      case 'General Chat':
        return 'Chat freely without specific context...';
      default: // This case handles the initial state or any unexpected _selectedMode value
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Image.asset(
                        'assets/Innovation_Brainstorm.png',
                        width: 48.0,
                        height: 48.0,
                      ), // Increased size
                      title: Text(
                        'KhonoPal Mode',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedMode = 'KhonoPal Mode';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    // Re-added: Voice Selection
                    ListTile(
                      leading: Icon(
                        Icons.record_voice_over,
                        color: (_voices.isNotEmpty && _selectedVoiceId != null)
                            ? const Color(0xFFC10D00)
                            : Colors.white70,
                      ),
                      title: Text(
                        'Voice Selection (${_selectedVoiceId != null ? _selectedVoiceId!.split('#').first : 'Default'})',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(
                          context,
                        ); // Close the current bottom sheet
                        _showVoiceSelectionSheet(
                          context,
                        ); // Open the voice selection sheet
                      },
                    ),
                    // Re-added: General Chat
                    ListTile(
                      leading: Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white70,
                      ),
                      title: Text(
                        'General Chat',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedMode = 'General Chat';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: Image.asset(
                        'assets/Cancel.png',
                        width: 48.0,
                        height: 48.0,
                      ), // Replaced with Image.asset and set size
                      title: Text(
                        'Clear History Chat',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        _clearChatHistory(); // Call the new method to clear chat history
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVoiceSelectionSheet(BuildContext context) {
    _voiceSearchController.clear(); // Clear search on entry to show all voices
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Select Voice',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Search bar for voices
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: TextField(
                      controller: _voiceSearchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search voices...',
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  if (_voices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No voices available',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount:
                            _filteredVoices.length, // Use filtered voices here
                        itemBuilder: (context, index) {
                          final voice =
                              _filteredVoices[index]; // Each voice item is expected to be a Map<String, dynamic>
                          // Safely access 'name' and 'locale' with null-aware operators and provide default strings
                          final voiceName =
                              (voice['name'] as String?) ?? 'Unknown Voice';
                          final voiceLocale =
                              (voice['locale'] as String?) ?? 'Unknown Locale';
                          final bool isSelected = voiceName == _selectedVoiceId;

                          return ListTile(
                            title: Text(
                              '$voiceName ($voiceLocale)', // Combine name and locale
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFC10D00)
                                    : Colors.white,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: const Color(0xFFC10D00),
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedVoiceId = voiceName;
                                // Ensure locale is also safely accessed when setting the voice
                                flutterTts.setVoice({
                                  'name': _selectedVoiceId!,
                                  'locale': voiceLocale,
                                });
                              });
                              Navigator.pop(context); // Close the bottom sheet
                            },
                          );
                        },
                      ),
                    ),
                ],
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
        final firstGreeting = _messages.firstWhere(
          (msg) => !msg.isUser,
        ); // Assuming the first AI message is the greeting
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
    final String encodedMessages = json.encode(
      _messages
          .map(
            (msg) => {
              'text': msg.text,
              'isUser': msg.isUser,
              'fullText': msg.fullText,
              'isGreeting': msg.isGreeting,
            },
          )
          .toList(),
    );
    await prefs.setString('chatHistory', encodedMessages);
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedMessages = prefs.getString('chatHistory');
    if (encodedMessages != null && encodedMessages.isNotEmpty) {
      final List<dynamic> decodedMessages = json.decode(encodedMessages);
      setState(() {
        _messages.clear();
        _messages.addAll(
          decodedMessages
              .map(
                (msg) => ChatMessage(
                  text: msg['text'],
                  isUser: msg['isUser'],
                  fullText: msg['fullText'],
                  isGreeting: msg['isGreeting'] ?? false,
                ),
              )
              .toList(),
        );
      });
    } else {
      // If no history or empty, the initial greeting will be set by initState.
      // _loadUserProfileAndSetGreeting(); // Removed duplicate call
    }
  }
}

class ChatMessage {
  String text; // Made mutable for typewriter effect
  final bool isUser;
  final String? fullText; // Stores the complete text for AI messages
  final bool isGreeting; // New property to identify greeting messages

  ChatMessage({
    required this.text,
    required this.isUser,
    this.fullText,
    this.isGreeting = false,
  });
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
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser &&
              videoController != null &&
              videoController!.value.isInitialized) ...[
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
                bottomLeft: message.isUser
                    ? const Radius.circular(15.0)
                    : const Radius.circular(0.0),
                bottomRight: message.isUser
                    ? const Radius.circular(0.0)
                    : const Radius.circular(15.0),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 5.0,
                    horizontal: 8.0,
                  ),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color:
                        (message.isUser
                                ? const Color(0xFFC10D00)
                                : Colors.grey[700])
                            ?.withAlpha((255 * 0.6).round()),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(15.0),
                      topRight: const Radius.circular(15.0),
                      bottomLeft: message.isUser
                          ? const Radius.circular(15.0)
                          : const Radius.circular(0.0),
                      bottomRight: message.isUser
                          ? const Radius.circular(0.0)
                          : const Radius.circular(15.0),
                    ),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (!message.isUser &&
                          !message
                              .isGreeting) // Only show for AI messages that are not greetings
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: IconButton(
                              icon: const Icon(
                                Icons.copy,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: message.fullText ?? message.text,
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Response copied to clipboard!',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
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

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _leftAnimation;
  late Animation<double> _heightAnimation;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(
            milliseconds: 700,
          ), // Adjusted duration to match CSS
        )..repeat(
          reverse: true,
        ); // Repeat with reverse to match alternate animation

    _leftAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.0),
        weight: 0.5,
      ), // Stays at 0% for first half
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 0.5,
      ), // Moves to 100% for second half
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
    final double desiredWidth =
        screenWidth * 0.4; // Adjust this value to make it smaller
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
        constraints: BoxConstraints(
          maxWidth: desiredWidth,
          minHeight: 48,
          maxHeight: 48,
        ),
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
                final currentLeft =
                    _leftAnimation.value *
                    (desiredWidth - 24 - 15); // Adjust for bar width
                final currentHeight = _heightAnimation.value;
                final currentWidth = _widthAnimation.value;
                return Positioned(
                  left: currentLeft,
                  top: (_leftAnimation.value < 0.5)
                      ? (48 - currentHeight) / 2
                      : 0, // Top/Bottom logic for alternating effect
                  bottom: (_leftAnimation.value >= 0.5)
                      ? (48 - currentHeight) / 2
                      : 0,
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
    );
  }
}
