import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart' as location;
import 'package:shared_preferences/shared_preferences.dart';

class TripSharingService {
  static const String _tripIdPrefsKey = 'active_trip_id';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _locationTimer;
  static String? _currentTripId;
  static bool _isSharing = false;
  static final location.Location _location = location.Location();
  static bool _backgroundModeEnabled = false;

  static bool get isSharing => _isSharing;
  static String? get currentTripId => _currentTripId;

  // ============================================================
  // ENABLE BACKGROUND LOCATION MODE
  // ============================================================
  static Future<void> enableBackgroundLocation() async {
    if (_backgroundModeEnabled) return;

    try {
      // Check permissions
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      final permission = await _location.hasPermission();
      if (permission == location.PermissionStatus.denied) {
        final requested = await _location.requestPermission();
        if (requested != location.PermissionStatus.granted) return;
      }

      // Enable background mode
      await _location.enableBackgroundMode(enable: true);
      _backgroundModeEnabled = true;
      print('✅ Background location mode enabled');
    } catch (e) {
      print('❌ Error enabling background location: $e');
    }
  }

  // START SHARING

  static Future<String> startSharing({
    required String userName,
    required double latitude,
    required double longitude,
  }) async {
    if (_isSharing) {
      await stopSharing();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await enableBackgroundLocation();

    final tripRef = _firestore.collection('active_trips').doc();
    _currentTripId = tripRef.id;
    final now = DateTime.now();
    final timestampString = now.toIso8601String();

    await tripRef.set({
      'tripId': _currentTripId,
      'userId': user.uid,
      'userName': userName,
      'currentLatitude': latitude,
      'currentLongitude': longitude,
      'startTime': Timestamp.fromDate(now),
      'lastUpdate': Timestamp.fromDate(now),
      'status': 'active',
      'locationHistory': [
        {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': timestampString,
        },
      ],
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tripIdPrefsKey, _currentTripId!);

    _isSharing = true;
    return _currentTripId!;
  }

  // UPDATE LOCATION
  static Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (!_isSharing || _currentTripId == null) return;

    try {
      final tripRef = _firestore.collection('active_trips').doc(_currentTripId);
      final now = DateTime.now();
      final timestampString = now.toIso8601String();

      await tripRef.update({
        'currentLatitude': latitude,
        'currentLongitude': longitude,
        'lastUpdate': Timestamp.fromDate(now),
        'locationHistory': FieldValue.arrayUnion([
          {
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': timestampString,
          },
        ]),
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // STOP SHARING
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tripIdPrefsKey);

    _isSharing = false;
    _currentTripId = null;
  }

  static Future<String?> getPersistedTripId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tripIdPrefsKey);
  }

  static Future<void> restoreTripSession() async {
    final persistedTripId = await getPersistedTripId();
    if (persistedTripId == null || persistedTripId.isEmpty) {
      return;
    }

    try {
      final doc = await _firestore
          .collection('active_trips')
          .doc(persistedTripId)
          .get();

      if (!doc.exists) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tripIdPrefsKey);
        return;
      }

      final data = doc.data();
      if (data == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tripIdPrefsKey);
        return;
      }

      if (data['status'] == 'active') {
        _currentTripId = persistedTripId;
        _isSharing = true;
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tripIdPrefsKey);
        _currentTripId = null;
        _isSharing = false;
      }
    } catch (e) {
      debugPrint('[Trip sharing service] Error restoring trip session: $e');
    }
  }

  // GET TRIP

  static Stream<DocumentSnapshot> getTrip(String tripId) {
    return _firestore.collection('active_trips').doc(tripId).snapshots();
  }

  // CLEANUP EXPIRED TRIPS

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

  // CHECK IF A TRIP IS STILL ACTIVE (for app resume)
  static Future<bool> isTripActive() async {
    if (!_isSharing || _currentTripId == null) return false;

    try {
      final doc = await _firestore
          .collection('active_trips')
          .doc(_currentTripId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['status'] == 'active';
      }
      return false;
    } catch (e) {
      print('Error checking trip status: $e');
      return false;
    }
  }
}
