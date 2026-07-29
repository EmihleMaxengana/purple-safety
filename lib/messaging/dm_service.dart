import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purple_safety/services/storage_service.dart';

class DmService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  static Future<String> getUserName(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['name'] ?? 'User';
  }

  // send text message
  static Future<void> sendTextMessage({
    required String recipientUserId,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    if (recipientUserId == senderId) {
      throw Exception('You cannot send a message to yourself');
    }

    final chatId = getChatId(senderId, recipientUserId);
    final recipientName = await getUserName(recipientUserId);

    final messageData = {
      'type': 'text',
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'recipientId': recipientUserId,
      'recipientName': recipientName,
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

    await _firestore
        .collection('users')
        .doc(senderId)
        .collection('dms')
        .add({
      ...messageData,
      'chatId': chatId,
    });
  }

  // send image message
  static Future<void> sendImageMessage({
    required String recipientUserId,
    required String senderId,
    required String senderName,
    required File imageFile,
  }) async {
    if (recipientUserId == senderId) {
      throw Exception('You cannot send a message to yourself');
    }

    final chatId = getChatId(senderId, recipientUserId);
    final recipientName = await getUserName(recipientUserId);

    final String imageUrl = await StorageService.uploadDMImage(
      file: imageFile,
      userId: senderId,
      chatId: chatId,
    );

    final messageData = {
      'type': 'image',
      'imageUrl': imageUrl,
      'senderId': senderId,
      'senderName': senderName,
      'recipientId': recipientUserId,
      'recipientName': recipientName,
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

    await _firestore
        .collection('users')
        .doc(senderId)
        .collection('dms')
        .add({
      ...messageData,
      'chatId': chatId,
    });
  }

  // send video message
  static Future<void> sendVideoMessage({
    required String recipientUserId,
    required String senderId,
    required String senderName,
    required File videoFile,
  }) async {
    if (recipientUserId == senderId) {
      throw Exception('You cannot send a message to yourself');
    }

    final chatId = getChatId(senderId, recipientUserId);
    final recipientName = await getUserName(recipientUserId);

    final String videoUrl = await StorageService.uploadDMVideo(
      file: videoFile,
      userId: senderId,
      chatId: chatId,
    );

    final messageData = {
      'type': 'video',
      'videoUrl': videoUrl,
      'senderId': senderId,
      'senderName': senderName,
      'recipientId': recipientUserId,
      'recipientName': recipientName,
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

    await _firestore
        .collection('users')
        .doc(senderId)
        .collection('dms')
        .add({
      ...messageData,
      'chatId': chatId,
    });
  }

  // send audio message
  static Future<void> sendAudioMessage({
    required String recipientUserId,
    required String senderId,
    required String senderName,
    required File audioFile,
  }) async {
    if (recipientUserId == senderId) {
      throw Exception('You cannot send a message to yourself');
    }

    final chatId = getChatId(senderId, recipientUserId);
    final recipientName = await getUserName(recipientUserId);

    final String audioUrl = await StorageService.uploadDMAudio(
      file: audioFile,
      userId: senderId,
      chatId: chatId,
    );

    final messageData = {
      'type': 'audio',
      'audioUrl': audioUrl,
      'senderId': senderId,
      'senderName': senderName,
      'recipientId': recipientUserId,
      'recipientName': recipientName,
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

    await _firestore
        .collection('users')
        .doc(senderId)
        .collection('dms')
        .add({
      ...messageData,
      'chatId': chatId,
    });
  }

  // send trip id message
  static Future<void> sendTripIdMessage({
    required String recipientUserId,
    required String senderName,
    required String tripId,
    required String senderId,
  }) async {
    if (recipientUserId == senderId) {
      throw Exception('You cannot share a trip with yourself');
    }

    final recipientName = await getUserName(recipientUserId);

    final messageData = {
      'type': 'trip_share',
      'senderId': senderId,
      'senderName': senderName,
      'recipientId': recipientUserId,
      'recipientName': recipientName,
      'tripId': tripId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    await _firestore
        .collection('users')
        .doc(recipientUserId)
        .collection('dms')
        .add(messageData);

    await _firestore
        .collection('users')
        .doc(senderId)
        .collection('dms')
        .add({
      ...messageData,
    });
  }

  // get messages stream
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

  // get unread count stream
  static Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('dms')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // get conversation stream
  static Stream<QuerySnapshot> getConversationStream(String userId1, String userId2) {
    final chatId = getChatId(userId1, userId2);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // mark as read
  static Future<void> markAsRead(String userId, String messageId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('dms')
        .doc(messageId)
        .update({'read': true});
  }

  // mark all from sender as read
  static Future<void> markAllFromSenderAsRead(String userId, String senderId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('dms')
        .where('senderId', isEqualTo: senderId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // get all users with profile
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

  // get selected recipients
  static Future<List<String>> getSelectedRecipients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final List<dynamic> list = doc.data()?['dmRecipients'] ?? [];
    return list.cast<String>();
  }

  // save selected recipients
  static Future<void> saveSelectedRecipients(List<String> recipientIds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'dmRecipients': recipientIds,
    });
  }
}