import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/incident_model.dart';

class IncidentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createIncident(Incident incident) async {
    try {
      await _firestore.collection('incidents').doc(incident.id).set(incident.toFirestore());
      await sendIncidentNotification(incident);
    } catch (e) {
      print('Error creating incident: $e');
      throw e;
    }
  }

  Future<void> sendIncidentNotification(Incident incident) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final currentUser = _auth.currentUser;
      
      String notificationTitle = incident.isAnonymous 
          ? '📢 New Incident Reported' 
          : '📢 ${incident.userName} reported an incident';
      
      String notificationBody = incident.type == IncidentType.missingPerson
          ? '🔍 MISSING: ${incident.missingPersonName} - ${incident.title}'
          : incident.title;
      
      for (var userDoc in usersSnapshot.docs) {
        if (currentUser != null && userDoc.id == currentUser.uid) continue;
        
        await _firestore.collection('users').doc(userDoc.id).collection('alerts').add({
          'message': '$notificationTitle\n$notificationBody',
          'type': 'incident',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'incidentId': incident.id,
          'incidentTitle': incident.title,
        });
      }
      
      print('Notifications sent to ${usersSnapshot.docs.length - 1} users');
    } catch (e) {
      print('Error sending incident notifications: $e');
    }
  }

  Stream<List<Incident>> getAllIncidents() {
    return _firestore
        .collection('incidents')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Incident.fromFirestore(doc))
            .toList());
  }

  Stream<List<Incident>> getIncidentsByType(IncidentType type) {
    return _firestore
        .collection('incidents')
        .where('type', isEqualTo: type.toString())
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Incident.fromFirestore(doc))
            .toList());
  }

  Future<Incident?> getIncident(String incidentId) async {
    try {
      final doc = await _firestore.collection('incidents').doc(incidentId).get();
      if (doc.exists) {
        return Incident.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting incident: $e');
      return null;
    }
  }

  Future<void> addComment({
    required String incidentId,
    required String comment,
    bool isAnonymous = false,
  }) async {
    try {
      final user = _auth.currentUser;
      String userId = isAnonymous ? 'anonymous' : (user?.uid ?? 'anonymous');
      String? userName;
      
      if (!isAnonymous && user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        userName = userDoc.data()?['name'] ?? 'User';
      }

      final commentData = {
        'userId': userId,
        'userName': isAnonymous ? 'Anonymous' : userName,
        'isAnonymous': isAnonymous,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('incidents')
          .doc(incidentId)
          .collection('comments')
          .add(commentData);

      await _firestore.collection('incidents').doc(incidentId).update({
        'commentCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error adding comment: $e');
      throw e;
    }
  }

  Stream<List<IncidentComment>> getComments(String incidentId) {
    return _firestore
        .collection('incidents')
        .doc(incidentId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IncidentComment.fromFirestore(doc, incidentId))
            .toList());
  }

  Future<void> shareIncident(String incidentId) async {
    try {
      await _firestore.collection('incidents').doc(incidentId).update({
        'shareCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error sharing incident: $e');
    }
  }
}