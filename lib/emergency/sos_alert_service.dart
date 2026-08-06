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
    double? latitude,
    double? longitude,
    String? audioPath,
    String? videoPath,
    String? triggerLat,
    String? triggerLng,
    String? triggerTimestamp,
    bool shareWithContacts = true,
    bool shareWithCommunity = false,
  }) async {
    String? locationLink;
    if (latitude != null && longitude != null) {
      locationLink = 'https://www.google.com/maps?q=$latitude,$longitude';
    }

    String? triggerLocationLink;
    if (triggerLat != null && triggerLng != null) {
      triggerLocationLink =
          'https://www.google.com/maps?q=$triggerLat,$triggerLng';
    }

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
      final existingActiveEventId = await getActiveSOSEventIdForUser(userId);
      if (existingActiveEventId != null) {
        debugPrint('Active SOS already exists for $userId, skipping duplicate creation');
        return existingActiveEventId;
      }

      final docRef = _firestore.collection('active_sos_events').doc();
      final sosEventId = docRef.id;

      final Map<String, dynamic> eventData = {
        'id': sosEventId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'audioUrl': audioUrl,
        'videoUrl': videoUrl,
        'responderCount': 0,
      };

      if (latitude != null && longitude != null) {
        eventData['latitude'] = latitude;
        eventData['longitude'] = longitude;
        eventData['locationLink'] = locationLink;
      }

      if (triggerLat != null && triggerLng != null) {
        eventData['triggerLat'] = double.tryParse(triggerLat);
        eventData['triggerLng'] = double.tryParse(triggerLng);
      }
      if (triggerTimestamp != null) {
        eventData['triggerTimestamp'] = triggerTimestamp;
      }

      await docRef.set(eventData);

      String message;
      if (shareWithContacts && locationLink != null) {
        message =
            'EMERGENCY: $userName needs immediate help at their location!';
        if (triggerLocationLink != null) {
          message =
              'EMERGENCY: $userName needs immediate help!\n'
              'Current: $locationLink\n'
              'Triggered: $triggerLocationLink\n'
              'Triggered at: $triggerTimestamp';
        }
      } else {
        message = 'EMERGENCY: $userName needs immediate help!';
        if (triggerLocationLink != null && shareWithContacts) {
          message =
              'EMERGENCY: $userName needs immediate help!\n'
              'Triggered at: $triggerTimestamp';
        }
      }

      final Map<String, dynamic> globalAlertData = {
        'type': 'sos',
        'message': message,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'sosEventId': sosEventId,
        'audioUrl': audioUrl,
        'videoUrl': videoUrl,
        'wasOffline': triggerLat != null,
        'shareWithContacts': shareWithContacts,
        'shareWithCommunity': shareWithCommunity,
      };

      if (shareWithCommunity && latitude != null && longitude != null) {
        globalAlertData['locationLink'] = locationLink;
        globalAlertData['latitude'] = latitude;
        globalAlertData['longitude'] = longitude;
      }

      if (triggerLat != null && triggerLng != null) {
        globalAlertData['triggerLat'] = double.tryParse(triggerLat);
        globalAlertData['triggerLng'] = double.tryParse(triggerLng);
        globalAlertData['triggerTimestamp'] = triggerTimestamp;
      }

      await _firestore.collection('global_alerts').add(globalAlertData);

      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == userId) continue;

        final alertRef = _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('alerts')
            .doc();

        String alertMessage;
        if (shareWithContacts && locationLink != null) {
          alertMessage =
              'SOS: $userName needs immediate help! Tap to view location.';
          if (triggerLocationLink != null) {
            alertMessage =
                'SOS: $userName needs immediate help!\n'
                'Current: $locationLink\n'
                'Triggered: $triggerLocationLink';
          }
        } else {
          alertMessage = 'SOS: $userName needs immediate help!';
        }

        final Map<String, dynamic> alertData = {
          'message': alertMessage,
          'type': 'sos',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'sosEventId': sosEventId,
          'userName': userName,
          'audioUrl': audioUrl,
          'videoUrl': videoUrl,
          'wasOffline': triggerLat != null,
        };

        if (shareWithContacts && latitude != null && longitude != null) {
          alertData['latitude'] = latitude;
          alertData['longitude'] = longitude;
        }

        if (triggerLat != null && triggerLng != null) {
          alertData['triggerLat'] = double.tryParse(triggerLat);
          alertData['triggerLng'] = double.tryParse(triggerLng);
        }

        batch.set(alertRef, alertData);
      }

      await batch.commit();
      return sosEventId;
    } catch (e) {
      rethrow;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static Future<String?> getActiveSOSEventIdForUser(String userId) async {
    final snapshot = await _firestore
        .collection('active_sos_events')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  static Future<void> deactivateSOSEvent(String sosEventId, {String? userId, double? finalLat, double? finalLng}) async {
    try {
      final eventDocSnapshot = await _firestore.collection('active_sos_events').doc(sosEventId).get();
      if (!eventDocSnapshot.exists) return;

      final eventData = eventDocSnapshot.data()!;
      final triggerLat = eventData['triggerLat'];
      final triggerLng = eventData['triggerLng'];
      final triggerTimestamp = eventData['triggerTimestamp'];
      final userName = eventData['userName'] ?? 'Someone';
      final userIdFromEvent = eventData['userId'];

      final double? currentLat = _toDouble(eventData['latitude']);
      final double? currentLng = _toDouble(eventData['longitude']);
      final double? resolvedLat = finalLat ?? currentLat;
      final double? resolvedLng = finalLng ?? currentLng;
      final reason = (finalLat != null || finalLng != null) ? 'user_safe' : 'system_ended';

      await _firestore.collection('active_sos_events').doc(sosEventId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'finalLatitude': resolvedLat,
        'finalLongitude': resolvedLng,
        'deactivationReason': reason,
      });

      final locationLink = (resolvedLat != null && resolvedLng != null)
          ? 'https://www.google.com/maps?q=$resolvedLat,$resolvedLng'
          : eventData['locationLink'] ?? 'Location unavailable';

      await _firestore.collection('global_alerts').add({
        'type': 'sos_resolved',
        'message': '$userName is now SAFE. The SOS alert has been resolved.',
        'sosEventId': sosEventId,
        'userName': userName,
        'locationLink': locationLink,
        'latitude': resolvedLat,
        'longitude': resolvedLng,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': eventData['userId'],
        'triggerLat': triggerLat,
        'triggerLng': triggerLng,
        'triggerTimestamp': triggerTimestamp,
        'resolvedAt': FieldValue.serverTimestamp(),
        'deactivationReason': reason,
      });

      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id == userIdFromEvent) {
          continue;
        }

        final alertRef = _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('alerts')
            .doc();

        batch.set(alertRef, {
          'message': 'SAFE: $userName is now safe. The SOS alert has been resolved.',
          'type': 'sos_deactivated',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'sosEventId': sosEventId,
          'latitude': resolvedLat,
          'longitude': resolvedLng,
          'userName': userName,
          'locationLink': locationLink,
          'triggerLat': triggerLat,
          'triggerLng': triggerLng,
          'triggerTimestamp': triggerTimestamp,
          'resolvedAt': FieldValue.serverTimestamp(),
          'deactivationReason': reason,
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
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList(),
        );
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

      final sosEvent = await _firestore
          .collection('active_sos_events')
          .doc(sosEventId)
          .get();
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
    double? triggerLat,
    double? triggerLng,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pending = prefs.getStringList(_pendingSOSKey) ?? [];

      final timestamp = DateTime.now().toIso8601String();
      final Map<String, String> sosData = {
        'userId': userId,
        'userName': userName,
        'triggerTimestamp': timestamp,
      };

      if (triggerLat != null && triggerLng != null) {
        sosData['triggerLat'] = triggerLat.toString();
        sosData['triggerLng'] = triggerLng.toString();
      }

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

          if (data.containsKey('userId') &&
              data.containsKey('triggerTimestamp')) {
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

  static Future<bool> hasActiveSOSEventForUser(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('active_sos_events')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
