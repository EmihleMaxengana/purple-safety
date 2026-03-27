import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _sosFingerprintEnabledKey = 'sos_fingerprint_enabled';

  static Future<bool> isFingerprintAvailable() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final List<BiometricType> availableTypes = await _auth
          .getAvailableBiometrics();
      return availableTypes.contains(BiometricType.fingerprint);
    } on PlatformException catch (e) {
      print('Error checking biometrics: $e');
      return false;
    }
  }

  static Future<bool> hasAnyBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticate({required String reason}) async {
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: reason,
      );
      return authenticated;
    } catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

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

  static Future<bool> isSOSFingerprintEnabled() async {
    final String? value = await _storage.read(key: _sosFingerprintEnabledKey);
    return value == 'true';
  }

  static Future<bool> triggerSOSWithFingerprint() async {
    final enabled = await isSOSFingerprintEnabled();
    if (!enabled) return false;

    return await authenticate(
      reason: 'FINGERPRINT SOS - Emergency services will be notified',
    );
  }
}
