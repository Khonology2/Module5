import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/database_service.dart';

// --- 1. Custom Color Definitions (Based on HTML/Tailwind) ---
const Color chatPrimary = Color(0xFF4F46E5); // Indigo-600
const Color chatBgDark = Color(0xFF1F2937); // Dark Slate Background
const Color translucentLayerColor = Color(0xE61E293B); // 90% opacity dark slate for blur effect

// --- Mock Data Structure and Logic (Simulating Firebase/Auth) ---
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });
}

 

// --- Team Chats Screen Widget ---
class TeamChatsScreen extends StatefulWidget {
  const TeamChatsScreen({super.key});

  @override
  State<TeamChatsScreen> createState() => _TeamChatsScreenState();
}

class _TeamChatsScreenState extends State<TeamChatsScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await DatabaseService.getUserProfile(user.uid);
      setState(() {
        _displayName = profile.displayName.isNotEmpty
            ? profile.displayName
            : (user.displayName ?? user.email ?? user.uid);
      });
    } catch (_) {
      setState(() {
        _displayName = user.displayName ?? user.email ?? user.uid;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in required to send messages.')),
      );
      return;
    }
    () async {
      try {
        await FirebaseFirestore.instance.collection('team.chat').add({
          'senderId': uid,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _textController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }();
  }

  Widget _buildTranslucentContainer({required Widget child}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          color: translucentLayerColor,
          child: child,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMine = currentUserId != null && msg.senderId == currentUserId;
    final time = TimeOfDay.fromDateTime(msg.timestamp).format(context);
    final displaySenderId = msg.senderId.length > 8
        ? '${msg.senderId.substring(0, 4)}...${msg.senderId.substring(msg.senderId.length - 4)}'
        : msg.senderId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isMine
              ? chatPrimary.withOpacity(0.9)
              : Colors.grey[700]!.withOpacity(0.7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMine ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    isMine ? 'You' : displaySenderId,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isMine
                          ? Colors.indigo.shade200
                          : Colors.grey.shade400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                        ? Colors.indigo.shade300
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(color: chatBgDark),
        child: SafeArea(
          child: Column(
            children: [
              _buildTranslucentContainer(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Team Chat & Collaboration',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Your Username:',
                              style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Builder(builder: (context) {
                            final user = FirebaseAuth.instance.currentUser;
                            final name = _displayName ?? user?.displayName ?? user?.email ?? '';
                            return Tooltip(
                              message: name.isEmpty ? 'Not signed in' : name,
                              child: Text(
                                name,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: chatPrimary,
                                    fontWeight: FontWeight.bold),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: FirebaseFirestore.instance
                      .collection('team.chat')
                      .orderBy('timestamp')
                      .snapshots()
                      .map((snapshot) => snapshot.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final ts = data['timestamp'];
                            DateTime dt;
                            if (ts is Timestamp) {
                              dt = ts.toDate();
                            } else {
                              dt = DateTime.now();
                            }
                            return ChatMessage(
                              id: doc.id,
                              senderId: (data['senderId'] ?? '') as String,
                              text: (data['text'] ?? '') as String,
                              timestamp: dt,
                            );
                          }).toList()),
                  initialData: const [],
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: chatPrimary));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                          child: Text('Start the conversation! No messages yet.',
                              style: TextStyle(color: Colors.grey)));
                    }

                    final messages = snapshot.data!;
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(messages[index]);
                      },
                    );
                  },
                ),
              ),
              _buildTranslucentContainer(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TextField(
                            controller: _textController,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.5),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: FloatingActionButton(
                          onPressed: _handleSend,
                          backgroundColor: chatPrimary,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          child: const Icon(Icons.send),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
