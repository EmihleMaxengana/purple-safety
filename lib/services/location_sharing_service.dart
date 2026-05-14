import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home_screen.dart';

class LocationSharingService {
  static Timer? _shareTimer;
  static bool _isSharing = false;
  static bool _shareWithCommunity = false;

  static bool get isSharing => _isSharing;

  static void startSharing(
    List<Contact> contacts,
    String userName,
    Function() getCoordinates, {
    bool shareWithCommunity = false,
  }) {
    if (_isSharing) return;
    
    _isSharing = true;
    _shareWithCommunity = shareWithCommunity;
    
    _sendLocationToAll(contacts, userName, getCoordinates());
    
    _shareTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _sendLocationToAll(contacts, userName, getCoordinates());
    });
  }

  static void stopSharing() {
    _shareTimer?.cancel();
    _shareTimer = null;
    _isSharing = false;
    _shareWithCommunity = false;
  }

  static Future<void> _sendLocationToAll(
    List<Contact> contacts,
    String userName,
    (double?, double?) coords,
  ) async {
    final (lat, lng) = coords;
    
    if (lat == null || lng == null) {
      debugPrint('Location not available, skipping share');
      return;
    }
    
    String message = await _buildLocationMessage(userName, lat, lng);
    String locationLink = 'https://www.google.com/maps?q=$lat,$lng';
    
    // Send to trusted contacts (SMS + WhatsApp)
    if (contacts.isNotEmpty) {
      for (var contact in contacts) {
        // Send SMS
        if (contact.phone != null && contact.phone!.isNotEmpty) {
          await _sendSMS(contact.phone!, message);
        }
        // Send WhatsApp (KEPT HERE)
        await _sendWhatsApp(contact, message);
      }
      debugPrint('📍 Location shared with ${contacts.length} trusted contacts (SMS + WhatsApp)');
    }
    
    // Send to community (in-app only, no SMS/WhatsApp)
    if (_shareWithCommunity) {
      await _sendToCommunity(userName, locationLink, lat, lng);
      debugPrint('📍 Location shared with community (in-app)');
    }
  }
  
  static Future<void> _sendToCommunity(
    String userName,
    String locationLink,
    double lat,
    double lng,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('global_alerts').add({
        'type': 'location_share',
        'message': '📍 $userName is sharing their live location with the community',
        'userName': userName,
        'locationLink': locationLink,
        'latitude': lat,
        'longitude': lng,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final batch = FirebaseFirestore.instance.batch();
      
      for (var userDoc in usersSnapshot.docs) {
        final alertRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('alerts')
            .doc();
        
        batch.set(alertRef, {
          'message': '📍 $userName is sharing their live location. Tap to view.',
          'type': 'location_share',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'locationLink': locationLink,
          'latitude': lat,
          'longitude': lng,
          'userName': userName,
        });
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error sending location to community: $e');
    }
  }

  static Future<String> _buildLocationMessage(
    String userName,
    double lat,
    double lng,
  ) async {
    String locationName = 'Unknown location';
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
    
    final now = DateFormat('HH:mm').format(DateTime.now());
    final link = 'https://www.google.com/maps?q=$lat,$lng';
    return '$userName is in $locationName at $now\nLocation: $link';
  }

  static Future<void> _sendSMS(String phoneNumber, String message) async {
    try {
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
      
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: cleanNumber,
        query: 'body=${Uri.encodeComponent(message)}',
      );
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        debugPrint('SMS opened for $phoneNumber');
      } else {
        debugPrint('Could not open SMS for $phoneNumber');
      }
    } catch (e) {
      debugPrint('Error sending SMS: $e');
    }
  }

  // ============================================================
  // WHATSAPP - KEPT ONLY FOR LOCATION SHARING TO TRUSTED CONTACTS
  // ============================================================
  static Future<void> _sendWhatsApp(Contact contact, String message) async {
    final String? whatsapp = contact.socialLinks['whatsapp'];
    if (whatsapp == null || whatsapp.isEmpty) {
      debugPrint('No WhatsApp number for ${contact.name}');
      return;
    }
    
    try {
      // Extract only digits
      String phone = whatsapp.replaceAll(RegExp(r'\D'), '');
      if (phone.isEmpty) {
        debugPrint('Invalid WhatsApp number for ${contact.name}');
        return;
      }
      
      // Remove leading zero if present (ZA numbers start with 0 for local)
      if (phone.startsWith('0')) {
        phone = phone.substring(1);
      }
      
      // Add South Africa country code (27) if not already there
      if (!phone.startsWith('27') && phone.length <= 9) {
        phone = '27$phone';
      }
      
      // Create WhatsApp URL
      final String url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
      debugPrint('WhatsApp URL for ${contact.name}: $url');
      
      final Uri uri = Uri.parse(url);
      
      // Try to launch - this will open WhatsApp with the message pre-filled
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('WhatsApp opened for ${contact.name}');
      } else {
        debugPrint('Could not open WhatsApp for ${contact.name}');
        // Try alternative format
        final altUrl = 'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}';
        final altUri = Uri.parse(altUrl);
        if (await canLaunchUrl(altUri)) {
          await launchUrl(altUri, mode: LaunchMode.externalApplication);
          debugPrint('WhatsApp opened via alternative URL for ${contact.name}');
        } else {
          debugPrint('WhatsApp may not be installed for ${contact.name}');
        }
      }
    } catch (e) {
      debugPrint('Error sending WhatsApp to ${contact.name}: $e');
    }
  }
}