import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripSharingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _locationTimer;
  static String? _currentTripId;
  static bool _isSharing = false;

  static bool get isSharing => _isSharing;
  static String? get currentTripId => _currentTripId;

  // Start sharing trip
  static Future<String> startSharing({
    required String userName,
    required double latitude,
    required double longitude,
    List<String>? sharedWithUserIds,
  }) async {
    // Stop any existing sharing
    if (_isSharing) {
      await stopSharing();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Create new trip document
    final tripRef = _firestore.collection('active_trips').doc();
    _currentTripId = tripRef.id;

    await tripRef.set({
      'tripId': _currentTripId,
      'userId': user.uid,
      'userName': userName,
      'currentLatitude': latitude,
      'currentLongitude': longitude,
      'startTime': FieldValue.serverTimestamp(),
      'lastUpdate': FieldValue.serverTimestamp(),
      'status': 'active',
      'sharedWith': sharedWithUserIds ?? [],
      'locationHistory': [
        {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': FieldValue.serverTimestamp(),
        }
      ],
    });

    _isSharing = true;
    return _currentTripId!;
  }

  // Update location from HomeScreen
  static Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (!_isSharing || _currentTripId == null) return;

    try {
      final tripRef = _firestore.collection('active_trips').doc(_currentTripId);
      
      await tripRef.update({
        'currentLatitude': latitude,
        'currentLongitude': longitude,
        'lastUpdate': FieldValue.serverTimestamp(),
        'locationHistory': FieldValue.arrayUnion([
          {
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': FieldValue.serverTimestamp(),
          }
        ]),
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // Stop sharing trip
  static Future<void> stopSharing() async {
    if (!_isSharing || _currentTripId == null) return;

    _locationTimer?.cancel();
    _locationTimer = null;

    try {
      final tripRef = _firestore.collection('active_trips').doc(_currentTripId);
      await tripRef.update({
        'status': 'ended',
        'endTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error stopping trip: $e');
    }

    _isSharing = false;
    _currentTripId = null;
  }

  // Get active trips for Full Map screen
  static Stream<List<Map<String, dynamic>>> getActiveTrips() {
    return _firestore
        .collection('active_trips')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'tripId': doc.id,
              'userId': data['userId'],
              'userName': data['userName'],
              'latitude': data['currentLatitude'],
              'longitude': data['currentLongitude'],
              'lastUpdate': data['lastUpdate'],
              'locationHistory': data['locationHistory'] ?? [],
            };
          }).toList();
        });
  }

  // Clean up expired trips
  static Future<void> cleanupExpiredTrips() async {
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final expiredTrips = await _firestore
        .collection('active_trips')
        .where('lastUpdate', isLessThan: Timestamp.fromDate(oneHourAgo))
        .where('status', isEqualTo: 'active')
        .get();

    final batch = _firestore.batch();
    for (var doc in expiredTrips.docs) {
      batch.update(doc.reference, {'status': 'expired'});
    }
    await batch.commit();
  }
}