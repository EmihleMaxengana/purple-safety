import 'dart:async';
import 'package:flutter/material.dart';
import 'package:purple_safety/emergency/emergency_mode_screen.dart';
import 'package:purple_safety/models/incident_model.dart';

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

  // Use this to activate emergency mode WITHOUT pushing the Emergency screen
  void setEmergencyActive(bool active) {
    if (active != _emergencyActive) {
      _emergencyActive = active;
      _emergencyStatusController.add(active);
    }
  }

  // Legacy method – pushes EmergencyModeScreen (used by the "Call Emergency" button)
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
    }
  }

  void deactivateEmergencyMode() {
    if (_emergencyActive) {
      _emergencyActive = false;
      _emergencyStatusController.add(false);
    }
  }

  void dispose() {
    _emergencyStatusController.close();
  }
}