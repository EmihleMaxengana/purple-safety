import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:purple_safety/messaging/dm_service.dart';
import 'package:purple_safety/services/storage_service.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;

  const ChatScreen({
    Key? key,
    required this.recipientId,
    required this.recipientName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentUserId = '';
  String _currentUserName = '';
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingAudioUrl;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _currentUserId = user.uid);
      final name = await DmService.getUserName(user.uid);
      setState(() => _currentUserName = name);
    }
  }

  //(show popup dialog)
  void _showPopup(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Info'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  //(show edit dialog)
  void _showEditDialog(String messageId, String currentMessage) {
    final TextEditingController editController = TextEditingController(text: currentMessage);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty) {
                _showPopup(context, 'Message cannot be empty');
                return;
              }
              if (newText == currentMessage) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context);
              await _editMessage(messageId, newText);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            child: const Text('Save'),
          ),
        ],
        backgroundColor: const Color(0xFF1a0f2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.purple.withOpacity(0.3)),
        ),
      ),
    );
  }

  //(edit message)
  Future<void> _editMessage(String messageId, String newText) async {
    try {
      final chatId = DmService.getChatId(_currentUserId, widget.recipientId);
      final now = DateTime.now();

      //(get the current edit history)
      final docSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      final existingData = docSnapshot.data() as Map<String, dynamic>?;
      List<dynamic> existingHistory = existingData?['editHistory'] ?? [];

      //(create new history entry with plain timestamp string)
      final newHistoryEntry = {
        'message': newText,
        'timestamp': now.toIso8601String(),
      };

      //(update the message in the chat collection)
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
            'message': newText,
            'edited': true,
            'editedAt': now.toIso8601String(),
            'editHistory': [...existingHistory, newHistoryEntry],
          });

      //(update the message in both users' DM collections)
      final senderDmQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('dms')
          .where(FieldPath.documentId, isEqualTo: messageId)
          .get();

      if (senderDmQuery.docs.isNotEmpty) {
        await senderDmQuery.docs.first.reference.update({
          'message': newText,
          'edited': true,
          'editedAt': now.toIso8601String(),
        });
      }

      final recipientDmQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.recipientId)
          .collection('dms')
          .where(FieldPath.documentId, isEqualTo: messageId)
          .get();

      if (recipientDmQuery.docs.isNotEmpty) {
        await recipientDmQuery.docs.first.reference.update({
          'message': newText,
          'edited': true,
          'editedAt': now.toIso8601String(),
        });
      }
    } catch (e) {
      _showPopup(context, 'Failed to edit message: $e');
    }
  }

  //(delete message - replaces with "Message deleted")
  Future<void> _deleteMessage(String messageId) async {
    try {
      final chatId = DmService.getChatId(_currentUserId, widget.recipientId);
      final now = DateTime.now();

      //(update the message in the chat collection)
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
            'message': 'Message deleted',
            'deleted': true,
            'deletedAt': now.toIso8601String(),
          });

      //(update the message in both users' DM collections)
      final senderDmQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('dms')
          .where(FieldPath.documentId, isEqualTo: messageId)
          .get();

      if (senderDmQuery.docs.isNotEmpty) {
        await senderDmQuery.docs.first.reference.update({
          'message': 'Message deleted',
          'deleted': true,
          'deletedAt': now.toIso8601String(),
        });
      }

      final recipientDmQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.recipientId)
          .collection('dms')
          .where(FieldPath.documentId, isEqualTo: messageId)
          .get();

      if (recipientDmQuery.docs.isNotEmpty) {
        await recipientDmQuery.docs.first.reference.update({
          'message': 'Message deleted',
          'deleted': true,
          'deletedAt': now.toIso8601String(),
        });
      }
    } catch (e) {
      _showPopup(context, 'Failed to delete message: $e');
    }
  }

  //(show long-press menu for sent messages)
  void _showMessageOptions(String messageId, String currentMessage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1a0f2e),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Message Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text(
                'Edit Message',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(messageId, currentMessage);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Message',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                //(close the bottom sheet immediately)
                Navigator.pop(context);

                //(show confirmation dialog)
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Message'),
                    content: const Text('Are you sure you want to delete this message?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                    backgroundColor: const Color(0xFF1a0f2e),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.purple.withOpacity(0.3)),
                    ),
                  ),
                );

                if (confirm == true) {
                  await _deleteMessage(messageId);
                }
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------
  // SEND TEXT
  // -------------------------------
  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await DmService.sendTextMessage(
      recipientUserId: widget.recipientId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      message: text,
    );
    _scrollToBottom();
  }

  // -------------------------------
  // SEND IMAGE
  // -------------------------------
  Future<void> _sendImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    await DmService.sendImageMessage(
      recipientUserId: widget.recipientId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      imageFile: file,
    );
    _scrollToBottom();
  }

  // -------------------------------
  // SEND VIDEO
  // -------------------------------
  Future<void> _sendVideo() async {
    final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    await DmService.sendVideoMessage(
      recipientUserId: widget.recipientId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      videoFile: file,
    );
    _scrollToBottom();
  }

  // -------------------------------
  // SEND AUDIO
  // -------------------------------
  Future<void> _sendAudio() async {
    _showPopup(context, 'Audio recording not implemented here. Use Safety Tools.');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // -------------------------------
  // PLAY AUDIO
  // -------------------------------
  Future<void> _toggleAudio(String url) async {
    if (_currentlyPlayingAudioUrl == url && _isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else if (_currentlyPlayingAudioUrl == url && !_isPlaying) {
      await _audioPlayer.resume();
      setState(() => _isPlaying = true);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() {
        _currentlyPlayingAudioUrl = url;
        _isPlaying = true;
      });
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() => _isPlaying = false);
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0e0718),
      appBar: AppBar(
        title: Text(widget.recipientName, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DmService.getConversationStream(_currentUserId, widget.recipientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.purple));
                }
                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.\nSend a message below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  reverse: false,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    final type = data['type'] ?? 'text';
                    final isDeleted = data['deleted'] == true;
                    final isEdited = data['edited'] == true;

                    //(only allow long-press on messages sent by current user, not deleted)
                    final canLongPress = isMe && !isDeleted;

                    return GestureDetector(
                      onLongPress: canLongPress
                          ? () {
                              //(long press 3 seconds)
                              Future.delayed(const Duration(seconds: 3), () {
                                if (mounted && isMe && !isDeleted) {
                                  final currentMessage = data['message'] ?? '';
                                  _showMessageOptions(doc.id, currentMessage);
                                }
                              });
                            }
                          : null,
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF6A1B9A) : const Color(0xFF2a1f3e),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isEdited && !isDeleted)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'edited',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              _buildMessageContent(type, data),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          //(input row with attachment buttons)
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF1a0f2e),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.blue, size: 24),
                  onPressed: _sendImage,
                  tooltip: 'Send Image',
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.green, size: 24),
                  onPressed: _sendVideo,
                  tooltip: 'Send Video',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFBF7DCB)),
                  onPressed: _sendTextMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String type, Map<String, dynamic> data) {
    final isDeleted = data['deleted'] == true;

    if (isDeleted) {
      return const Text(
        'Message deleted',
        style: TextStyle(
          color: Colors.white54,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    switch (type) {
      case 'image':
        final imageUrl = data['imageUrl'] as String?;
        if (imageUrl == null) return const Text('Image unavailable');
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  body: Center(
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[800],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image, color: Colors.white54),
                );
              },
            ),
          ),
        );

      case 'video':
        final videoUrl = data['videoUrl'] as String?;
        if (videoUrl == null) return const Text('Video unavailable');
        return GestureDetector(
          onTap: () {
            _showPopup(context, 'Video player coming soon.');
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                color: Colors.grey[800],
                child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 60),
              ),
            ],
          ),
        );

      case 'audio':
        final audioUrl = data['audioUrl'] as String?;
        if (audioUrl == null) return const Text('Audio unavailable');
        final isCurrent = _currentlyPlayingAudioUrl == audioUrl;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                (isCurrent && _isPlaying) ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () => _toggleAudio(audioUrl),
            ),
            Expanded(
              child: Text(
                isCurrent && _isPlaying ? 'Playing...' : 'Audio message',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );

      case 'trip_share':
        final tripId = data['tripId'] ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Shared Trip ID', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/full_map', arguments: tripId);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tripId,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );

      default:
        //(text)
        return Text(
          data['message'] ?? '',
          style: const TextStyle(color: Colors.white),
        );
    }
  }
}