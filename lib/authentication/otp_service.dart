import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class OTPService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static const int OTP_VALIDITY_MINUTES = 10;
  static const int OTP_LENGTH = 6;
  static const String OTP_COLLECTION = 'otps';

  static const String _sendOTPUrl =
      'https://sendotpemail-6qju6ualcq-uc.a.run.app';

  static String _generateOTP() {
    Random random = Random();
    int otp = random.nextInt(900000) + 100000;
    return otp.toString();
  }

  /// Send OTP to email for registration
  static Future<Map<String, dynamic>?> sendOTPForRegistration(
    String email,
  ) async {
    try {
      final otp = _generateOTP();
      final expirationTime = DateTime.now().add(
        Duration(minutes: OTP_VALIDITY_MINUTES),
      );

      await _firestore.collection(OTP_COLLECTION).doc(email).set({
        'otp': otp,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expirationTime),
        'attempts': 0,
        'verified': false,
      });

      try {
        final callable = _functions.httpsCallable('sendOTPEmail');
        await callable.call({'email': email, 'otp': otp});
        print('✅ OTP sent to $email');
      } catch (e) {
        return {'success': false, 'message': 'Failed to send OTP email: $e'};
      }

      return {
        'success': true,
        'expiresIn': OTP_VALIDITY_MINUTES,
        'message': 'OTP sent successfully',
      };
    } catch (e) {
      print('❌ Error sending OTP: $e');
      return {'success': false, 'message': 'Failed to send OTP: $e'};
    }
  }

  /// Verify OTP code entered by user
  static Future<Map<String, dynamic>> verifyOTP(
    String email,
    String enteredOTP,
  ) async {
    try {
      final docSnapshot = await _firestore
          .collection(OTP_COLLECTION)
          .doc(email)
          .get();

      if (!docSnapshot.exists) {
        return {
          'success': false,
          'message': 'No OTP found for this email. Please request a new one.',
        };
      }

      final data = docSnapshot.data();
      final storedOTP = data?['otp'];
      final expiresAt = (data?['expiresAt'] as Timestamp?)?.toDate();
      final verified = data?['verified'] ?? false;

      if (verified) {
        return {
          'success': false,
          'message': 'This OTP has already been verified.',
        };
      }

      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        return {
          'success': false,
          'message': 'OTP has expired. Please request a new one.',
          'expired': true,
        };
      }

      int currentAttempts = data?['attempts'] ?? 0;
      if (currentAttempts >= 5) {
        return {
          'success': false,
          'message': 'Too many incorrect attempts. Please request a new OTP.',
          'maxAttempts': true,
        };
      }

      if (storedOTP == enteredOTP.trim()) {
        await _firestore.collection(OTP_COLLECTION).doc(email).update({
          'verified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        return {'success': true, 'message': 'OTP verified successfully!'};
      } else {
        await _firestore.collection(OTP_COLLECTION).doc(email).update({
          'attempts': currentAttempts + 1,
        });

        return {
          'success': false,
          'message': 'Incorrect OTP. Please try again.',
          'attemptsRemaining': 5 - (currentAttempts + 1),
        };
      }
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      return {'success': false, 'message': 'Error verifying OTP: $e'};
    }
  }

  static Future<bool> isOTPVerified(String email) async {
    try {
      final docSnapshot = await _firestore
          .collection(OTP_COLLECTION)
          .doc(email)
          .get();

      if (!docSnapshot.exists) {
        return false;
      }

      return docSnapshot.data()?['verified'] ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<int?> getOTPRemainingSeconds(String email) async {
    try {
      final docSnapshot = await _firestore
          .collection(OTP_COLLECTION)
          .doc(email)
          .get();

      if (!docSnapshot.exists) {
        return null;
      }

      final expiresAt = (docSnapshot.data()?['expiresAt'] as Timestamp?)
          ?.toDate();
      if (expiresAt == null) {
        return null;
      }

      final remaining = expiresAt.difference(DateTime.now()).inSeconds;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> resendOTP(String email) async {
    try {
      await _firestore.collection(OTP_COLLECTION).doc(email).delete();

      // Send new OTP
      return await sendOTPForRegistration(email);
    } catch (e) {
      print('❌ Error resending OTP: $e');
      return {'success': false, 'message': 'Failed to resend OTP: $e'};
    }
  }

  static Future<void> cleanupOTP(String email) async {
    try {
      await _firestore.collection(OTP_COLLECTION).doc(email).delete();
    } catch (e) {
      //(silent cleanup)
    }
  }
}
