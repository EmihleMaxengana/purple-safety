import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _sessionKeyPrefix = 'session_verified_';
  static const String _requireReauthKey = 'require_reauth';

  Future<void> savePin(String pin) async {
    try {
      await _storage.write(key: 'user_pin', value: pin);
    } catch (e) {
      print('Error saving PIN: $e');
    }
  }

  Future<String?> getPin() async {
    try {
      return await _storage.read(key: 'user_pin');
    } catch (e) {
      print('Error getting PIN: $e');
      return null;
    }
  }

  Future<User?> registerWithEmail(
    String fullName,
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
        await Future.delayed(const Duration(milliseconds: 500));

        final currentUser = _auth.currentUser;
        if (currentUser == null || currentUser.uid != user.uid) {
          throw Exception('Authentication state not ready. Please try again.');
        }

        Map<String, dynamic> userData = {
          'name': fullName,
          'email': email,
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (nextOfKinName != null && nextOfKinName.isNotEmpty) {
          userData['nextOfKinName'] = nextOfKinName;
        }
        if (nextOfKinPhone != null && nextOfKinPhone.isNotEmpty) {
          userData['nextOfKinPhone'] = nextOfKinPhone;
        }
        if (nextOfKinRelation != null && nextOfKinRelation.isNotEmpty) {
          userData['nextOfKinRelation'] = nextOfKinRelation;
        }
        if (nextOfKinAltPhone != null && nextOfKinAltPhone.isNotEmpty) {
          userData['nextOfKinAltPhone'] = nextOfKinAltPhone;
        }
        if (gender != null && gender.isNotEmpty) {
          userData['gender'] = gender;
        }

        int retryCount = 0;
        bool saved = false;
        while (retryCount < 3 && !saved) {
          try {
            await _firestore.collection('users').doc(user.uid).set(userData);
            saved = true;
          } catch (e) {
            retryCount++;
            if (retryCount < 3) {
              await Future.delayed(const Duration(milliseconds: 500));
            } else {
              rethrow;
            }
          }
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final existingUser = _auth.currentUser;
        if (existingUser != null && existingUser.email == email) {
          return existingUser;
        }
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message =
              'No account found with this email address. Please create an account first.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'Invalid email address format.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled. Please contact support.';
          break;
        case 'too-many-requests':
          message = 'Too many failed login attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Password reset error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() as Map<String, dynamic>?;
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

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

  Future<void> markRequireReauth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_requireReauthKey, true);
    } catch (e) {
      print('Error setting requireReauth flag: $e');
    }
  }

  Future<void> clearRequireReauth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_requireReauthKey, false);
    } catch (e) {
      print('Error clearing requireReauth flag: $e');
    }
  }

  Future<bool> isRequireReauth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_requireReauthKey) ?? false;
    } catch (e) {
      print('Error reading requireReauth flag: $e');
      return false;
    }
  }

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

  Future<bool> reauthenticateWithPIN(String pin) async {
    try {
      String? storedPin = await _storage.read(key: 'user_pin');
      if (storedPin == null) {
        return false;
      }
      return pin == storedPin;
    } catch (e) {
      return false;
    }
  }

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
