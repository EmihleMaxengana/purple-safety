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

  int _unreadNotificationsCount = 0;
  int _unreadInvitationsCount = 0;
  int _unreadSentInvitationsCount = 0;
  int _unreadReceivedInvitationsCount = 0;

  bool _notificationsViewed = false;
  bool _sentInvitationsViewed = false;
  bool _receivedInvitationsViewed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _invitationTabController = TabController(length: 2, vsync: this);
    
    _tabController.addListener(() {
      setState(() {});
    });

    _invitationTabController.addListener(() {
      setState(() {});
    });

    _loadUnreadCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invitationTabController.dispose();
    super.dispose();
  }

  void _loadUnreadCounts() {
    final user = _auth.getCurrentUser();
    if (user == null) return;

    _firestoreService.getAlertsStream(user.uid).listen((alerts) {
      final unreadNotifications = alerts
          .where((a) => !a.read && a.type != 'invitation')
          .length;
      final unreadInvitations = alerts
          .where((a) => !a.read && a.type == 'invitation')
          .length;

      setState(() {
        _unreadNotificationsCount = unreadNotifications;
        _unreadInvitationsCount = unreadInvitations;
      });
    });

    FirebaseFirestore.instance
        .collection('invitations')
        .where('inviterId', isEqualTo: user.uid)
        .where('status', whereIn: ['accepted', 'declined'])
        .snapshots()
        .listen((snapshot) {
          final unreadSent = snapshot.docs.where((doc) {
            final data = doc.data();
            final viewed = data['viewedBySender'] ?? false;
            return viewed == false;
          }).length;

          setState(() {
            _unreadSentInvitationsCount = unreadSent;
          });
        });

    FirebaseFirestore.instance
        .collection('invitations')
        .where('inviteeId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          final unreadReceived = snapshot.docs.where((doc) {
            final data = doc.data();
            final viewed = data['viewedByReceiver'] ?? false;
            return viewed == false;
          }).length;

          setState(() {
            _unreadReceivedInvitationsCount = unreadReceived;
          });
        });
  }

  void _markNotificationsViewed() {
    if (_notificationsViewed) return;
    _notificationsViewed = true;
  }

  Future<void> _markSentInvitationsViewed() async {
    if (_sentInvitationsViewed) return;
    _sentInvitationsViewed = true;

    final user = _auth.getCurrentUser();
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('invitations')
        .where('inviterId', isEqualTo: user.uid)
        .where('status', whereIn: ['accepted', 'declined'])
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['viewedBySender'] == false) {
        batch.update(doc.reference, {'viewedBySender': true});
      }
    }
    await batch.commit();

    setState(() {
      _unreadSentInvitationsCount = 0;
    });
  }

  Future<void> _markReceivedInvitationsViewed() async {
    if (_receivedInvitationsViewed) return;
    _receivedInvitationsViewed = true;

    final user = _auth.getCurrentUser();
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('invitations')
        .where('inviteeId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['viewedByReceiver'] == false) {
        batch.update(doc.reference, {'viewedByReceiver': true});
      }
    }
    await batch.commit();

    setState(() {
      _unreadReceivedInvitationsCount = 0;
    });
  }

  Future<void> _onAlertTap(Alert alert) async {
    final user = _auth.getCurrentUser();
    if (user != null) {
      await _firestoreService.markAlertAsRead(user.uid, alert.id);
      setState(() {
        if (alert.type == 'invitation') {
          _unreadInvitationsCount = _unreadInvitationsCount > 0 ? _unreadInvitationsCount - 1 : 0;
        } else {
          _unreadNotificationsCount = _unreadNotificationsCount > 0 ? _unreadNotificationsCount - 1 : 0;
        }
      });
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
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading invitations: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white70),
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

            String statusText = 'Pending';
            Color statusColor = Colors.orange;
            IconData statusIcon = Icons.hourglass_empty;

            switch (status) {
              case 'accepted':
                statusText = 'Accepted';
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              case 'declined':
                statusText = 'Declined';
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
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading invitations: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white70),
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
                statusText = 'Accepted';
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              case 'declined':
                statusText = 'Declined';
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
          tabs: [
            // notifications tab
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications, size: 20),
                  const SizedBox(width: 8),
                  const Text('Notifications'),
                  if (_unreadNotificationsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // invitations tab
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mail, size: 20),
                  const SizedBox(width: 8),
                  const Text('Invitations'),
                  if (_unreadInvitationsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        _unreadInvitationsCount > 9 ? '9+' : '$_unreadInvitationsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            TextButton(
              onPressed: () async {
                await _firestoreService.markAllAlertsAsRead(user.uid);
                setState(() {
                  _unreadNotificationsCount = 0;
                });
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
                  // invitations tab with sub-tabs
                  Column(
                    children: [
                      Container(
                        color: const Color(0xFF1a0f2e),
                        child: TabBar(
                          controller: _invitationTabController,
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          onTap: (index) {
                            if (index == 0) {
                              _markSentInvitationsViewed();
                            } else if (index == 1) {
                              _markReceivedInvitationsViewed();
                            }
                          },
                          tabs: [
                            // sent sub-tab
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.send, size: 18),
                                  const SizedBox(width: 6),
                                  const Text('Sent'),
                                  if (_unreadSentInvitationsCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.rectangle,
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                      child: Text(
                                        _unreadSentInvitationsCount > 9 ? '9+' : '$_unreadSentInvitationsCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // received sub-tab
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inbox, size: 18),
                                  const SizedBox(width: 6),
                                  const Text('Received'),
                                  if (_unreadReceivedInvitationsCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.rectangle,
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                      child: Text(
                                        _unreadReceivedInvitationsCount > 9 ? '9+' : '$_unreadReceivedInvitationsCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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