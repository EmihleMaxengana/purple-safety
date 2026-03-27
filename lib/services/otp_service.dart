import 'package:firebase_auth/firebase_auth.dart';

class OTPService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? _verificationId;
  static int? _resendToken;

  // Send OTP via SMS
  static Future<bool> sendOtp(String phoneNumber) async {
    try {
      print('Sending OTP to phone number: $phoneNumber');
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('Verification auto-completed');
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed error code: ${e.code}');
          print('Verification failed message: ${e.message}');
          throw Exception('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Code sent successfully. Verification ID: $verificationId');
          _verificationId = verificationId;
          _resendToken = resendToken;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto-retrieval timeout. Verification ID: $verificationId');
          _verificationId = verificationId;
        },
      );
      return true;
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  // Verify the OTP entered by the user
  static Future<bool> verifyOtp(String enteredOtp) async {
    if (_verificationId == null) {
      print('No verification ID found - OTP was not sent successfully');
      return false;
    }
    try {
      print('Verifying OTP with verification ID: $_verificationId');
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: enteredOtp,
      );
      await _auth.signInWithCredential(credential);
      print('OTP verified successfully');
      return true;
    } catch (e) {
      print('OTP verification error: $e');
      return false;
    }
  }

  // Resend OTP
  static Future<bool> resendOtp(String phoneNumber) async {
    try {
      print('Resending OTP to phone number: $phoneNumber');
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {
          print('Verification auto-completed on resend');
        },
        verificationFailed: (e) {
          print('Resend verification failed: ${e.message}');
          throw Exception(e.message);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Resend code sent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
        },
        codeAutoRetrievalTimeout: (_) {
          print('Resend auto-retrieval timeout');
        },
        forceResendingToken: _resendToken,
      );
      return true;
    } catch (e) {
      print('Error resending OTP: $e');
      return false;
    }
  }
}
