import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InvitationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send invitation (ONE-WAY)
  static Future<bool> sendInvitation({
    required String inviterName,
    required String inviterEmail,
    required String inviteeEmail,
    required String inviterId,
  }) async {
    try {
      // Prevent self-invitation
      if (inviterEmail == inviteeEmail) {
        print('Cannot invite yourself');
        return false;
      }

      // Find invitee user (they must have an account)
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: inviteeEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('User not found');
        return false;
      }

      final inviteeId = userQuery.docs.first.id;

      // Check if already a trusted contact (one-way from inviter to invitee)
      final existingContact = await _firestore
          .collection('users')
          .doc(inviterId)
          .collection('contacts')
          .where('id', isEqualTo: inviteeId)
          .limit(1)
          .get();
      
      if (existingContact.docs.isNotEmpty) {
        print('Already a trusted contact');
        return false;
      }

      // Check if invitation already exists
      final existingInvitation = await _firestore
          .collection('invitations')
          .where('inviterId', isEqualTo: inviterId)
          .where('inviteeId', isEqualTo: inviteeId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingInvitation.docs.isNotEmpty) {
        print('Invitation already exists');
        return false;
      }

      // Create invitation
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

      // Send in-app notification
      await _firestore
          .collection('users')
          .doc(inviteeId)
          .collection('alerts')
          .add({
            'message': '🔐 $inviterName invited you to be their trusted contact. Tap to respond.',
            'type': 'invitation',
            'invitationId': invitationId,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

      return true;
    } catch (e) {
      print('Error sending invitation: $e');
      return false;
    }
  }

  // Get pending invitations for current user
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

  // Accept invitation - ONE WAY: adds invitee to inviter's contacts ONLY
  static Future<bool> acceptInvitation(String invitationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final invitationDoc = await _firestore.collection('invitations').doc(invitationId).get();
      if (!invitationDoc.exists) return false;

      final data = invitationDoc.data()!;
      
      if (data['status'] != 'pending') {
        print('Invitation already processed');
        return false;
      }

      final inviterId = data['inviterId'];
      final inviteeId = user.uid;

      // Check if already a trusted contact
      final existingContact = await _firestore
          .collection('users')
          .doc(inviterId)
          .collection('contacts')
          .where('id', isEqualTo: inviteeId)
          .limit(1)
          .get();
      
      if (existingContact.docs.isNotEmpty) {
        print('Already a trusted contact');
        await _firestore.collection('invitations').doc(invitationId).update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      // Get invitee name
      final inviteeUserDoc = await _firestore.collection('users').doc(inviteeId).get();
      final inviteeName = inviteeUserDoc.data()?['name'] ?? 'User';

      // Update invitation status
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // ONE-WAY: Add invitee to inviter's trusted contacts ONLY
      await _addTrustedContact(
        userId: inviterId, 
        trustedUserId: inviteeId, 
        name: inviteeName,
      );

      // Send notification to inviter
      await _firestore
          .collection('users')
          .doc(inviterId)
          .collection('alerts')
          .add({
            'message': '✅ $inviteeName accepted your trusted contact invitation!',
            'type': 'info',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

      return true;
    } catch (e) {
      print('Error accepting invitation: $e');
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
      print('Error declining invitation: $e');
      return false;
    }
  }

  static Future<void> _addTrustedContact({
    required String userId, 
    required String trustedUserId, 
    required String name,
  }) async {
    // Check if contact already exists
    final existingContact = await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .where('id', isEqualTo: trustedUserId)
        .limit(1)
        .get();
    
    if (existingContact.docs.isNotEmpty) {
      print('Contact already exists for $userId');
      return;
    }
    
    // Check contact limit (max 5)
    final allContacts = await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .get();
    
    if (allContacts.docs.length >= 5) {
      print('User already has 5 contacts, cannot add more');
      return;
    }
    
    final contactId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Get phone number if available
    final trustedUserDoc = await _firestore.collection('users').doc(trustedUserId).get();
    final phone = trustedUserDoc.data()?['phone'] ?? '';
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId)
        .set({
          'id': contactId,
          'name': name,
          'initials': name.isNotEmpty ? name[0].toUpperCase() : '?',
          'color': Colors.primaries[DateTime.now().millisecond % Colors.primaries.length].value,
          'active': true,
          'phone': phone,
          'relationship': 'Trusted Contact',
          'socialLinks': {},
        });
    
    print('Added contact $name to user $userId');
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
              'userId': data['id'],
              'name': data['name'],
              'phone': data['phone'],
            };
          }).toList();
        });
  }
}