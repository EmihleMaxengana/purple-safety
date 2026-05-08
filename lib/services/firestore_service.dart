import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/home/home_screen.dart';

class Alert {
  final String id;
  final String message;
  final String type;
  final DateTime timestamp;
  bool read;
  final String? incidentId;
  final String? incidentTitle;

  Alert({
    required this.id,
    required this.message,
    required this.type,
    required this.timestamp,
    this.read = false,
    this.incidentId,
    this.incidentTitle,
  });

  factory Alert.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Alert(
      id: doc.id,
      message: data['message'],
      type: data['type'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      read: data['read'] ?? false,
      incidentId: data['incidentId'],
      incidentTitle: data['incidentTitle'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
      'incidentId': incidentId,
      'incidentTitle': incidentTitle,
    };
  }
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> addContact(String userId, Contact contact) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contact.id)
        .set(contact.toFirestore());
  }

  Future<void> deleteContact(String userId, String contactId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }

  Future<void> updateContact(String userId, Contact contact) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contact.id)
        .update(contact.toFirestore());
  }

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

  Future<void> markAlertAsRead(String userId, String alertId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('alerts')
        .doc(alertId)
        .update({'read': true});
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
}