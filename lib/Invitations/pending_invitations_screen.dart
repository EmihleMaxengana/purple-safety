import 'package:flutter/material.dart';
import 'package:purple_safety/contacts/invitation_service.dart';

class PendingInvitationsScreen extends StatefulWidget {
  const PendingInvitationsScreen({Key? key}) : super(key: key);

  @override
  State<PendingInvitationsScreen> createState() => _PendingInvitationsScreenState();
}

class _PendingInvitationsScreenState extends State<PendingInvitationsScreen> {
  List<Map<String, dynamic>> _pendingInvitations = [];
  bool _isLoading = true;
  String _processingId = '';

  @override
  void initState() {
    super.initState();
    _listenToInvitations();
  }

  void _listenToInvitations() {
    InvitationService.getPendingInvitations().listen((invitations) {
      if (mounted) {
        setState(() {
          _pendingInvitations = invitations;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _acceptInvitation(String invitationId, String inviterName) async {
    if (_processingId == invitationId) return;
    
    setState(() {
      _processingId = invitationId;
      _isLoading = true;
    });
    
    final success = await InvitationService.acceptInvitation(invitationId);
    
    if (success && mounted) {
      setState(() {
        _pendingInvitations.removeWhere((inv) => inv['id'] == invitationId);
        _processingId = '';
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are now $inviterName\'s trusted contact. They can see your location when you share it.'),
          backgroundColor: Colors.green,
        ),
      );
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } else if (mounted) {
      setState(() {
        _processingId = '';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not accept invitation. It may have expired.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineInvitation(String invitationId) async {
    if (_processingId == invitationId) return;
    
    setState(() {
      _processingId = invitationId;
      _isLoading = true;
    });
    
    final success = await InvitationService.declineInvitation(invitationId);
    
    if (success && mounted) {
      setState(() {
        _pendingInvitations.removeWhere((inv) => inv['id'] == invitationId);
        _processingId = '';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation declined.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (mounted) {
      setState(() {
        _processingId = '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0e0718),
      appBar: AppBar(
        title: const Text('Pending Invitations'),
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
        child: _isLoading && _pendingInvitations.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Colors.purple),
              )
            : _pendingInvitations.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.white38),
                        SizedBox(height: 16),
                        Text(
                          'No pending invitations',
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'When someone invites you, it will appear here',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingInvitations.length,
                    itemBuilder: (context, index) {
                      final invitation = _pendingInvitations[index];
                      final isProcessing = _processingId == invitation['id'];
                      return Card(
                        color: const Color(0xFF1a0f2e),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.purple.withOpacity(0.2),
                                    child: Text(
                                      invitation['inviterName'][0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          invitation['inviterName'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          invitation['inviterEmail'],
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: isProcessing ? null : () => _declineInvitation(invitation['id']),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                      child: isProcessing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.red,
                                              ),
                                            )
                                          : const Text('Decline'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: isProcessing ? null : () => _acceptInvitation(
                                        invitation['id'],
                                        invitation['inviterName'],
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      child: isProcessing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Accept'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}