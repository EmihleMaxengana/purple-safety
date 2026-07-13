import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SOSAlertService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _pendingSOSKey = 'pending_sos';


  // COMMUNITY SOS - Sends alert to ALL app users( not a push in notification tho)
 
  static Future<String?> sendCommunitySOSAlert({
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    String? audioPath,
    String? videoPath,
    String? triggerLat,
    String? triggerLng,
    String? triggerTimestamp,
  }) async {
    final locationLink = 'https://www.google.com/maps?q=$latitude,$longitude';
    final triggerLocationLink = (triggerLat != null && triggerLng != null)
        ? 'https://www.google.com/maps?q=$triggerLat,$triggerLng'
        : null;

    debugPrint(' Sending COMMUNITY SOS alert from $userName at $locationLink');

    try {
      final docRef = _firestore.collection('active_sos_events').doc();
      final sosEventId = docRef.id;

      final Map<String, dynamic> eventData = {
        'id': sosEventId,
        'userId': userId,
        'userName': userName,
        'latitude': latitude,
        'longitude': longitude,
        'locationLink': locationLink,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'audioPath': audioPath,
        'videoPath': videoPath,
        'responderCount': 0,
      };

      if (triggerLat != null && triggerLng != null) {
        eventData['triggerLat'] = double.tryParse(triggerLat);
        eventData['triggerLng'] = double.tryParse(triggerLng);
      }
      if (triggerTimestamp != null) {
        eventData['triggerTimestamp'] = triggerTimestamp;
      }

      await docRef.set(eventData);
      debugPrint(' SOS event created: $sosEventId');

      String message = ' EMERGENCY: $userName needs immediate help at their location!';
      if (triggerLocationLink != null) {
        message = ' EMERGENCY: $userName needs immediate help!\n'
            '📍 Current: $locationLink\n'
            '📍 Triggered: $triggerLocationLink\n'
            '🕐 Triggered at: $triggerTimestamp';
      }

      await _firestore.collection('global_alerts').add({
        'type': 'sos',
        'message': message,
        'userId': userId,
        'userName': userName,
        'locationLink': locationLink,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'sosEventId': sosEventId,
        'triggerLat': triggerLat != null ? double.tryParse(triggerLat) : null,
        'triggerLng': triggerLng != null ? double.tryParse(triggerLng) : null,
        'triggerTimestamp': triggerTimestamp,
        'wasOffline': triggerLat != null,
      });

      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();
      int alertCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == userId) continue;

        final alertRef = _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('alerts')
            .doc();

        String alertMessage = ' SOS: $userName needs immediate help! Tap to view location.';
        if (triggerLocationLink != null) {
          alertMessage = ' SOS: $userName needs immediate help!\n'
              '📍 Current: $locationLink\n'
              '📍 Triggered: $triggerLocationLink';
        }

        batch.set(alertRef, {
          'message': alertMessage,
          'type': 'sos',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'sosEventId': sosEventId,
          'latitude': latitude,
          'longitude': longitude,
          'userName': userName,
          'triggerLat': triggerLat != null ? double.tryParse(triggerLat) : null,
          'triggerLng': triggerLng != null ? double.tryParse(triggerLng) : null,
          'wasOffline': triggerLat != null,
        });
        alertCount++;
      }

      await batch.commit();
      debugPrint(' SOS alert sent to $alertCount users');

      return sosEventId;

    } catch (e) {
      debugPrint(' Error sending community SOS alert: $e');
      rethrow;
    }
  }

  // ============================================================
  // DEACTIVATE SOS EVENT
  // ============================================================
  static Future<void> deactivateSOSEvent(String sosEventId, {String? userId}) async {
    try {
      await _firestore.collection('active_sos_events').doc(sosEventId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      final eventDoc = await _firestore.collection('active_sos_events').doc(sosEventId).get();
      final eventData = eventDoc.data();
      final userName = eventData?['userName'] ?? 'Someone';

      await _firestore.collection('global_alerts').add({
        'type': 'sos_resolved',
        'message': '✅ $userName is now SAFE. The SOS alert has been resolved.',
        'sosEventId': sosEventId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint(' SOS event $sosEventId deactivated');
    } catch (e) {
      debugPrint(' Error deactivating SOS event: $e');
      rethrow;
    }
  }

 
  // Get active SOS events

  static Stream<List<Map<String, dynamic>>> getActiveSOSEvents() {
    return _firestore
        .collection('active_sos_events')
        .where('status', isEqualTo: 'active')
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


  // User responds to help
 
  static Future<void> respondToSOS({
    required String sosEventId,
    required String responderId,
    required String responderName,
    required double responderLatitude,
    required double responderLongitude,
  }) async {
    try {
      await _firestore
          .collection('active_sos_events')
          .doc(sosEventId)
          .collection('responders')
          .add({
            'userId': responderId,
            'userName': responderName,
            'latitude': responderLatitude,
            'longitude': responderLongitude,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'en_route',
          });

      await _firestore.collection('active_sos_events').doc(sosEventId).update({
        'responderCount': FieldValue.increment(1),
      });

      final sosEvent = await _firestore.collection('active_sos_events').doc(sosEventId).get();
      if (sosEvent.exists) {
        final eventData = sosEvent.data();
        await _firestore
            .collection('users')
            .doc(eventData?['userId'])
            .collection('alerts')
            .add({
              'message': ' $responderName is on their way to help you!',
              'type': 'responder',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'responderId': responderId,
              'responderName': responderName,
            });
      }

      debugPrint(' $responderName responded to SOS event $sosEventId');

    } catch (e) {
      debugPrint(' Error responding to SOS: $e');
      rethrow;
    }
  }

 
  // SMS FALLBACK( problem with this is that it the user cant personally  trigger the sos bcoz the app is not 0rating)

  static Future<void> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final cleanedNumber = phoneNumber.replaceAll(' ', '').replaceAll('+', '');
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: cleanedNumber,
        query: 'body=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        debugPrint('📱 SMS compose opened for $phoneNumber');
      } else {
        throw Exception('Could not launch SMS app');
      }
    } catch (e) {
      debugPrint('❌ SMS send error: $e');
      rethrow;
    }
  }

  // OFFLINE SOS QUEUE
 
  static Future<void> storeSOSLocally({
    required String userId,
    required String userName,
    required double triggerLat,
    required double triggerLng,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pending = prefs.getStringList(_pendingSOSKey) ?? [];

      final timestamp = DateTime.now().toIso8601String();
      final Map<String, String> sosData = {
        'userId': userId,
        'userName': userName,
        'triggerLat': triggerLat.toString(),
        'triggerLng': triggerLng.toString(),
        'triggerTimestamp': timestamp,
      };

      final jsonString = sosData.toString();
      final encoded = Uri.encodeComponent(jsonString);

      if (!pending.contains(encoded)) {
        pending.add(encoded);
        await prefs.setStringList(_pendingSOSKey, pending);
        debugPrint(' SOS stored locally: $timestamp');
      }
    } catch (e) {
      debugPrint(' Error storing SOS locally: $e');
    }
  }

  // Get pending SOS list(will be sent once back online via wifi or mobile data)

  static Future<List<Map<String, String>>> getPendingSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pending = prefs.getStringList(_pendingSOSKey) ?? [];
      final List<Map<String, String>> result = [];

      for (var encoded in pending) {
        try {
          final decoded = Uri.decodeComponent(encoded);
          final cleaned = decoded.replaceAll('{', '').replaceAll('}', '');
          final parts = cleaned.split(',');

          final Map<String, String> data = {};
          for (var part in parts) {
            final keyValue = part.split(':');
            if (keyValue.length == 2) {
              final key = keyValue[0].trim().replaceAll("'", '');
              final value = keyValue[1].trim().replaceAll("'", '');
              data[key] = value;
            }
          }

          if (data.containsKey('userId') && data.containsKey('triggerTimestamp')) {
            result.add(data);
          }
        } catch (e) {
          debugPrint('Error decoding pending SOS: $e');
        }
      }

      return result;
    } catch (e) {
      debugPrint(' Error getting pending SOS: $e');
      return [];
    }
  }

  // ============================================================
  // Clear pending SOS
  // ============================================================
  static Future<void> clearPendingSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingSOSKey);
      debugPrint('✅ Pending SOS cleared');
    } catch (e) {
      debugPrint('Error clearing pending SOS: $e');
    }
  }

  // ============================================================
  // Check if pending SOS exists
  // ============================================================
  static Future<bool> hasPendingSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pending = prefs.getStringList(_pendingSOSKey) ?? [];
      return pending.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}