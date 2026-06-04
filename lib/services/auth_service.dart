import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AuthService provides authentication helpers plus a small
/// session / re-auth persistence layer used by the app to require
/// short re-authentication when the user returns to the app.

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register with email and password, with optional next of kin and gender
  Future<User?> registerWithEmail(
    String name,
    String email,
    String password,
    String phone, {
    String? nextOfKinName,
    String? nextOfKinPhone,
    String? nextOfKinRelation,
    String? nextOfKinAltPhone,
    String? gender,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        Map<String, dynamic> userData = {
          'name': name,
          'email': email,
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (nextOfKinName != null && nextOfKinName.isNotEmpty)
          userData['nextOfKinName'] = nextOfKinName;
        if (nextOfKinPhone != null && nextOfKinPhone.isNotEmpty)
          userData['nextOfKinPhone'] = nextOfKinPhone;
        if (nextOfKinRelation != null && nextOfKinRelation.isNotEmpty)
          userData['nextOfKinRelation'] = nextOfKinRelation;
        if (nextOfKinAltPhone != null && nextOfKinAltPhone.isNotEmpty)
          userData['nextOfKinAltPhone'] = nextOfKinAltPhone;

        await _firestore.collection('users').doc(user.uid).set(userData);
      }
      return user;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  // Login with email and password
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Password reset error: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() as Map<String, dynamic>?;
  }

  // Update user data (generic)
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // Update next of kin specifically
  Future<void> updateNextOfKin(
    String userId, {
    String? name,
    String? phone,
    String? relation,
    String? altPhone,
  }) async {
    Map<String, dynamic> updateData = {};
    if (name != null) updateData['nextOfKinName'] = name;
    if (phone != null) updateData['nextOfKinPhone'] = phone;
    if (relation != null) updateData['nextOfKinRelation'] = relation;
    if (altPhone != null) updateData['nextOfKinAltPhone'] = altPhone;
    if (updateData.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update(updateData);
    }
  }

  // --- Session / re-auth helpers ---
  static const String _sessionKeyPrefix = 'session_verified_';
  static const String _requireReauthKey = 'require_reauth';

  /// Mark the session as verified (store timestamp for current user)
  Future<void> markSessionVerified() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await prefs.setString(
          '${_sessionKeyPrefix}$userId',
          DateTime.now().toIso8601String(),
        );
        await prefs.setBool(_requireReauthKey, false);
      }
    } catch (e) {
      print('Error marking session verified: $e');
    }
  }

  /// Mark that reauth is required (called when app is backgrounded/exited)
  Future<void> markRequireReauth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_requireReauthKey, true);
    } catch (e) {
      print('Error setting requireReauth flag: $e');
    }
  }

  /// Clear the require reauth flag
  Future<void> clearRequireReauth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_requireReauthKey, false);
    } catch (e) {
      print('Error clearing requireReauth flag: $e');
    }
  }

  /// Returns true if the app currently requires re-authentication
  Future<bool> isRequireReauth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_requireReauthKey) ?? false;
    } catch (e) {
      print('Error reading requireReauth flag: $e');
      return false;
    }
  }

  /// Re-authenticate the current user using their password without
  /// signing them out/in. Uses Firebase `reauthenticateWithCredential`.
  Future<bool> reauthenticateWithPassword(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final email = user.email;
      if (email == null) return false;
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print('Re-authentication failed: $e');
      return false;
    }
  }

  /// Clear stored session info for current user
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await prefs.remove('${_sessionKeyPrefix}$userId');
      }
      await prefs.setBool(_requireReauthKey, false);
    } catch (e) {
      print('Error clearing session: $e');
    }
  }
}
