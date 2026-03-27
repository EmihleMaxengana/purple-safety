import 'dart:async';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import 'emergency_mode_screen.dart';

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
  void activateEmergencyModeLight({List<Contact>? contacts}) {
    if (!_emergencyActive) {
      _emergencyActive = true;
      if (contacts != null) {
        _currentContacts = contacts;
      }
      _emergencyStatusController.add(true);
    }
  }

  void deactivateEmergencyMode() {
    if (_emergencyActive) {
      _emergencyActive = false;
      _emergencyStatusController.add(false);
    }
  }

  void _simulateEmergencyProcesses(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      debugPrint('Emergency alerts sent');
    });
  }
}
