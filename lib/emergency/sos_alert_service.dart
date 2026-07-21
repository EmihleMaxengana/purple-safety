import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purple_safety/services/storage_service.dart';

class SOSAlertService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _pendingSOSKey = 'pending_sos';

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

    String? audioUrl;
    if (audioPath != null && audioPath.isNotEmpty) {
      audioUrl = await StorageService.uploadAudio(
        filePath: audioPath,
        userId: userId,
        isSOS: true,
      );
    }

    String? videoUrl;
    if (videoPath != null && videoPath.isNotEmpty) {
      videoUrl = await StorageService.uploadVideo(
        filePath: videoPath,
        userId: userId,
        isSOS: true,
      );
    }

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
        'audioUrl': audioUrl,
        'videoUrl': videoUrl,
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

      String message = 'EMERGENCY: $userName needs immediate help at their location!';
      if (triggerLocationLink != null) {
        message = 'EMERGENCY: $userName needs immediate help!\n'
            'Current: $locationLink\n'
            'Triggered: $triggerLocationLink\n'
            'Triggered at: $triggerTimestamp';
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
        'audioUrl': audioUrl,
        'videoUrl': videoUrl,
        'triggerLat': triggerLat != null ? double.tryParse(triggerLat) : null,
        'triggerLng': triggerLng != null ? double.tryParse(triggerLng) : null,
        'triggerTimestamp': triggerTimestamp,
        'wasOffline': triggerLat != null,
      });

      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == userId) continue;

        final alertRef = _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('alerts')
            .doc();

        String alertMessage = 'SOS: $userName needs immediate help! Tap to view location.';
        if (triggerLocationLink != null) {
          alertMessage = 'SOS: $userName needs immediate help!\n'
              'Current: $locationLink\n'
              'Triggered: $triggerLocationLink';
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
          'audioUrl': audioUrl,
          'videoUrl': videoUrl,
          'triggerLat': triggerLat != null ? double.tryParse(triggerLat) : null,
          'triggerLng': triggerLng != null ? double.tryParse(triggerLng) : null,
          'wasOffline': triggerLat != null,
        });
      }

      await batch.commit();
      return sosEventId;

    } catch (e) {
      rethrow;
    }
  }

  static Future<void> deactivateSOSEvent(String sosEventId, {String? userId}) async {
    try {
      await _firestore.collection('active_sos_events').doc(sosEventId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      final eventDoc = await _firestore.collection('active_sos_events').doc(sosEventId).get();
      if (!eventDoc.exists) return;
      final eventData = eventDoc.data()!;
      final userName = eventData['userName'] ?? 'Someone';
      final locationLink = eventData['locationLink'] ?? 'Location unavailable';
      final latitude = eventData['latitude'];
      final longitude = eventData['longitude'];

      await _firestore.collection('global_alerts').add({
        'type': 'sos_resolved',
        'message': '$userName is now SAFE. The SOS alert has been resolved.',
        'sosEventId': sosEventId,
        'userName': userName,
        'locationLink': locationLink,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': eventData['userId'],
      });

      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      for (var userDoc in usersSnapshot.docs) {
        if (userId != null && userDoc.id == userId) continue;

        final alertRef = _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('alerts')
            .doc();

        batch.set(alertRef, {
          'message': 'SAFE: $userName is now safe. The SOS alert has been resolved.',
          'type': 'sos_resolved',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'sosEventId': sosEventId,
          'latitude': latitude,
          'longitude': longitude,
          'userName': userName,
          'locationLink': locationLink,
        });
      }

      await batch.commit();

      debugPrint('SOS event $sosEventId deactivated and notifications sent (excluding deactivator).');

    } catch (e) {
      debugPrint('Error deactivating SOS event: $e');
      rethrow;
    }
  }

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
              'message': '$responderName is on their way to help you!',
              'type': 'responder',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'responderId': responderId,
              'responderName': responderName,
            });
      }

    } catch (e) {
      rethrow;
    }
  }

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
      } else {
        throw Exception('Could not launch SMS app');
      }
    } catch (e) {
      rethrow;
    }
  }

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
      }
    } catch (e) {
      return;
    }
  }

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
          continue;
        }
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearPendingSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingSOSKey);
    } catch (e) {
      return;
    }
  }

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