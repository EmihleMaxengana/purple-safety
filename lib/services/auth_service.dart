import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        if (nextOfKinName != null && nextOfKinName.isNotEmpty) userData['nextOfKinName'] = nextOfKinName;
        if (nextOfKinPhone != null && nextOfKinPhone.isNotEmpty) userData['nextOfKinPhone'] = nextOfKinPhone;
        if (nextOfKinRelation != null && nextOfKinRelation.isNotEmpty) userData['nextOfKinRelation'] = nextOfKinRelation;
        if (nextOfKinAltPhone != null && nextOfKinAltPhone.isNotEmpty) userData['nextOfKinAltPhone'] = nextOfKinAltPhone;
        if (gender != null && gender.isNotEmpty) userData['gender'] = gender;
        
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
}