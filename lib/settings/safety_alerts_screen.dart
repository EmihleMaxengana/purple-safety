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

  int _unreadNotificationsCount = 0;
  int _unreadInvitationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCounts();
  }

  @override
  void dispose() {
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

    final currentUserId = _auth.getCurrentUser()?.uid;

    //(handle deactivated SOS notifications - sos_deactivated and safe)
    if ((alert.type == 'sos_deactivated' || alert.type == 'safe') && alert.sosEventId != null) {
      try {
        final eventDoc = await FirebaseFirestore.instance
            .collection('active_sos_events')
            .doc(alert.sosEventId)
            .get();
        
        if (eventDoc.exists) {
          final data = eventDoc.data()!;
          
          //(if current user is the trigger user, do absolutely nothing)
          if (currentUserId == data['userId']) {
            return;
          }
          
          Navigator.pop(context, {
            'showDeactivationModal': true,
            'sosEventId': alert.sosEventId,
          });
        } else {
          //(event doesn't exist, just pop back)
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error fetching deactivated SOS data: $e');
        Navigator.pop(context);
      }
      return;
    }

    //(handle active SOS notifications)
    if (alert.type == 'sos' && alert.sosEventId != null) {
      final isActive = await _isSOSActive(alert.sosEventId!);
      
      if (isActive) {
        Navigator.pop(context, 'sos');
        return;
      }
      
      //(if SOS is no longer active, treat it as deactivated)
      try {
        final eventDoc = await FirebaseFirestore.instance
            .collection('active_sos_events')
            .doc(alert.sosEventId)
            .get();
        
        if (eventDoc.exists) {
          final data = eventDoc.data()!;
          
          if (currentUserId == data['userId']) {
            return;
          }
          
          Navigator.pop(context, {
            'showDeactivationModal': true,
            'sosEventId': alert.sosEventId,
          });
        } else {
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error fetching deactivated SOS data: $e');
        Navigator.pop(context);
      }
      return;
    }

    //(handle incident notifications)
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

    //(handle invitation notifications - mark invitation as read when tapped)
    if (alert.type == 'invitation' && alert.invitationId != null) {
      //(invitation is already marked read above, just refresh)
      setState(() {});
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
          return const SizedBox();
        }

        if (snapshot.hasError) {
          return const SizedBox();
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox();
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

        return Column(
          children: sortedDocs.map((doc) {
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

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status == 'pending'
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status == 'pending'
                      ? Colors.orange.withOpacity(0.3)
                      : statusColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.2),
                        radius: 16,
                        child: Text(
                          inviterName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invitation from $inviterName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              inviterEmail,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 44),
                      child: Text(
                        'Received ${_formatTime(createdAt.toDate())}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  if (isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final success = await InvitationService.declineInvitation(invitationId);
                              if (success && mounted) {
                                _showPopup(context, 'Invitation declined');
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                                _showPopup(context, 'You are now $inviterName\'s trusted contact!');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
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
          return const SizedBox();
        }

        if (snapshot.hasError) {
          return const SizedBox();
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox();
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

        return Column(
          children: sortedDocs.map((doc) {
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

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status == 'pending'
                    ? Colors.orange.withOpacity(0.05)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status == 'pending'
                      ? Colors.orange.withOpacity(0.2)
                      : statusColor.withOpacity(0.15),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    radius: 16,
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invitation sent to $inviteeEmail',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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
                      size: 18,
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showPopup(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Info'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
                  'Alerts and invitations will appear here',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final allAlerts = snapshot.data!;
        final notifications = allAlerts.where((a) => a.type != 'invitation').toList();
        final invitationAlerts = allAlerts.where((a) => a.type == 'invitation').toList();

        //(sort all items by timestamp descending)
        final allItems = <Map<String, dynamic>>[];
        
        for (var alert in notifications) {
          allItems.add({
            'type': 'alert',
            'data': alert,
            'timestamp': alert.timestamp,
          });
        }

        for (var alert in invitationAlerts) {
          allItems.add({
            'type': 'invitation_alert',
            'data': alert,
            'timestamp': alert.timestamp,
          });
        }

        allItems.sort((a, b) {
          return b['timestamp'].compareTo(a['timestamp']);
        });

        if (allItems.isEmpty) {
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
                  'Alerts and invitations will appear here',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allItems.length,
          itemBuilder: (context, index) {
            final item = allItems[index];
            
            if (item['type'] == 'invitation_alert') {
              final alert = item['data'] as Alert;
              return _buildInvitationAlert(alert);
            } else {
              final alert = item['data'] as Alert;
              return _buildNotificationAlert(alert);
            }
          },
        );
      },
    );
  }

  Widget _buildInvitationAlert(Alert alert) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('invitations')
          .doc(alert.invitationId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
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
        final isReceived = data['inviteeId'] == _auth.getCurrentUser()?.uid;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: alert.read
                ? Colors.white.withOpacity(0.05)
                : statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: alert.read
                  ? Colors.white.withOpacity(0.1)
                  : statusColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isReceived
                              ? 'Invitation from $inviterName'
                              : 'Invitation to $inviterEmail',
                          style: TextStyle(
                            color: alert.read ? Colors.white70 : Colors.white,
                            fontSize: 14,
                            fontWeight: alert.read ? FontWeight.normal : FontWeight.w500,
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
                  if (!alert.read)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              if (isPending && isReceived) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final success = await InvitationService.declineInvitation(alert.invitationId!);
                          if (success && mounted) {
                            _showPopup(context, 'Invitation declined');
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final success = await InvitationService.acceptInvitation(alert.invitationId!);
                          if (success && mounted) {
                            _showPopup(context, 'You are now $inviterName\'s trusted contact!');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationAlert(Alert alert) {
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
    } else if (alert.type == 'sos_deactivated') {
      color = Colors.orange;
      icon = Icons.check_circle;
    } else if (alert.type == 'safe') {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (alert.type == 'location_share') {
      color = Colors.blue;
      icon = Icons.location_on;
    } else if (alert.type == 'found') {
      color = Colors.green;
      icon = Icons.check_circle;
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
            if (alert.type == 'incident' || alert.type == 'sos' || alert.type == 'sos_deactivated' || alert.type == 'safe')
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white38,
                size: 14,
              ),
          ],
        ),
      ),
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

    final totalUnread = _unreadNotificationsCount + _unreadInvitationsCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Alerts'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () async {
              await _firestoreService.markAllAlertsAsRead(user.uid);
              setState(() {
                _unreadNotificationsCount = 0;
                _unreadInvitationsCount = 0;
              });
              _showPopup(context, 'All notifications marked as read');
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
            if (totalUnread > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.red.withOpacity(0.15),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalUnread unread item${totalUnread > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildNotifications(),
            ),
          ],
        ),
      ),
    );
  }
}