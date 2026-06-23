import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SOSEventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> createSOSEvent({
    required Position location,
    required String userId,
    required String userName,
  }) async {
    final activeQuery = await _firestore
        .collection('active_sos')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (activeQuery.docs.isNotEmpty) {
      // Update existing event
      await activeQuery.docs.first.reference.update({
        'location': GeoPoint(location.latitude, location.longitude),
        'timestamp': FieldValue.serverTimestamp(),
      });
      return;
    }

    await _firestore.collection('active_sos').add({
      'userId': userId,
      'userName': userName,
      'location': GeoPoint(location.latitude, location.longitude),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  static Future<void> endSOSEvent() async {
    final activeQuery = await _firestore
        .collection('active_sos')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    for (var doc in activeQuery.docs) {
      await doc.reference.update({'status': 'ended'});
    }
  }

  static Stream<DocumentSnapshot?> getActiveSOS() {
    return _firestore
        .collection('active_sos')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : null,
        );
  }

  static Stream<List<QueryDocumentSnapshot>> getActiveMembers() {
    return _firestore
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  static Future<List<dynamic>> fetchNearbyPoliceStations(
    double lat,
    double lng,
    String apiKey,
  ) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&type=police&key=$apiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['results'] ?? [];
    }
    return [];
  }

  static Stream<List<Map<String, dynamic>>> getChatMessages(String sosEventId) {
    return _firestore
        .collection('active_sos')
        .doc(sosEventId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'userId': data['userId'],
              'userName': data['userName'],
              'message': data['message'],
              'timestamp': data['timestamp'],
            };
          }).toList(),
        );
  }

  static Future<void> sendMessage(String sosEventId, String message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = (userDoc.data()?['name'] as String?) ?? 'Anonymous';

    await _firestore
        .collection('active_sos')
        .doc(sosEventId)
        .collection('messages')
        .add({
          'userId': user.uid,
          'userName': userName,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }
}
