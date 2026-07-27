import 'package:flutter/material.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/contacts/firestore_service.dart';
import 'package:purple_safety/contacts/invitation_service.dart';
import 'package:purple_safety/incidents/incident_detail_screen.dart';
import 'package:purple_safety/incidents/incident_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SafetyAlertsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToCommunity;

  const SafetyAlertsScreen({Key? key, this.onNavigateToCommunity}) : super(key: key);

  @override
  State<SafetyAlertsScreen> createState() => _SafetyAlertsScreenState();
}

class _SafetyAlertsScreenState extends State<SafetyAlertsScreen>
    with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _auth = AuthService();
  final IncidentService _incidentService = IncidentService();

  late TabController _tabController;
  late TabController _invitationTabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _invitationTabController = TabController(length: 2, vsync: this);
    
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invitationTabController.dispose();
    super.dispose();
  }

  Future<void> _onAlertTap(Alert alert) async {
    final user = _auth.getCurrentUser();
    if (user != null) {
      await _firestoreService.markAlertAsRead(user.uid, alert.id);
    }

    if (alert.type == 'sos' && alert.sosEventId != null) {
      final isActive = await _isSOSActive(alert.sosEventId!);
      if (!isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This SOS alert has already been resolved.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, 'sos');
        return;
      }
      Navigator.pop(context, 'sos');
      return;
    }

    if (alert.type == 'incident' && alert.incidentId != null) {
      final incident = await _incidentService.getIncident(alert.incidentId!);
      if (incident != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IncidentDetailScreen(incident: incident),
          ),
        );
      }
      return;
    }

    if (alert.type == 'invitation' && alert.invitationId != null) {
      _tabController.animateTo(1);
    }
  }

  Future<bool> _isSOSActive(String sosEventId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('active_sos_events')
          .doc(sosEventId)
          .get();
      if (!doc.exists) return false;
      final data = doc.data();
      return data?['status'] == 'active';
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // BUILD RECEIVED INVITATIONS - SORTED BY DATE (NEWEST FIRST)
  // ============================================================
  Widget _buildReceivedInvitations() {
    final user = _auth.getCurrentUser();
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invitations')
          .where('inviteeId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading invitations: ${snapshot.error}',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.white38),
                SizedBox(height: 16),
                Text(
                  'No invitations received',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  'When someone invites you, it will appear here',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // ============================================================
        // SORT MANUALLY: Most recent first (newest createdAt)
        // ============================================================
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.toDate().compareTo(aTime.toDate());
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final invitationId = doc.id;
            final inviterName = data['inviterName'] ?? 'Someone';
            final inviterEmail = data['inviterEmail'] ?? '';
            final status = data['status'] ?? 'pending';
            final createdAt = data['createdAt'] as Timestamp?;

            // Determine status display
            String statusText = 'Pending';
            Color statusColor = Colors.orange;
            IconData statusIcon = Icons.hourglass_empty;

            switch (status) {
              case 'accepted':
                statusText = 'Accepted ✓';
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              case 'declined':
                statusText = 'Declined ✗';
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
                break;
              default:
                statusText = 'Pending';
                statusColor = Colors.orange;
                statusIcon = Icons.hourglass_empty;
            }

            final isPending = status == 'pending';

            return Card(
              color: const Color(0xFF1a0f2e),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: statusColor.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.2),
                          child: Text(
                            inviterName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inviterName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                inviterEmail,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (createdAt != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Received ${_formatTime(createdAt.toDate())}',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final success = await InvitationService.declineInvitation(invitationId);
                                if (success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invitation declined'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final success = await InvitationService.acceptInvitation(invitationId);
                                if (success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('You are now $inviterName\'s trusted contact!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD SENT INVITATIONS - SORTED BY DATE (NEWEST FIRST)
  // ============================================================
  Widget _buildSentInvitations() {
    final user = _auth.getCurrentUser();
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invitations')
          .where('inviterId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading invitations: ${snapshot.error}',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send, size: 64, color: Colors.white38),
                SizedBox(height: 16),
                Text(
                  'No invitations sent',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  'Invitations you send will appear here',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // ============================================================
        // SORT MANUALLY: Most recent first (newest createdAt)
        // ============================================================
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.toDate().compareTo(aTime.toDate());
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final inviteeEmail = data['inviteeEmail'] ?? 'Unknown';
            final createdAt = data['createdAt'] as Timestamp?;

            String statusText = 'Pending';
            Color statusColor = Colors.orange;
            IconData statusIcon = Icons.hourglass_empty;

            switch (status) {
              case 'accepted':
                statusText = 'Accepted ✓';
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              case 'declined':
                statusText = 'Declined ✗';
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
                break;
              default:
                statusText = 'Pending';
                statusColor = Colors.orange;
                statusIcon = Icons.hourglass_empty;
            }

            return Card(
              color: const Color(0xFF1a0f2e),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: statusColor.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.2),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inviteeEmail,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (createdAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(createdAt.toDate()),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (status == 'pending')
                      Icon(
                        Icons.hourglass_top,
                        color: Colors.orange,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotifications() {
    final user = _auth.getCurrentUser();
    if (user == null) return const SizedBox();

    return StreamBuilder<List<Alert>>(
      stream: _firestoreService.getAlertsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off, size: 64, color: Colors.white38),
                SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  'Alerts from the community will appear here',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final alerts = snapshot.data!
            .where((alert) => alert.type != 'invitation')
            .toList();

        if (alerts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off, size: 64, color: Colors.white38),
                SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  'Alerts from the community will appear here',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            Color color;
            IconData icon;

            if (alert.type == 'warning') {
              color = Colors.red;
              icon = Icons.warning;
            } else if (alert.type == 'incident') {
              color = Colors.orange;
              icon = Icons.report;
            } else if (alert.type == 'sos') {
              color = Colors.red;
              icon = Icons.sos;
            } else if (alert.type == 'safe') {
              color = Colors.green;
              icon = Icons.check_circle;
            } else if (alert.type == 'location_share') {
              color = Colors.blue;
              icon = Icons.location_on;
            } else {
              color = Colors.blue;
              icon = Icons.info;
            }

            return GestureDetector(
              onTap: () => _onAlertTap(alert),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: alert.read
                      ? Colors.white.withOpacity(0.05)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: alert.read
                        ? Colors.white.withOpacity(0.1)
                        : color.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.message,
                            style: TextStyle(
                              color: alert.read ? Colors.white70 : Colors.white,
                              fontSize: 14,
                              fontWeight: alert.read ? FontWeight.normal : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(alert.timestamp),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!alert.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (alert.type == 'incident' || alert.type == 'sos')
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white38,
                        size: 14,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.getCurrentUser();
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Alerts'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.notifications),
              text: 'Notifications',
            ),
            Tab(
              icon: Icon(Icons.mail),
              text: 'Invitations',
            ),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            TextButton(
              onPressed: () async {
                await _firestoreService.markAllAlertsAsRead(user.uid);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read')),
                );
              },
              child: const Text(
                'Read all',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNotifications(),
                  Column(
                    children: [
                      Container(
                        color: const Color(0xFF1a0f2e),
                        child: TabBar(
                          controller: _invitationTabController,
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.send),
                              text: 'Sent',
                            ),
                            Tab(
                              icon: Icon(Icons.inbox),
                              text: 'Received',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _invitationTabController,
                          children: [
                            _buildSentInvitations(),
                            _buildReceivedInvitations(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}