import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home/home_screen.dart';

class SOSAlertService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // COMMUNITY SOS - Sends alert to ALL app users
  // ============================================================
  static Future<String?> sendCommunitySOSAlert({
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    String? audioPath,
    String? videoPath,
  }) async {
    final locationLink = 'https://www.google.com/maps?q=$latitude,$longitude';
    final timestamp = DateTime.now();
    
    debugPrint('🚨 Sending COMMUNITY SOS alert from $userName at $locationLink');
    
    try {
      final docRef = _firestore.collection('active_sos_events').doc();
      final sosEventId = docRef.id;
      
      await docRef.set({
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
      });
      
      debugPrint('✅ SOS event created: $sosEventId');
      
      await _firestore.collection('global_alerts').add({
        'type': 'sos',
        'message': '🚨 EMERGENCY: $userName needs immediate help at their location!',
        'userId': userId,
        'userName': userName,
        'locationLink': locationLink,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'sosEventId': sosEventId,
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
        
        batch.set(alertRef, {
          'message': '🚨 SOS: $userName needs immediate help! Tap to view location.',
          'type': 'sos',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'sosEventId': sosEventId,
          'latitude': latitude,
          'longitude': longitude,
          'userName': userName,
        });
        alertCount++;
      }
      
      await batch.commit();
      debugPrint('✅ SOS alert sent to $alertCount users');
      
      return sosEventId;
      
    } catch (e) {
      debugPrint('❌ Error sending community SOS alert: $e');
      rethrow;
    }
  }
  
  // ============================================================
  // DEACTIVATE SOS EVENT (when user marks themselves safe)
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
      
      debugPrint('✅ SOS event $sosEventId deactivated');
    } catch (e) {
      debugPrint('❌ Error deactivating SOS event: $e');
      rethrow;
    }
  }
  
  // ============================================================
  // Get active SOS events (for map display)
  // ============================================================
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
  
  // ============================================================
  // User responds to help (volunteers to assist)
  // ============================================================
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
              'message': '🆘 $responderName is on their way to help you!',
              'type': 'responder',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'responderId': responderId,
              'responderName': responderName,
            });
      }
      
      debugPrint('✅ $responderName responded to SOS event $sosEventId');
      
    } catch (e) {
      debugPrint('❌ Error responding to SOS: $e');
      rethrow;
    }
  }
}