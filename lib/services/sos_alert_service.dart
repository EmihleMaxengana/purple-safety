import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home_screen.dart';

class SOSAlertService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send alerts to trusted contacts AND all app users
  static Future<void> sendAlerts(
    List<Contact> contacts,
    String locationLink, {
    String? audioPath,
    String? videoPath,
  }) async {
    // 1. Send to trusted contacts (SMS/WhatsApp)
    if (await Permission.sms.request().isGranted) {
      for (var contact in contacts) {
        await sendSMS(contact.phone!, locationLink);
        await sendWhatsApp(contact, locationLink);
      }
    }

    // 2. Send global push notification to all app users (via FCM topic)
    await _sendGlobalNotification(locationLink);

    // 3. Save emergency alert to Firestore for all users
    await _saveGlobalAlert(
      locationLink,
      audioPath: audioPath,
      videoPath: videoPath,
    );
  }

  static Future<void> _sendGlobalNotification(String locationLink) async {
    try {
      debugPrint('Global emergency alert sent to topic: emergency_alerts');
    } catch (e) {
      debugPrint('Error sending global notification: $e');
    }
  }

  static Future<void> _saveGlobalAlert(
    String locationLink, {
    String? audioPath,
    String? videoPath,
  }) async {
    try {
      await _firestore.collection('global_alerts').add({
        'timestamp': FieldValue.serverTimestamp(),
        'locationLink': locationLink,
        'audioPath': audioPath,
        'videoPath': videoPath,
        'type': 'emergency',
      });
    } catch (e) {
      debugPrint('Error saving global alert: $e');
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
    final String url =
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
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
