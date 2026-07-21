import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purple_safety/services/storage_service.dart';

class DmService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------------------------------
  // Chat ID helper
  // -------------------------------
  static String getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  // -------------------------------
  // Send text message (existing)
  // -------------------------------
  static Future<void> sendTextMessage({
    required String recipientUserId,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    final chatId = getChatId(senderId, recipientUserId);
    final messageData = {
      'type': 'text',
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    // Add to chat messages subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Also store a copy in recipient's DM inbox for easy listing
    await _firestore
        .collection('users')
        .doc(recipientUserId)
        .collection('dms')
        .add({
      ...messageData,
      'chatId': chatId,
    });
  }

  // -------------------------------
  // Send image message (NEW)
  // -------------------------------
  static Future<void> sendImageMessage({
    required String recipientUserId,
    required String senderId,
    required String senderName,
    required File imageFile,
  }) async {
    final chatId = getChatId(senderId, recipientUserId);

    // 1. Upload to Firebase Storage
    final String imageUrl = await StorageService.uploadDMImage(imageFile, chatId);

    // 2. Build message data
    final messageData = {
      'type': 'image',
      'imageUrl': imageUrl,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    // 3. Store in chat subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // 4. Store in recipient's DM inbox
    await _firestore
        .collection('users')
        .doc(recipientUserId)
        .collection('dms')
        .add({
      ...messageData,
      'chatId': chatId,
    });
  }

  // -------------------------------
  // Send video message (NEW)
  // -------------------------------
  static Future<void> sendVideoMessage({
    required String recipientUserId,
    required String senderId,
    required String senderName,
    required File videoFile,
  }) async {
    final chatId = getChatId(senderId, recipientUserId);

    final String videoUrl = await StorageService.uploadDMVideo(videoFile, chatId);

    final messageData = {
      'type': 'video',
      'videoUrl': videoUrl,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    await _firestore
        .collection('users')
        .doc(recipientUserId)
        .collection('dms')
        .add({
      ...messageData,
      'chatId': chatId,
    });
  }

  // -------------------------------
  // Send audio message (NEW)
  // -------------------------------
  static Future<void> sendAudioMessage({
    required String recipientUserId,
    required String senderId,
    required String senderName,
    required File audioFile,
  }) async {
    final chatId = getChatId(senderId, recipientUserId);

    final String audioUrl = await StorageService.uploadDMAudio(audioFile, chatId);

    final messageData = {
      'type': 'audio',
      'audioUrl': audioUrl,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    await _firestore
        .collection('users')
        .doc(recipientUserId)
        .collection('dms')
        .add({
      ...messageData,
      'chatId': chatId,
    });
  }

  // -------------------------------
  // Send trip share (existing)
  // -------------------------------
  static Future<void> sendTripIdMessage({
    required String recipientUserId,
    required String senderName,
    required String tripId,
    required String senderId,
  }) async {
    final message = {
      'type': 'trip_share',
      'senderId': senderId,
      'senderName': senderName,
      'tripId': tripId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };
    await _firestore
        .collection('users')
        .doc(recipientUserId)
        .collection('dms')
        .add(message);
  }

  // -------------------------------
  // Stream of DMs for inbox (updated to include media fields)
  // -------------------------------
  static Stream<List<Map<String, dynamic>>> getMessagesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('dms')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }

  // -------------------------------
  // Stream of conversation messages (updated to include media fields)
  // -------------------------------
  static Stream<QuerySnapshot> getConversationStream(String userId1, String userId2) {
    final chatId = getChatId(userId1, userId2);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // -------------------------------
  // Mark as read
  // -------------------------------
  static Future<void> markAsRead(String userId, String messageId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('dms')
        .doc(messageId)
        .update({'read': true});
  }

  // -------------------------------
  // User profile helpers (existing)
  // -------------------------------
  static Future<List<Map<String, dynamic>>> getAllUsersWithProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs
        .where((doc) => doc.id != currentUser.uid)
        .map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'User',
            'email': data['email'] ?? '',
            'gender': data['gender'] ?? 'Not specified',
            'nextOfKinName': data['nextOfKinName'] ?? '',
            'nextOfKinRelation': data['nextOfKinRelation'] ?? '',
          };
        }).toList();
  }

  static Future<String> getUserName(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['name'] ?? 'User';
  }

  static Future<List<String>> getSelectedRecipients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final List<dynamic> list = doc.data()?['dmRecipients'] ?? [];
    return list.cast<String>();
  }

  static Future<void> saveSelectedRecipients(List<String> recipientIds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'dmRecipients': recipientIds,
    });
  }
}