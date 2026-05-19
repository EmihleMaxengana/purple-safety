import 'package:flutter/material.dart';
import 'package:purple_safety/services/auth_service.dart';
import 'package:purple_safety/services/firestore_service.dart';
import 'package:purple_safety/incidents/incident_detail_screen.dart';
import 'package:purple_safety/services/incident_service.dart';
import 'package:purple_safety/invitations/pending_invitations_screen.dart';

class SafetyAlertsScreen extends StatefulWidget {
  const SafetyAlertsScreen({Key? key}) : super(key: key);

  @override
  State<SafetyAlertsScreen> createState() => _SafetyAlertsScreenState();
}

class _SafetyAlertsScreenState extends State<SafetyAlertsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _auth = AuthService();
  final IncidentService _incidentService = IncidentService();

  Future<void> _onAlertTap(Alert alert) async {
    final user = _auth.getCurrentUser();
    if (user != null) {
      await _firestoreService.markAlertAsRead(user.uid, alert.id);
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
    } else if (alert.type == 'invitation' && alert.invitationId != null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PendingInvitationsScreen()),
        );
      }
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
        actions: [
          TextButton(
            onPressed: () async {
              await _firestoreService.markAllAlertsAsRead(user.uid);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All alerts marked as read')),
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
        child: StreamBuilder<List<Alert>>(
          stream: _firestoreService.getAlertsStream(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No alerts yet',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final alerts = snapshot.data!;
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
                } else if (alert.type == 'invitation') {
                  color = Colors.purple;
                  icon = Icons.person_add;
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
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
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
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
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
                        if (alert.type == 'incident' || alert.type == 'invitation')
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
}