import 'package:flutter/material.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/contacts/invitation_service.dart';
import 'package:purple_safety/contacts/firestore_service.dart';

class InviteContactScreen extends StatefulWidget {
  const InviteContactScreen({Key? key}) : super(key: key);

  @override
  State<InviteContactScreen> createState() => _InviteContactScreenState();
}

class _InviteContactScreenState extends State<InviteContactScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  int _currentContactCount = 0;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadContactCount();
  }

  Future<void> _loadContactCount() async {
    final user = AuthService().getCurrentUser();
    if (user != null) {
      final contacts = await _firestoreService
          .getContactsStream(user.uid)
          .first;
      setState(() {
        _currentContactCount = contacts.length;
      });
    }
  }

  Future<void> _sendInvitation() async {
    if (_currentContactCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have 5 trusted contacts. Delete one to add more.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = AuthService().getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to invite contacts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prevent inviting yourself
    final currentUserEmail = user.email;
    if (email == currentUserEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot invite yourself as a trusted contact.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userData = await AuthService().getUserData(user.uid);
    final userName = userData?['name'] ?? 'Someone';
    final userEmail = userData?['email'] ?? user.email ?? '';

    setState(() {
      _isLoading = true;
    });

    final success = await InvitationService.sendInvitation(
      inviterName: userName,
      inviterEmail: userEmail,
      inviteeEmail: email,
      inviterId: user.uid,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation sent! They will receive a notification.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send invitation. They may already be your trusted contact.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0e0718),
      appBar: AppBar(
        title: const Text('Invite Trusted Contact'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.person_add_alt_1,
                  color: Colors.white70,
                  size: 60,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Invite a Trusted Contact',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_currentContactCount/5',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter their email address. They will receive an invitation to become your trusted contact.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 30),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Email address',
                      hintStyle: TextStyle(color: Color(0xFFBF7DCB)),
                      prefixIcon: Icon(Icons.email, color: Color(0xFFBF7DCB)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendInvitation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Send Invitation',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your contact will receive an in-app notification. Once they accept, they will appear in your trusted contacts list.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}