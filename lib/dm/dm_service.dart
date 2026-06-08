import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DmService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------------------------------
  // Chat & Messaging
  // -------------------------------

  /// Get or create a consistent chat ID for two users (sorted IDs)
  static String getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Stream of messages for a conversation
  static Stream<QuerySnapshot> getConversationStream(String userId1, String userId2) {
    final chatId = getChatId(userId1, userId2);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Send a text message (stores in chat subcollection + recipient's DM inbox)
  static Future<void> sendTextMessage({
    required String recipientUserId,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    final chatId = getChatId(senderId, recipientUserId);
    final messageData = {
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
      'type': 'text',
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'chatId': chatId,
    });
  }

  /// Send a trip share message (only appears in inbox)
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

  /// Stream of all DMs for a user (inbox)
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

  /// Mark a DM as read
  static Future<void> markAsRead(String userId, String messageId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('dms')
        .doc(messageId)
        .update({'read': true});
  }

  // -------------------------------
  // User profiles & auto‑share
  // -------------------------------

  /// Get all users with full profile (excluding current user)
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

  /// Get user name by ID
  static Future<String> getUserName(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['name'] ?? 'User';
  }

  /// Get saved auto‑share recipients list
  static Future<List<String>> getSelectedRecipients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final List<dynamic> list = doc.data()?['dmRecipients'] ?? [];
    return list.cast<String>();
  }

  /// Save auto‑share recipients list
  static Future<void> saveSelectedRecipients(List<String> recipientIds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'dmRecipients': recipientIds,
    });
  }
}