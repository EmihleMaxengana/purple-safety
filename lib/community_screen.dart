import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'models/incident_model.dart';
import 'services/incident_service.dart';
import 'incidents/incident_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final IncidentService _incidentService = IncidentService();
  String _selectedFilter = 'all';
  
  final Map<String, String> _filterLabels = {
    'all': 'All',
    'missingPerson': 'Missing',
    'harassment': 'Harassment',
    'crime': 'Crime',
    'accident': 'Accident',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Community Reports'),
          backgroundColor: const Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _filterLabels.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: _selectedFilter == entry.key,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = entry.key;
                        });
                      },
                      backgroundColor: Colors.white.withOpacity(0.1),
                      selectedColor: const Color(0xFF6A1B9A),
                      labelStyle: TextStyle(
                        color: _selectedFilter == entry.key ? Colors.white : Colors.white70,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Incident>>(
                stream: _selectedFilter == 'all'
                    ? _incidentService.getAllIncidents()
                    : _incidentService.getIncidentsByType(
                        IncidentType.values.firstWhere(
                          (e) => e.toString() == 'IncidentType.$_selectedFilter',
                          orElse: () => IncidentType.other,
                        ),
                      ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.report, size: 64, color: Colors.white38),
                          SizedBox(height: 16),
                          Text(
                            'No reports yet',
                            style: TextStyle(color: Colors.white70),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap the + button to report an incident',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final incidents = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: incidents.length,
                    itemBuilder: (context, index) {
                      final incident = incidents[index];
                      return _buildIncidentCard(incident);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard(Incident incident) {
    Color typeColor = _getTypeColor(incident.type);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1a0f2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IncidentDetailScreen(incident: incident),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: typeColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      _getTypeLabel(incident.type),
                      style: TextStyle(color: typeColor, fontSize: 10),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(incident.timestamp),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Text(
                incident.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              
              Text(
                incident.description.length > 100
                    ? '${incident.description.substring(0, 100)}...'
                    : incident.description,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              
              if (incident.type == IncidentType.missingPerson && incident.missingPersonName != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_search, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'MISSING: ${incident.missingPersonName}',
                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white54, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      incident.location,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white54, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    incident.isAnonymous ? 'Anonymous' : (incident.userName ?? 'User'),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.comment,
                    label: '${incident.commentCount}',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IncidentDetailScreen(incident: incident),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.share,
                    label: '${incident.shareCount}',
                    onTap: () => _shareIncident(incident),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFBF7DCB), size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(IncidentType type) {
    switch (type) {
      case IncidentType.missingPerson:
        return Colors.orange;
      case IncidentType.harassment:
        return Colors.purple;
      case IncidentType.crime:
        return Colors.red;
      case IncidentType.accident:
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(IncidentType type) {
    switch (type) {
      case IncidentType.missingPerson:
        return 'Missing Person';
      case IncidentType.harassment:
        return 'Harassment';
      case IncidentType.crime:
        return 'Crime';
      case IncidentType.accident:
        return 'Accident';
      default:
        return 'Other';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _shareIncident(Incident incident) async {
    final message = '''
🚨 ${incident.title}

${incident.description}

📍 Location: ${incident.location}
📅 Reported: ${_formatTime(incident.timestamp)}
👤 Reported by: ${incident.isAnonymous ? 'Anonymous' : incident.userName ?? 'User'}

${incident.type == IncidentType.missingPerson ? '🔍 MISSING PERSON: ${incident.missingPersonName}\nAge: ${incident.missingPersonAge}\nLast seen: ${incident.lastSeenLocation}\n' : ''}
Please share to help spread awareness.
''';
    
    await Share.share(message);
    await _incidentService.shareIncident(incident.id);
    
    setState(() {});
  }
}