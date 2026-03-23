import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import '../home/home_screen.dart';

class LocationSharingService {
  static Timer? _shareTimer;
  static bool _isSharing = false;

  static bool get isSharing => _isSharing;

  static void startSharing(
    List<Contact> contacts,
    String userName,
    Function() getCoordinates,
  ) {
    if (_isSharing) return;
    _isSharing = true;

    _sendLocationToAll(contacts, userName, getCoordinates());

    _shareTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _sendLocationToAll(contacts, userName, getCoordinates());
    });
  }

  static void stopSharing() {
    _shareTimer?.cancel();
    _shareTimer = null;
    _isSharing = false;
  }

  static Future<void> _sendLocationToAll(
    List<Contact> contacts,
    String userName,
    (double?, double?) coords,
  ) async {
    final (lat, lng) = coords;
    String message = await _buildLocationMessage(userName, lat, lng);
    for (var contact in contacts) {
      await _sendSMS(contact.phone!, message);
      await _sendWhatsApp(contact, message);
    }
  }

  static Future<String> _buildLocationMessage(
    String userName,
    double? lat,
    double? lng,
  ) async {
    String locationName = 'Unknown location';
    if (lat != null && lng != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          Placemark p = placemarks.first;
          List<String> parts = [];
          if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
          if (p.subLocality != null && p.subLocality!.isNotEmpty)
            parts.add(p.subLocality!);
          if (p.locality != null && p.locality!.isNotEmpty)
            parts.add(p.locality!);
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
            parts.add(p.administrativeArea!);
          if (p.country != null && p.country!.isNotEmpty) parts.add(p.country!);
          if (parts.isNotEmpty) locationName = parts.join(', ');
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
      }
    }
    final now = DateFormat('HH:mm').format(DateTime.now());
    final link = lat != null && lng != null
        ? 'https://www.google.com/maps?q=$lat,$lng'
        : 'Location unavailable';
    return '$userName is in $locationName at $now\nCoordinates: $link';
  }

  static Future<void> _sendSMS(String phoneNumber, String message) async {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('sms_sender');
        await platform.invokeMethod('sendSms', {
          'phoneNumber': phoneNumber,
          'message': message,
        });
        debugPrint('SMS sent to $phoneNumber');
      } catch (e) {
        debugPrint('Failed to send SMS via method channel: $e');
        // fallback to URL launcher
        final url = 'sms:$phoneNumber?body=${Uri.encodeComponent(message)}';
        await _launchUrl(url);
      }
    } else {
      // iOS: open SMS app
      final url = 'sms:$phoneNumber?body=${Uri.encodeComponent(message)}';
      await _launchUrl(url);
    }
  }

  static Future<void> _sendWhatsApp(Contact contact, String message) async {
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
