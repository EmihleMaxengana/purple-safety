import 'package:firebase_auth/firebase_auth.dart';

class OTPService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send email verification link to the current user
  static Future<bool> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in to send email verification');
        return false;
      }
      await user.sendEmailVerification();
      print('✅ Email verification sent to ${user.email}');
      return true;
    } catch (e) {
      print('❌ Error sending email verification: $e');
      return false;
    }
  }

  // Check if the user's email is verified (call this periodically)
  static Future<bool> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      // Reload user to get latest verification status from Firebase
      await user.reload();
      // Refresh the currentUser instance
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        return false;
      }
      return refreshedUser.emailVerified;
    } catch (e) {
      print('❌ Error checking email verification: $e');
      return false;
    }
  }

  // Resend email verification link
  static Future<bool> resendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in to resend email verification');
        return false;
      }
      await user.sendEmailVerification();
      print('✅ Email verification resent to ${user.email}');
      return true;
    } catch (e) {
      print('❌ Error resending email verification: $e');
      return false;
    }
  }
}