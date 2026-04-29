import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _sosFingerprintEnabledKey = 'sos_fingerprint_enabled';
  static const String _userPinKey = 'user_pin';

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

  static Future<bool> authenticateWithPinFallback({
    required BuildContext context,
    required String reason,
  }) async {
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: reason,
      );
      if (authenticated) return true;
    } catch (e) {
      print('Biometric error: $e');
    }
    
    return await _showPinDialog(context, reason);
  }

  static Future<bool> _showPinDialog(BuildContext context, String reason) async {
    String enteredPin = '';
    bool isFirstTime = await _isFirstTimePinSetup();
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isFirstTime ? 'Set Up PIN' : 'Enter PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFirstTime)
              Text(
                reason,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: isFirstTime ? 'Enter 6-digit PIN' : 'Enter your 6-digit PIN',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
              onChanged: (value) {
                enteredPin = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (enteredPin.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a 6-digit PIN'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              if (isFirstTime) {
                await _savePin(enteredPin);
                Navigator.pop(context, true);
              } else {
                final isValid = await _verifyPin(enteredPin);
                if (isValid) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid PIN. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isFirstTime ? 'Set PIN' : 'Verify'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  static Future<bool> _isFirstTimePinSetup() async {
    final String? pin = await _storage.read(key: _userPinKey);
    return pin == null;
  }

  static Future<void> _savePin(String pin) async {
    await _storage.write(key: _userPinKey, value: pin);
  }

  static Future<bool> _verifyPin(String enteredPin) async {
    final String? storedPin = await _storage.read(key: _userPinKey);
    return storedPin == enteredPin;
  }

  static Future<bool> isPinSetup() async {
    final String? pin = await _storage.read(key: _userPinKey);
    return pin != null;
  }

  static Future<bool> resetPin(BuildContext context) async {
    final authenticated = await authenticateWithPinFallback(
      context: context,
      reason: 'Authenticate to change your PIN',
    );
    
    if (authenticated) {
      await _storage.delete(key: _userPinKey);
      return await _showPinDialog(context, 'Set up your new PIN');
    }
    return false;
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