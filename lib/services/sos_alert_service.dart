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
      // 1. Create active SOS event in Firestore
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
      
      // 2. Save to global_alerts collection for all users to see
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
      
      // 3. Add alert to EVERY user's personal alerts collection
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();
      int alertCount = 0;
      
      for (var userDoc in usersSnapshot.docs) {
        // Don't send alert to the person who triggered SOS
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
      // Update the SOS event status to 'resolved'
      await _firestore.collection('active_sos_events').doc(sosEventId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      
      // Get the event details to know who to notify
      final eventDoc = await _firestore.collection('active_sos_events').doc(sosEventId).get();
      final eventData = eventDoc.data();
      final userName = eventData?['userName'] ?? 'Someone';
      
      // Add to global alerts that this SOS has been resolved
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
      // Add responder to the SOS event's responders subcollection
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
      
      // Increment responder count on the main event
      await _firestore.collection('active_sos_events').doc(sosEventId).update({
        'responderCount': FieldValue.increment(1),
      });
      
      // Get the SOS event owner to notify them
      final sosEvent = await _firestore.collection('active_sos_events').doc(sosEventId).get();
      if (sosEvent.exists) {
        final eventData = sosEvent.data();
        // Add alert to the SOS originator that someone is coming
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
  
  // ============================================================
  // LEGACY METHODS - For backward compatibility
  // ============================================================
  static Future<void> sendPrivateAlerts(
    List<Contact> contacts,
    String locationLink, {
    String? audioPath,
    String? videoPath,
  }) async {
    debugPrint('📱 Sending private alerts to ${contacts.length} trusted contacts');
    
    if (await Permission.sms.request().isGranted) {
      for (var contact in contacts) {
        if (contact.phone != null && contact.phone!.isNotEmpty) {
          await sendSMS(contact.phone!, locationLink);
        }
        await sendWhatsApp(contact, locationLink);
      }
    }
  }
  
  static Future<void> sendSMS(String phoneNumber, String message) async {
    final String fullMessage = message;
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('sms_sender');
        await platform.invokeMethod('sendSms', {
          'phoneNumber': phoneNumber,
          'message': fullMessage,
        });
        debugPrint('📱 SMS sent to $phoneNumber');
      } catch (e) {
        debugPrint('Failed to send SMS via method channel: $e');
        final url = 'sms:$phoneNumber?body=${Uri.encodeComponent(fullMessage)}';
        await _launchUrl(url);
      }
    } else {
      final url = 'sms:$phoneNumber?body=${Uri.encodeComponent(fullMessage)}';
      await _launchUrl(url);
    }
  }
  
  static Future<void> sendWhatsApp(Contact contact, String message) async {
    final String? whatsapp = contact.socialLinks['whatsapp'];
    if (whatsapp == null || whatsapp.isEmpty) return;
    
    String phone = whatsapp.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return;
    
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    
    if (!phone.startsWith('27') && phone.length <= 9) {
      phone = '27$phone';
    }
    
    final String url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    debugPrint('💬 WhatsApp URL: $url');
    await _launchUrl(url);
  }
  
  static Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }
}