import 'dart:async';
import 'package:flutter/material.dart';
import 'emergency_mode_screen.dart';

class EmergencyManager {
  static final EmergencyManager _instance = EmergencyManager._internal();

  factory EmergencyManager() {
    return _instance;
  }

  EmergencyManager._internal();

  bool _emergencyActive = false;
  StreamController<bool> _emergencyStatusController =
      StreamController<bool>.broadcast();

  Stream<bool> get emergencyStatusStream => _emergencyStatusController.stream;
  bool get isEmergencyActive => _emergencyActive;

  void activateEmergencyMode(BuildContext context) {
    if (!_emergencyActive) {
      _emergencyActive = true;
      _emergencyStatusController.add(true);

      // Navigate to emergency mode screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EmergencyModeScreen()),
      );

      // Simulate emergency processes
      _simulateEmergencyProcesses(context);
    }
  }

  void deactivateEmergencyMode() {
    if (_emergencyActive) {
      _emergencyActive = false;
      _emergencyStatusController.add(false);
      // Add any cleanup logic here
    }
  }

  void _simulateEmergencyProcesses(BuildContext context) {
    // Simulate sending alerts
    Future.delayed(const Duration(seconds: 2), () {
      // This could be replaced with actual API calls
      debugPrint('Emergency alerts sent');
    });
  }
}
