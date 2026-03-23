import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _sosFingerprintEnabledKey = 'sos_fingerprint_enabled';

  // Check if fingerprint hardware is available AND enrolled
  static Future<bool> isFingerprintAvailable() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final List<BiometricType> availableTypes = await _auth
          .getAvailableBiometrics();

      // Check if fingerprint (Touch ID on iOS, fingerprint on Android) is available
      return availableTypes.contains(BiometricType.fingerprint);
    } on PlatformException catch (e) {
      print('Error checking biometrics: $e');
      return false;
    }
  }

  // Check if any biometric is available (fallback for info)
  static Future<bool> hasAnyBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  // Authenticate with fingerprint (biometric only)
  static Future<bool> authenticate({required String reason}) async {
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return authenticated;
    } catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

  // Enable SOS fingerprint trigger
  static Future<bool> enableSOSFingerprint() async {
    final available = await isFingerprintAvailable();
    if (!available) return false;

    final bool authenticated = await authenticate(
      reason: 'Set up fingerprint for SOS emergency trigger',
    );

    if (authenticated) {
      await _storage.write(key: _sosFingerprintEnabledKey, value: 'true');
      return true;
    }
    return false;
  }

  // Check if SOS fingerprint is enabled
  static Future<bool> isSOSFingerprintEnabled() async {
    final String? value = await _storage.read(key: _sosFingerprintEnabledKey);
    return value == 'true';
  }

  // Trigger SOS with fingerprint
  static Future<bool> triggerSOSWithFingerprint() async {
    // Check if SOS fingerprint is enabled first
    final enabled = await isSOSFingerprintEnabled();
    if (!enabled) return false;

    return await authenticate(
      reason: 'FINGERPRINT SOS - Emergency services will be notified',
    );
  }
}
