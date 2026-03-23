import 'package:flutter/material.dart';

class OTPService {
  static String? _storedOtp;

  // Send OTP to the given phone number (mock)
  static Future<bool> sendOtp(String phoneNumber) async {
    // In a real app, you'd call an API to send SMS.
    // For testing, we generate a random 6-digit OTP and print it.
    _storedOtp = (100000 + DateTime.now().millisecondsSinceEpoch % 900000)
        .toString();
    debugPrint('Mock OTP for $phoneNumber: $_storedOtp');
    return true;
  }

  // Verify the OTP entered by the user
  static Future<bool> verifyOtp(String enteredOtp) async {
    await Future.delayed(const Duration(seconds: 1)); // simulate network delay
    return enteredOtp == _storedOtp;
  }
}
