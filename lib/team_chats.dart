import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdh/services/cloudinary_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/utils/attachment_opener.dart';

// --- 1. Custom Color Definitions (Based on HTML/Tailwind) ---
const Color chatPrimary = Color(0xFF4F46E5); // Indigo-600
const Color chatBgDark = Color(0xFF1F2937); // Dark Slate Background
const Color translucentLayerColor = Color(
  0xE61E293B,
); // 90% opacity dark slate for blur effect

// --- Mock Data Structure and Logic (Simulating Firebase/Auth) ---
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String? senderName;
  final bool isTyping;
  final bool isDeleted;
  final DateTime? editedAt;
  final String? replyTo;
  final String? replyToText;
  final String? replyToSender;
  final Map<String, List<String>> reactions;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType;
  final int? attachmentSizeBytes;
  final String? goalId;
  final String? goalTitle;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.senderName,
    this.isTyping = false,
    this.isDeleted = false,
    this.editedAt,
    this.replyTo,
    this.replyToText,
    this.replyToSender,
    this.reactions = const {},
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.attachmentSizeBytes,
    this.goalId,
    this.goalTitle,
  });
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> {
  late Timer _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() {
        _tick = (_tick + 1) % 3;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = (_tick % 3) + 1;
    final dots = List.filled(count, '.').join();
    return Text(
      'typing$dots',
      style: const TextStyle(color: Colors.white, fontSize: 15),
    );
  }
}

// --- Team Chats Screen Widget ---
class TeamChatsScreen extends StatefulWidget {
  const TeamChatsScreen({super.key});

  @override
  State<TeamChatsScreen> createState() => _TeamChatsScreenState();
}

class _TeamChatsScreenState extends State<TeamChatsScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController(
    initialScrollOffset: 0.0,
  );
  Uint8List? _pendingAttachmentBytes;
  String? _pendingAttachmentName;
  int? _pendingAttachmentSizeBytes;
  String? _pendingAttachmentType;
  String? _selectedGoalId;
  String? _selectedGoalTitle;
  String? _displayName;
  final Map<String, String> _userNameCache = {}; // Cache for usernames
  final Set<String> _processedIds = {};
  final List<ChatMessage> _visibleMessages = [];
  final Map<String, Timer> _typingTimers = {};
  bool _initializedStream = false;
  final Map<String, GlobalKey> _itemKeys = {};
  ChatMessage? _replyingTo;
  bool _showGoalOnly = false;

  Future<void> _showCenterNotice(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1629),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: chatPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
    // Nudge list to latest after first frame and shortly after to account for async content sizing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      Future.delayed(
        const Duration(milliseconds: 120),
        () => _scrollToBottom(),
      );
    });
  }

  String? _profilePhotoUrl;

  Future<void> _loadDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Try to get name from onboarding collection first (like dashboard does)
      final onboardingName = await DatabaseService.getUserNameFromOnboarding(
        userId: user.uid,
        email: user.email,
      );

      if (onboardingName != null && onboardingName.isNotEmpty) {
        setState(() {
          _displayName = onboardingName;
        });
        return;
      }

      // Fallback to user profile
      final profile = await DatabaseService.getUserProfile(user.uid);
      setState(() {
        _displayName = profile.displayName.isNotEmpty
            ? profile.displayName
            : (user.displayName ?? user.email ?? user.uid);
        _profilePhotoUrl = profile.profilePhotoUrl;
      });
    } catch (_) {
      setState(() {
        _displayName = user.displayName ?? user.email ?? user.uid;
        _profilePhotoUrl = null;
      });
    }
  }

  Future<String> _getUserName(String userId) async {
    // Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    // If it's the current user, use cached display name
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == userId && _displayName != null) {
      _userNameCache[userId] = _displayName!;
      return _displayName!;
    }

    try {
      // Try to get name from onboarding collection first (like dashboard does)
      final onboardingName = await DatabaseService.getUserNameFromOnboarding(
        userId: userId,
        email: currentUser?.email,
      );

      if (onboardingName != null && onboardingName.isNotEmpty) {
        _userNameCache[userId] = onboardingName;
        return onboardingName;
      }

      // Fallback to user profile
      final profile = await DatabaseService.getUserProfile(userId);
      final name = profile.displayName.isNotEmpty
          ? profile.displayName
          : (currentUser?.displayName ?? currentUser?.email ?? userId);
      _userNameCache[userId] = name;
      return name;
    } catch (_) {
      // Fallback to userId if profile fetch fails
      final fallback = currentUser?.displayName ?? currentUser?.email ?? userId;
      _userNameCache[userId] = fallback;
      return fallback;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  String _guessAttachmentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
    if (imageExts.contains(ext)) return 'image';
    return 'document';
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'bmp',
        ],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        await _showCenterNotice(
          // ignore: use_build_context_synchronously
          context,
          'Unable to read selected file. Please try again.',
        );
        return;
      }
      setState(() {
        _pendingAttachmentBytes = file.bytes;
        _pendingAttachmentName = file.name;
        _pendingAttachmentSizeBytes = file.size;
        _pendingAttachmentType = _guessAttachmentType(file.name);
      });
    } catch (e) {
      // ignore: use_build_context_synchronously
      await _showCenterNotice(context, 'Failed to pick file: $e');
    }
  }

  void _clearPendingAttachment() {
    setState(() {
      _pendingAttachmentBytes = null;
      _pendingAttachmentName = null;
      _pendingAttachmentSizeBytes = null;
      _pendingAttachmentType = null;
    });
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    final hasAttachment = _pendingAttachmentBytes != null;
    if (text.isEmpty && !hasAttachment) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showCenterNotice(context, 'Sign in required to send messages.');
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      final name = _displayName ?? user?.displayName ?? user?.email ?? '';
      final payload = <String, dynamic>{
        'senderId': uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'senderName': name,
        'isDeleted': false,
        'clientAt': Timestamp.fromDate(DateTime.now()),
        'editedAt': null,
      };
      if (_replyingTo != null) {
        payload['replyTo'] = _replyingTo!.id;
        payload['replyToText'] = _replyingTo!.text;
        payload['replyToSender'] =
            _replyingTo!.senderName ?? _replyingTo!.senderId;
      }
      if (_selectedGoalId != null && _selectedGoalTitle != null) {
        payload['goalId'] = _selectedGoalId;
        payload['goalTitle'] = _selectedGoalTitle;
      }
      if (hasAttachment &&
          _pendingAttachmentBytes != null &&
          _pendingAttachmentName != null) {
        final goalIdForUpload = _selectedGoalId ?? 'team_chat';
        final secureUrl = await CloudinaryService.uploadFileUnsigned(
          bytes: _pendingAttachmentBytes!,
          fileName: _pendingAttachmentName!,
          goalId: goalIdForUpload,
        );
        payload['attachmentUrl'] = secureUrl;
        payload['attachmentName'] = _pendingAttachmentName;
        payload['attachmentType'] = _pendingAttachmentType;
        payload['attachmentSizeBytes'] = _pendingAttachmentSizeBytes;
      }
      final collection = FirebaseFirestore.instance.collection('team.chat');
      final docRef = await collection.add(payload);
      final now = DateTime.now();
      final newMsg = ChatMessage(
        id: docRef.id,
        senderId: uid,
        text: text,
        timestamp: now,
        senderName: name,
        isDeleted: false,
        editedAt: null,
        replyTo: _replyingTo?.id,
        replyToText: _replyingTo?.text,
        replyToSender: _replyingTo?.senderName ?? _replyingTo?.senderId,
        reactions: const {},
        attachmentUrl: payload['attachmentUrl'] as String?,
        attachmentName: payload['attachmentName'] as String?,
        attachmentType: payload['attachmentType'] as String?,
        attachmentSizeBytes: payload['attachmentSizeBytes'] as int?,
        goalId: payload['goalId'] as String?,
        goalTitle: payload['goalTitle'] as String?,
      );
      _processedIds.add(docRef.id);
      setState(() {
        // Keep newest messages at the front for reverse: true list
        _visibleMessages.insert(0, newMsg);
      });
      _textController.clear();
      if (mounted) {
        setState(() {
          _replyingTo = null;
          _selectedGoalId = null;
          _selectedGoalTitle = null;
        });
      }
      _clearPendingAttachment();
      _scrollToBottom(animate: true);
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Failed to send: $e');
    }
  }

  List<ChatMessage> _repliesForMessage(String id) {
    final replies = _visibleMessages
        .where((m) => m.replyTo == id && !m.isTyping)
        .toList();
    replies.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return replies;
  }

  Future<void> _openAttachment(ChatMessage msg) async {
    final url = msg.attachmentUrl;
    if (url == null || url.isEmpty) return;
    try {
      final opened = await openAttachmentUrl(url);
      if (!opened) {
        await _showCenterNotice(
          // ignore: use_build_context_synchronously
          context,
          'Unable to open attachment.',
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      await _showCenterNotice(context, 'Failed to open attachment: $e');
    }
  }

  Widget _buildAttachmentPreviewBubble(ChatMessage msg) {
    if (msg.attachmentUrl == null) return const SizedBox.shrink();
    final isImage = msg.attachmentType == 'image';
    final name = msg.attachmentName ?? 'Attachment';
    final sizeBytes = msg.attachmentSizeBytes;
    String? sizeLabel;
    if (sizeBytes != null && sizeBytes > 0) {
      final kb = sizeBytes / 1024;
      if (kb < 1024) {
        sizeLabel = '${kb.toStringAsFixed(1)} KB';
      } else {
        final mb = kb / 1024;
        sizeLabel = '${mb.toStringAsFixed(1)} MB';
      }
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: InkWell(
        onTap: () => _openAttachment(msg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isImage ? Icons.image : Icons.insert_drive_file,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sizeLabel != null)
                    Text(
                      sizeLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showThreadView(ChatMessage parent) async {
    final replies = _repliesForMessage(parent.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1629),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thread',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMessageBubble(parent),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),
                if (replies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No replies yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: replies.length,
                      itemBuilder: (context, index) {
                        final m = replies[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _buildMessageBubble(m),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTranslucentContainer({required Widget child}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(color: translucentLayerColor, child: child),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMine = currentUserId != null && msg.senderId == currentUserId;
    final time = TimeOfDay.fromDateTime(msg.timestamp).format(context);

    // Use FutureBuilder to fetch full name if senderName is missing
    return FutureBuilder<String>(
      future: isMine
          ? Future.value('You')
          : (msg.senderName != null && msg.senderName!.isNotEmpty)
          ? Future.value(msg.senderName!)
          : _getUserName(msg.senderId),
      builder: (context, snapshot) {
        final senderLabel = snapshot.data ?? msg.senderId;

        final bubbleKey = _itemKeys.putIfAbsent(msg.id, () => GlobalKey());
        final replies = _repliesForMessage(msg.id);
        return Align(
          key: ValueKey(msg.id),
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: (!msg.isTyping)
                ? () => _showMessageActions(msg, isMine)
                : null,
            child: Container(
              key: bubbleKey,
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isMine
                    ? const Color(0xFFC10D00)
                    : Colors.grey[700]!.withValues(alpha: 0.7),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg.replyTo != null &&
                      (msg.replyToText != null || msg.replyToSender != null))
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.replyToSender ?? 'Reply',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (msg.replyToText ?? '').isEmpty
                                ? '(attachment)'
                                : msg.replyToText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (msg.replyTo != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _scrollToMessage(msg.replyTo!),
                                child: const Text(
                                  'View',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          senderLabel,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMine
                                  ? Colors.indigo.shade300
                                  : Colors.grey.shade500,
                            ),
                          ),
                          if (msg.editedAt != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(edited)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  msg.isTyping
                      ? _TypingIndicator()
                      : (msg.isDeleted
                            ? const Text(
                                'Message deleted',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : Text(
                                msg.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              )),
                  if (msg.goalTitle != null && msg.goalTitle!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Text(
                        'Goal: ${msg.goalTitle}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  _buildAttachmentPreviewBubble(msg),
                  if (replies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showThreadView(msg),
                          child: Text(
                            replies.length == 1
                                ? 'View thread (1 reply)'
                                : 'View thread (${replies.length} replies)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (msg.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: -6,
                        children: msg.reactions.entries.map((e) {
                          final emoji = e.key;
                          final count = e.value.length;
                          final mine =
                              currentUserId != null &&
                              e.value.contains(currentUserId);
                          return GestureDetector(
                            onTap: () => _toggleReaction(msg, emoji),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: mine
                                    ? Border.all(color: Colors.white24)
                                    : null,
                              ),
                              child: Text(
                                '$emoji $count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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

  Future<void> _showMessageActions(ChatMessage msg, bool isMine) async {
    final canEdit =
        isMine &&
        !msg.isDeleted &&
        DateTime.now().difference(msg.timestamp) <= const Duration(minutes: 10);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.white),
                title: const Text(
                  'Reply',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions, color: Colors.white),
                title: const Text(
                  'React',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, 'react'),
              ),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text(
                    'Edit',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
            ],
          ),
        );
      },
      backgroundColor: const Color(0xFF0F1629),
    );
    switch (action) {
      case 'reply':
        _setReplyTo(msg);
        break;
      case 'react':
        _pickReaction(msg);
        break;
      case 'edit':
        _editMessage(msg);
        break;
      case 'delete':
        _confirmDelete(msg);
        break;
      default:
        break;
    }
  }

  void _setReplyTo(ChatMessage msg) {
    setState(() {
      _replyingTo = msg;
    });
  }

  Future<void> _pickReaction(ChatMessage msg) async {
    const emojis = ['👍', '❤️', '😂', '🎉', '😮', '🙏'];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF0F1629),
          child: Wrap(
            spacing: 12,
            children: emojis
                .map(
                  (e) => GestureDetector(
                    onTap: () => Navigator.pop(context, e),
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (chosen != null) {
      _toggleReaction(msg, chosen);
    }
  }

  Future<void> _toggleReaction(ChatMessage msg, String emoji) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('team.chat')
          .doc(msg.id);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final rawReactions = (data['reactions'] is Map)
            ? Map<String, dynamic>.from(data['reactions'] as Map)
            : <String, dynamic>{};

        // Remove the user from any existing emoji arrays first (enforce one reaction per user)
        String? existingEmojiOfUser;
        final updated = <String, List<String>>{};
        rawReactions.forEach((k, v) {
          final list = (v is List)
              ? v.whereType<String>().toList()
              : <String>[];
          if (list.contains(uid)) existingEmojiOfUser = k;
          updated[k] = list.where((x) => x != uid).toList();
        });

        // Toggle logic: if tapping the same emoji, leave user removed (unreact). Otherwise add to chosen emoji.
        if (existingEmojiOfUser != emoji) {
          final target = updated[emoji] ?? <String>[];
          if (!target.contains(uid)) target.add(uid);
          updated[emoji] = target;
        }

        // Clean up empty arrays to keep map tidy
        final cleaned = <String, dynamic>{};
        updated.forEach((k, v) {
          if (v.isNotEmpty) cleaned[k] = v;
        });

        tx.update(docRef, {'reactions': cleaned});
      });
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Failed to react: $e');
    }
  }

  Future<void> _editMessage(ChatMessage msg) async {
    final controller = TextEditingController(text: msg.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Update your message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newText == null) return;
    if (newText.isEmpty || newText == msg.text) return;
    try {
      await FirebaseFirestore.instance
          .collection('team.chat')
          .doc(msg.id)
          .update({'text': newText, 'editedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Failed to edit: $e');
    }
  }

  Future<void> _scrollToMessage(String id) async {
    final key = _itemKeys[id];
    if (key != null) {
      final ctx = key.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
        );
      }
    }
  }

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        // With reverse: true, the 'bottom' aligns to offset 0.0
        const double position = 0.0;
        if (animate) {
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(position);
        }
      }
    });
  }

  void _sortVisibleDesc() {}

  bool _reactionsEqual(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      final la = a[k] ?? const <String>[];
      final lb = b[k] ?? const <String>[];
      if (la.length != lb.length) return false;
      final sa = la.toSet();
      final sb = lb.toSet();
      if (sa.length != sb.length) return false;
      if (!sa.containsAll(sb)) return false;
    }
    return true;
  }

  Future<void> _confirmDelete(ChatMessage msg) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (res == true) {
      try {
        final idx = _visibleMessages.indexWhere((m) => m.id == msg.id);
        if (idx != -1) {
          final current = _visibleMessages[idx];
          setState(() {
            _visibleMessages[idx] = ChatMessage(
              id: current.id,
              senderId: current.senderId,
              text: current.text,
              timestamp: current.timestamp,
              senderName: current.senderName,
              isTyping: false,
              isDeleted: true,
              editedAt: current.editedAt,
              replyTo: current.replyTo,
              replyToText: current.replyToText,
              replyToSender: current.replyToSender,
              reactions: current.reactions,
              attachmentUrl: current.attachmentUrl,
              attachmentName: current.attachmentName,
              attachmentType: current.attachmentType,
              attachmentSizeBytes: current.attachmentSizeBytes,
              goalId: current.goalId,
              goalTitle: current.goalTitle,
            );
          });
        }
        await FirebaseFirestore.instance
            .collection('team.chat')
            .doc(msg.id)
            .update({
              'isDeleted': true,
              'deletedAt': FieldValue.serverTimestamp(),
              'deletedBy': FirebaseAuth.instance.currentUser?.uid,
            });
      } catch (e) {
        if (!mounted) return;
        await _showCenterNotice(context, 'Failed to delete: $e');
      }
    }
  }

  Future<void> _pickGoalContext() async {
    final existingTitles =
        _visibleMessages
            .map((m) => m.goalTitle)
            .whereType<String>()
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F1629),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Link message to a goal topic',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (existingTitles.isNotEmpty)
                ...existingTitles.map(
                  (title) => ListTile(
                    title: Text(
                      title,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () => Navigator.pop(ctx, title),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.white),
                title: const Text(
                  'Create new goal topic',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  final controller = TextEditingController();
                  final newTitle = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('New goal topic'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Enter goal or topic title',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, controller.text.trim()),
                            child: const Text('Save'),
                          ),
                        ],
                      );
                    },
                  );
                  if (newTitle != null && newTitle.trim().isNotEmpty) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(ctx, newTitle.trim());
                  } else {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
    if (choice == null || choice.isEmpty) return;
    setState(() {
      _selectedGoalTitle = choice;
      _selectedGoalId =
          'topic_${choice.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/khono_bg.png', fit: BoxFit.cover),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0F1F), Color(0x001F2840)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTranslucentContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final user = FirebaseAuth.instance.currentUser;
                              final name =
                                  _displayName ??
                                  user?.displayName ??
                                  user?.email ??
                                  '';
                              return Row(
                                children: [
                                  if (_profilePhotoUrl != null &&
                                      _profilePhotoUrl!.isNotEmpty)
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage(
                                        _profilePhotoUrl!,
                                      ),
                                      backgroundColor: Colors.white24,
                                    )
                                  else
                                    const Icon(
                                      Icons.person_outline,
                                      color: Colors.white,
                                    ),
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: name.isEmpty
                                        ? 'Not signed in'
                                        : name,
                                    child: Text(
                                      name.isEmpty ? 'Guest' : name,
                                      style: const TextStyle(
                                        color: chatPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: _displayName?.isEmpty ?? true
                                        ? 'Not signed in'
                                        : _displayName,
                                    child: Text(
                                      (_displayName?.isEmpty ?? true)
                                          ? 'Guest'
                                          : _displayName!,
                                      style: const TextStyle(
                                        color: chatPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: !_showGoalOnly,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() {
                              _showGoalOnly = false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Goal discussions'),
                          selected: _showGoalOnly,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() {
                              _showGoalOnly = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<ChatMessage>>(
                      stream: FirebaseFirestore.instance
                          .collection('team.chat')
                          .orderBy('clientAt', descending: true)
                          .snapshots()
                          .handleError((error) {
                            // Silently handle errors to prevent unmount errors
                            developer.log('Error in team chat stream: $error');
                          })
                          .map(
                            (snapshot) => snapshot.docs.map((doc) {
                              final data = doc.data();
                              final ts = data['timestamp'];
                              final ca = data['clientAt'];
                              DateTime dt;
                              if (ts is Timestamp) {
                                dt = ts.toDate();
                              } else if (ca is Timestamp) {
                                dt = ca.toDate();
                              } else {
                                dt = DateTime.now();
                              }
                              final dynamic rawText = data['text'];
                              final String safeText = rawText is String
                                  ? rawText
                                  : '';
                              final dynamic rawSenderId = data['senderId'];
                              final String safeSenderId = rawSenderId is String
                                  ? rawSenderId
                                  : '';
                              final dynamic rawSenderName = data['senderName'];
                              final String safeSenderName =
                                  rawSenderName is String ? rawSenderName : '';
                              final dynamic rawDeleted = data['isDeleted'];
                              final bool safeDeleted = rawDeleted is bool
                                  ? rawDeleted
                                  : false;
                              final dynamic rawEdited = data['editedAt'];
                              final DateTime? safeEdited =
                                  rawEdited is Timestamp
                                  ? rawEdited.toDate()
                                  : null;
                              final String? replyTo =
                                  (data['replyTo'] is String)
                                  ? data['replyTo'] as String
                                  : null;
                              final String? replyToText =
                                  (data['replyToText'] is String)
                                  ? data['replyToText'] as String
                                  : null;
                              final String? replyToSender =
                                  (data['replyToSender'] is String)
                                  ? data['replyToSender'] as String
                                  : null;
                              final Map<String, List<String>> safeReactions =
                                  {};
                              if (data['reactions'] is Map) {
                                final m = Map<String, dynamic>.from(
                                  data['reactions'] as Map,
                                );
                                m.forEach((k, v) {
                                  if (v is List) {
                                    safeReactions[k] = v
                                        .whereType<String>()
                                        .toList();
                                  }
                                });
                              }
                              final String? attachmentUrl =
                                  (data['attachmentUrl'] is String)
                                  ? data['attachmentUrl'] as String
                                  : null;
                              final String? attachmentName =
                                  (data['attachmentName'] is String)
                                  ? data['attachmentName'] as String
                                  : null;
                              final String? attachmentType =
                                  (data['attachmentType'] is String)
                                  ? data['attachmentType'] as String
                                  : null;
                              final int? attachmentSizeBytes =
                                  data['attachmentSizeBytes'] is int
                                  ? data['attachmentSizeBytes'] as int
                                  : (data['attachmentSizeBytes'] is num
                                        ? (data['attachmentSizeBytes'] as num)
                                              .round()
                                        : null);
                              final String? goalId = (data['goalId'] is String)
                                  ? data['goalId'] as String
                                  : null;
                              final String? goalTitle =
                                  (data['goalTitle'] is String)
                                  ? data['goalTitle'] as String
                                  : null;
                              return ChatMessage(
                                id: doc.id,
                                senderId: safeSenderId,
                                text: safeText,
                                timestamp: dt,
                                senderName: safeSenderName,
                                isDeleted: safeDeleted,
                                editedAt: safeEdited,
                                replyTo: replyTo,
                                replyToText: replyToText,
                                replyToSender: replyToSender,
                                reactions: safeReactions,
                                attachmentUrl: attachmentUrl,
                                attachmentName: attachmentName,
                                attachmentType: attachmentType,
                                attachmentSizeBytes: attachmentSizeBytes,
                                goalId: goalId,
                                goalTitle: goalTitle,
                              );
                            }).toList(),
                          ),
                      initialData: const <ChatMessage>[],
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !_initializedStream) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: chatPrimary,
                            ),
                          );
                        }
                        final incoming = snapshot.data ?? const <ChatMessage>[];
                        if (!_initializedStream) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || _initializedStream) return;
                            setState(() {
                              _visibleMessages.clear();
                              for (final m in incoming) {
                                _visibleMessages.add(m);
                                _processedIds.add(m.id);
                              }
                              _initializedStream = true;
                              _sortVisibleDesc();
                            });
                            _scrollToBottom();
                          });
                        } else {
                          bool changed = false;
                          final currentUserId =
                              FirebaseAuth.instance.currentUser?.uid;
                          for (final m in incoming) {
                            if (_processedIds.contains(m.id)) {
                              final idx = _visibleMessages.indexWhere(
                                (x) => x.id == m.id,
                              );
                              if (idx != -1) {
                                final current = _visibleMessages[idx];
                                final bool canReplaceNow =
                                    (!current.isTyping) || m.isDeleted;
                                if (canReplaceNow) {
                                  final bool different =
                                      current.text != m.text ||
                                      current.isDeleted != m.isDeleted ||
                                      current.senderName != m.senderName ||
                                      current.timestamp != m.timestamp ||
                                      current.editedAt != m.editedAt ||
                                      current.replyTo != m.replyTo ||
                                      current.replyToText != m.replyToText ||
                                      current.replyToSender !=
                                          m.replyToSender ||
                                      !_reactionsEqual(
                                        current.reactions,
                                        m.reactions,
                                      );
                                  if (different) {
                                    _visibleMessages[idx] = m;
                                    changed = true;
                                  }
                                }
                              }
                              continue;
                            }
                            _processedIds.add(m.id);
                            if (currentUserId != null &&
                                m.senderId == currentUserId) {
                              _visibleMessages.add(m);
                              changed = true;
                            } else {
                              final placeholder = ChatMessage(
                                id: m.id,
                                senderId: m.senderId,
                                text: '',
                                timestamp: m.timestamp,
                                senderName: m.senderName,
                                isTyping: true,
                                isDeleted: m.isDeleted,
                              );
                              _visibleMessages.add(placeholder);
                              _typingTimers[m.id]?.cancel();
                              _typingTimers[m.id] = Timer(
                                const Duration(seconds: 5),
                                () {
                                  if (!mounted) return;
                                  final idx = _visibleMessages.indexWhere(
                                    (x) => x.id == m.id,
                                  );
                                  if (idx != -1) {
                                    setState(() {
                                      _visibleMessages[idx] = m;
                                    });
                                  }
                                },
                              );
                              changed = true;
                            }
                          }
                          if (changed) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() {});
                              _scrollToBottom(animate: true);
                            });
                          }
                        }
                        if (_visibleMessages.isEmpty) {
                          return const Center(
                            child: Text(
                              'Start the conversation! No messages yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        final displayedMessages = _showGoalOnly
                            ? _visibleMessages
                                  .where((m) => m.goalId != null)
                                  .toList()
                            : List<ChatMessage>.from(_visibleMessages);
                        if (displayedMessages.isEmpty) {
                          return const Center(
                            child: Text(
                              'No goal discussions yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        return ListView.builder(
                          reverse: true,
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: displayedMessages.length,
                          itemBuilder: (context, index) {
                            final m = displayedMessages[index];
                            return KeyedSubtree(
                              key: ValueKey(m.id),
                              child: _buildMessageBubble(m),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _buildTranslucentContainer(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_replyingTo != null)
                            Container(
                              margin: const EdgeInsets.only(
                                right: 8,
                                bottom: 8,
                              ),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _replyingTo!.senderName ??
                                              _replyingTo!.senderId,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _replyingTo!.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white60,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        setState(() => _replyingTo = null),
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          if (_selectedGoalTitle != null &&
                              _selectedGoalTitle!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.flag_outlined,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedGoalTitle!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedGoalId = null;
                                        _selectedGoalTitle = null;
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_pendingAttachmentName != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _pendingAttachmentType == 'image'
                                        ? Icons.image
                                        : Icons.attach_file,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _pendingAttachmentName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _clearPendingAttachment,
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: _pickGoalContext,
                                icon: const Icon(
                                  Icons.flag_outlined,
                                  color: Colors.white70,
                                ),
                              ),
                              IconButton(
                                onPressed: _pickAttachment,
                                icon: const Icon(
                                  Icons.attach_file,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 4),
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
                                      hintStyle: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 16,
                                          ),
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
                                child: IconButton(
                                  onPressed: _handleSend,
                                  icon: Image.asset(
                                    'assets/Send_Paper_Plane/send_plane.png',
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.contain,
                                  ),
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    minWidth: 56,
                                    minHeight: 56,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
