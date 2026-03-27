import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/home/home_screen.dart'; // for Contact model

class Alert {
  final String id;
  final String message;
  final String type; // 'warning', 'info', etc.
  final DateTime timestamp;
  bool read;

  Alert({
    required this.id,
    required this.message,
    required this.type,
    required this.timestamp,
    this.read = false,
  });

  factory Alert.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Alert(
      id: doc.id,
      message: data['message'],
      type: data['type'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      read: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
    };
  }
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Contacts subcollection for a user
  Stream<List<Contact>> getContactsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Contact.fromFirestore(doc)).toList(),
        );
  }

  // Add a contact
  Future<void> addContact(String userId, Contact contact) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contact.id)
        .set(contact.toFirestore());
  }

  // Delete a contact
  Future<void> deleteContact(String userId, String contactId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }

  // Update a contact (if needed)
  Future<void> updateContact(String userId, Contact contact) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contact.id)
        .update(contact.toFirestore());
  }

  // Save an SOS alert
  Future<void> saveAlert(String userId, Map<String, dynamic> alertData) async {
    await _firestore.collection('alerts').add({
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      ...alertData,
    });
  }

  // NEW: Alerts subcollection for a user
  Stream<List<Alert>> getAlertsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Alert.fromFirestore(doc)).toList(),
        );
  }

  Future<void> markAllAlertsAsRead(String userId) async {
    final batch = _firestore.batch();
    final alerts = await _firestore
        .collection('users')
        .doc(userId)
        .collection('alerts')
        .where('read', isEqualTo: false)
        .get();
    for (var doc in alerts.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> addAlert(String userId, String message, String type) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('alerts')
        .add(
          Alert(
            id: '',
            message: message,
            type: type,
            timestamp: DateTime.now(),
            read: false,
          ).toFirestore(),
        );
  }
}
