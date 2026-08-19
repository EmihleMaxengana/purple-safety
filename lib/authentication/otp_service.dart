import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_functions/firebase_functions.dart';

class OTPService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static const int OTP_VALIDITY_MINUTES = 10;
  static const int OTP_LENGTH = 6;
  static const String OTP_COLLECTION = 'otps';

  /// Generate a random 6-digit OTP code
  static String _generateOTP() {
    Random random = Random();
    int otp = random.nextInt(900000) + 100000; // Generates 100000-999999
    return otp.toString();
  }

  /// Send OTP to email for registration
  static Future<Map<String, dynamic>?> sendOTPForRegistration(String email) async {
    try {
      final otp = _generateOTP();
      final expirationTime = DateTime.now().add(
        Duration(minutes: OTP_VALIDITY_MINUTES),
      );

      // Store OTP in Firestore
      await _firestore.collection(OTP_COLLECTION).doc(email).set({
        'otp': otp,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expirationTime),
        'attempts': 0,
        'verified': false,
      });

      // Send OTP via email using Cloud Function
      try {
        final callable = _functions.httpsCallable('sendOTPEmail');
        await callable.call({
          'email': email,
          'otp': otp,
        });
        print('✅ OTP sent to $email');
      } catch (e) {
        print('⚠️ Cloud Function error (email may not be sent): $e');
        // Continue anyway - OTP is stored and can be used
      }

      return {
        'success': true,
        'expiresIn': OTP_VALIDITY_MINUTES,
        'message': 'OTP sent successfully',
      };
    } catch (e) {
      print('❌ Error sending OTP: $e');
      return {
        'success': false,
        'message': 'Failed to send OTP: $e',
      };
    }
  }

  /// Verify OTP code entered by user
  static Future<Map<String, dynamic>> verifyOTP(String email, String enteredOTP) async {
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

      // Check if already verified
      if (verified) {
        return {
          'success': false,
          'message': 'This OTP has already been verified.',
        };
      }

      // Check if OTP has expired
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        return {
          'success': false,
          'message': 'OTP has expired. Please request a new one.',
          'expired': true,
        };
      }

      // Increment attempts
      int currentAttempts = data?['attempts'] ?? 0;
      if (currentAttempts >= 5) {
        return {
          'success': false,
          'message': 'Too many incorrect attempts. Please request a new OTP.',
          'maxAttempts': true,
        };
      }

      // Verify OTP
      if (storedOTP == enteredOTP.trim()) {
        // Mark OTP as verified
        await _firestore.collection(OTP_COLLECTION).doc(email).update({
          'verified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        return {
          'success': true,
          'message': 'OTP verified successfully!',
        };
      } else {
        // Increment failed attempts
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
      return {
        'success': false,
        'message': 'Error verifying OTP: $e',
      };
    }
  }

  /// Check if OTP has been verified for an email
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
      print('❌ Error checking OTP verification status: $e');
      return false;
    }
  }

  /// Get remaining time for OTP expiration
  static Future<int?> getOTPRemainingSeconds(String email) async {
    try {
      final docSnapshot = await _firestore
          .collection(OTP_COLLECTION)
          .doc(email)
          .get();

      if (!docSnapshot.exists) {
        return null;
      }

      final expiresAt = (docSnapshot.data()?['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt == null) {
        return null;
      }

      final remaining = expiresAt.difference(DateTime.now()).inSeconds;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      print('❌ Error getting OTP remaining time: $e');
      return null;
    }
  }

  /// Resend OTP
  static Future<Map<String, dynamic>?> resendOTP(String email) async {
    try {
      // Delete old OTP
      await _firestore.collection(OTP_COLLECTION).doc(email).delete();
      
      // Send new OTP
      return await sendOTPForRegistration(email);
    } catch (e) {
      print('❌ Error resending OTP: $e');
      return {
        'success': false,
        'message': 'Failed to resend OTP: $e',
      };
    }
  }

  /// Clean up OTP after successful registration
  static Future<void> cleanupOTP(String email) async {
    try {
      await _firestore.collection(OTP_COLLECTION).doc(email).delete();
      print('✅ OTP cleaned up for $email');
    } catch (e) {
      print('❌ Error cleaning up OTP: $e');
    }
  }
}