import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../home/home_screen.dart';

class SOSAlertService {
  static Future<void> sendAlerts(
    List<Contact> contacts,
    String locationLink,
  ) async {
    if (await Permission.sms.request().isGranted) {
      for (var contact in contacts) {
        await sendSMS(contact.phone!, locationLink);
        await sendWhatsApp(contact, locationLink);
      }
    } else {
      debugPrint('SMS permission denied');
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
