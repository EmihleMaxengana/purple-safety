import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/incident_model.dart';

class IncidentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createIncident(Incident incident) async {
    try {
      // Calculate expiration date (24 hours from now)
      final expiresAt = DateTime.now().add(const Duration(hours: 24));
      
      final incidentWithExpiry = Incident(
        id: incident.id,
        userId: incident.userId,
        userName: incident.userName,
        userPhone: incident.userPhone,
        alternativePhone: incident.alternativePhone,
        isAnonymous: incident.isAnonymous,
        title: incident.title,
        description: incident.description,
        type: incident.type,
        missingPersonName: incident.missingPersonName,
        missingPersonAge: incident.missingPersonAge,
        lastSeenLocation: incident.lastSeenLocation,
        missingPersonImageUrl: incident.missingPersonImageUrl,
        location: incident.location,
        latitude: incident.latitude,
        longitude: incident.longitude,
        imageUrls: incident.imageUrls,
        videoUrls: incident.videoUrls,
        timestamp: incident.timestamp,
        commentCount: 0,
        shareCount: 0,
        isResolved: false,
        isFound: false,
        foundAt: null,
        expiresAt: expiresAt,  // NEW: Auto-delete after 24 hours
      );
      
      await _firestore.collection('incidents').doc(incident.id).set(incidentWithExpiry.toFirestore());
      await sendIncidentNotification(incident);
    } catch (e) {
      print('Error creating incident: $e');
      throw e;
    }
  }

  // NEW: Mark incident as found
  Future<void> markAsFound(String incidentId) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('incidents').doc(incidentId).update({
        'isFound': true,
        'foundAt': Timestamp.fromDate(now),
      });
      
      // Add a global alert that the person was found
      await _firestore.collection('global_alerts').add({
        'type': 'found',
        'message': '✅ GOOD NEWS: A missing person has been found and is safe!',
        'incidentId': incidentId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('✅ Incident $incidentId marked as found');
    } catch (e) {
      print('Error marking incident as found: $e');
      throw e;
    }
  }

  // NEW: Delete expired incidents (called periodically)
  Future<void> deleteExpiredIncidents() async {
    try {
      final now = DateTime.now();
      final expiredIncidents = await _firestore
          .collection('incidents')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();
      
      final batch = _firestore.batch();
      for (var doc in expiredIncidents.docs) {
        batch.delete(doc.reference);
        print('🗑️ Deleted expired incident: ${doc.id}');
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting expired incidents: $e');
    }
  }

  // NEW: Get only active incidents (not found and not expired)
  Stream<List<Incident>> getActiveIncidents() {
    final now = DateTime.now();
    return _firestore
        .collection('incidents')
        .where('isFound', isEqualTo: false)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Incident.fromFirestore(doc))
            .toList());
  }

  // Keep original method for backward compatibility
  Stream<List<Incident>> getAllIncidents() {
    final now = DateTime.now();
    return _firestore
        .collection('incidents')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Incident.fromFirestore(doc))
            .toList());
  }

  Stream<List<Incident>> getIncidentsByType(IncidentType type) {
    final now = DateTime.now();
    return _firestore
        .collection('incidents')
        .where('type', isEqualTo: type.toString())
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
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
}