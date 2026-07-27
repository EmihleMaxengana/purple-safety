import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InvitationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<bool> sendInvitation({
    required String inviterName,
    required String inviterEmail,
    required String inviteeEmail,
    required String inviterId,
  }) async {
    try {
      if (inviterEmail == inviteeEmail) {
        return false;
      }

      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: inviteeEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return false;
      }

      final inviteeId = userQuery.docs.first.id;

      // Check if the inviter already has this person as a contact
      final contactCheck = await _firestore
          .collection('users')
          .doc(inviterId)
          .collection('contacts')
          .where('userId', isEqualTo: inviteeId)
          .limit(1)
          .get();

      if (contactCheck.docs.isNotEmpty) {
        return false;
      }

      // Check for pending invitation FROM THIS USER to the invitee
      final pendingCheck = await _firestore
          .collection('invitations')
          .where('inviterId', isEqualTo: inviterId)
          .where('inviteeId', isEqualTo: inviteeId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (pendingCheck.docs.isNotEmpty) {
        return false;
      }

      // ============================================================
      // REMOVED: The reverse invitation check
      // User A can invite User B even if User B invited User A before
      // They are separate trust relationships
      // ============================================================

      final invitationRef = _firestore.collection('invitations').doc();
      final invitationId = invitationRef.id;

      await invitationRef.set({
        'id': invitationId,
        'inviterId': inviterId,
        'inviterName': inviterName,
        'inviterEmail': inviterEmail,
        'inviteeId': inviteeId,
        'inviteeEmail': inviteeEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
      });

      await _firestore
          .collection('users')
          .doc(inviteeId)
          .collection('alerts')
          .add({
            'message': '$inviterName invited you to be their trusted contact. Tap to respond.',
            'type': 'invitation',
            'invitationId': invitationId,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

      return true;
    } catch (e) {
      return false;
    }
  }

  static Stream<List<Map<String, dynamic>>> getPendingInvitations() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('invitations')
        .where('inviteeId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'inviterId': data['inviterId'],
              'inviterName': data['inviterName'],
              'inviterEmail': data['inviterEmail'],
              'createdAt': data['createdAt'],
            };
          }).toList();
        });
  }

  static Future<bool> acceptInvitation(String invitationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final invitationDoc = await _firestore.collection('invitations').doc(invitationId).get();
      if (!invitationDoc.exists) return false;

      final data = invitationDoc.data()!;
      
      if (data['status'] != 'pending') {
        return false;
      }

      final inviterId = data['inviterId'];
      final inviteeId = user.uid;

      final inviteeUserDoc = await _firestore.collection('users').doc(inviteeId).get();
      final inviteeName = inviteeUserDoc.data()?['name'] ?? 'User';
      final inviteePhone = inviteeUserDoc.data()?['phone'] ?? '';

      // Check if the inviter already has this person as a contact
      final existingCheck = await _firestore
          .collection('users')
          .doc(inviterId)
          .collection('contacts')
          .where('userId', isEqualTo: inviteeId)
          .limit(1)
          .get();

      if (existingCheck.docs.isNotEmpty) {
        await _firestore.collection('invitations').doc(invitationId).update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      // Update invitation status
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // ============================================================
      // ONE-WAY ONLY: Add the invitee (User B) to the inviter's (User A) contacts
      // DO NOT add the inviter (User A) to the invitee's (User B) contacts
      // User B must send their own invitation to User A if they want to trust them
      // ============================================================
      final contactId = DateTime.now().millisecondsSinceEpoch.toString();

      await _firestore
          .collection('users')
          .doc(inviterId)  // ONLY User A's contacts collection
          .collection('contacts')
          .doc(contactId)
          .set({
            'id': contactId,
            'userId': inviteeId,  // User B
            'name': inviteeName,
            'initials': inviteeName.isNotEmpty ? inviteeName[0].toUpperCase() : '?',
            'color': Colors.primaries[DateTime.now().millisecond % Colors.primaries.length].value,
            'active': true,
            'phone': inviteePhone,
            'relationship': 'Trusted Contact',
            'socialLinks': {},
          });

      // ============================================================
      // REMOVED: The code that was adding inviter to invitee's contacts
      // NO LONGER creating contacts in invitee's collection
      // ============================================================

      // Notify inviter (User A) that User B accepted
      await _firestore
          .collection('users')
          .doc(inviterId)
          .collection('alerts')
          .add({
            'message': '$inviteeName accepted your trusted contact invitation!',
            'type': 'info',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> declineInvitation(String invitationId) async {
    try {
      final invitationDoc = await _firestore.collection('invitations').doc(invitationId).get();
      if (!invitationDoc.exists) return false;
      
      final data = invitationDoc.data()!;
      if (data['status'] != 'pending') return false;
      
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get all trusted contacts for a user
  static Stream<List<Map<String, dynamic>>> getTrustedContacts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'userId': data['userId'],
              'name': data['name'],
              'phone': data['phone'],
            };
          }).toList();
        });
  }
}