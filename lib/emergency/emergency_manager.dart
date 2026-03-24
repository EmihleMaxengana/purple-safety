import 'dart:async';
import 'package:flutter/material.dart';
import '../home/home_screen.dart'; // for Contact model
import 'emergency_mode_screen.dart';

class EmergencyManager {
  static final EmergencyManager _instance = EmergencyManager._internal();

  factory EmergencyManager() => _instance;
  EmergencyManager._internal();

  bool _emergencyActive = false;
  StreamController<bool> _emergencyStatusController =
      StreamController<bool>.broadcast();

  // Store the current trusted contacts for SOS
  List<Contact> _currentContacts = [];

  Stream<bool> get emergencyStatusStream => _emergencyStatusController.stream;
  bool get isEmergencyActive => _emergencyActive;

  // Get the stored contacts
  List<Contact> getCurrentContacts() => _currentContacts;

  // Set contacts (call this when SOS is activated or contacts change)
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

  void deactivateEmergencyMode() {
    if (_emergencyActive) {
      _emergencyActive = false;
      _emergencyStatusController.add(false);
      // Clear contacts or keep them – your choice
      // _currentContacts.clear();
    }
  }

  void _simulateEmergencyProcesses(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      debugPrint('Emergency alerts sent');
    });
  }
}
