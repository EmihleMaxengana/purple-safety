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

  // Start sharing your live location
  static Future<String> startSharing({
    required String userName,
    required double latitude,
    required double longitude,
  }) async {
    // Stop any existing sharing
    if (_isSharing) {
      await stopSharing();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Create a new trip document in Firestore
    final tripRef = _firestore.collection('active_trips').doc();
    _currentTripId = tripRef.id;
    final now = DateTime.now();
    final timestamp = Timestamp.fromDate(now);

    await tripRef.set({
      'tripId': _currentTripId,
      'userId': user.uid,
      'userName': userName,
      'currentLatitude': latitude,
      'currentLongitude': longitude,
      'startTime': timestamp,
      'lastUpdate': timestamp,
      'status': 'active', // active, ended, expired
      'locationHistory': [
        {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': timestamp,
        }
      ],
    });

    _isSharing = true;
    
    return _currentTripId!;
  }

  // Update your current location
  static Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (!_isSharing || _currentTripId == null) return;

    try {
      final tripRef = _firestore.collection('active_trips').doc(_currentTripId);
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);
      
      await tripRef.update({
        'currentLatitude': latitude,
        'currentLongitude': longitude,
        'lastUpdate': timestamp,
        'locationHistory': FieldValue.arrayUnion([
          {
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': timestamp,
          }
        ]),
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // Stop sharing your location
  static Future<void> stopSharing() async {
    if (!_isSharing || _currentTripId == null) return;

    _locationTimer?.cancel();
    _locationTimer = null;

    try {
      final tripRef = _firestore.collection('active_trips').doc(_currentTripId);
      await tripRef.update({
        'status': 'ended',
        'endTime': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error stopping trip: $e');
    }

    _isSharing = false;
    _currentTripId = null;
  }

  // Get a specific trip to follow (for viewers)
  static Stream<DocumentSnapshot> getTrip(String tripId) {
    return _firestore.collection('active_trips').doc(tripId).snapshots();
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