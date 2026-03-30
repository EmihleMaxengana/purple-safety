import 'dart:async';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import 'emergency_mode_screen.dart';
import '../services/sos_event_service.dart';
import '../services/auth_service.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyManager {
  static final EmergencyManager _instance = EmergencyManager._internal();

  factory EmergencyManager() => _instance;
  EmergencyManager._internal();

  bool _emergencyActive = false;
  StreamController<bool> _emergencyStatusController =
      StreamController<bool>.broadcast();

  List<Contact> _currentContacts = [];

  Stream<bool> get emergencyStatusStream => _emergencyStatusController.stream;
  bool get isEmergencyActive => _emergencyActive;

  List<Contact> getCurrentContacts() => _currentContacts;

  void setCurrentContacts(List<Contact> contacts) {
    _currentContacts = contacts;
  }

  void activateEmergencyMode(BuildContext context, {List<Contact>? contacts}) {
    if (!_emergencyActive) {
      _emergencyActive = true;
      if (contacts != null) {
        _currentContacts = contacts;
      }
      _emergencyStatusController.add(true);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EmergencyModeScreen()),
      );

      _simulateEmergencyProcesses(context);
    }
  }

  // Light activation – only sets the flag, no navigation
  void activateEmergencyModeLight({List<Contact>? contacts}) async {
    if (!_emergencyActive) {
      _emergencyActive = true;
      if (contacts != null) {
        _currentContacts = contacts;
      }
      _emergencyStatusController.add(true);

      // --- Store SOS event in Firestore
      final user = AuthService().getCurrentUser();
      if (user != null) {
        try {
          final position = await Geolocator.getCurrentPosition();
          final userData = await AuthService().getUserData(user.uid);
          final userName = userData?['name'] ?? 'User';
          await SOSEventService.createSOSEvent(
            location: position,
            userId: user.uid,
            userName: userName,
          );
        } catch (e) {
          debugPrint('Failed to create SOS event: $e');
        }
      }
    }
  }

  void deactivateEmergencyMode() async {
    if (_emergencyActive) {
      _emergencyActive = false;
      _emergencyStatusController.add(false);
      await SOSEventService.endSOSEvent();
    }
  }

  void _simulateEmergencyProcesses(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      debugPrint('Emergency alerts sent');
    });
  }
}
