import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/incident_model.dart';
import 'services/incident_service.dart';
import 'services/sos_alert_service.dart';
import 'incidents/incident_detail_screen.dart';
import 'incidents/post_choice_modal.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final IncidentService _incidentService = IncidentService();
  String _selectedView = 'map'; // Default to map view
  
  // Map related
  GoogleMapController? _mapController;
  Set<Marker> _sosMarkers = {};
  Set<Marker> _incidentMarkers = {};
  bool _isMapReady = false;
  
  // Active SOS events list (for list view)
  List<Map<String, dynamic>> _activeSOSEvents = [];
  bool _isLoadingSOS = true;
  
  // Current user location (center of South Africa as fallback)
  static const LatLng _saCenter = LatLng(-28.4795, 24.6728);

  @override
  void initState() {
    super.initState();
    _listenToActiveSOS();
    _loadIncidentsAsMarkers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ============================================================
  // LISTEN TO ACTIVE SOS EVENTS FROM FIRESTORE
  // ============================================================
  void _listenToActiveSOS() {
    FirebaseFirestore.instance
        .collection('active_sos_events')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _isLoadingSOS = false;
        _activeSOSEvents = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'userId': data['userId'],
            'userName': data['userName'] ?? 'Someone',
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'locationLink': data['locationLink'],
            'timestamp': data['timestamp'],
            'responderCount': data['responderCount'] ?? 0,
          };
        }).toList();
        
        _updateSOSMarkers();
      });
    });
  }
  
  void _updateSOSMarkers() {
    setState(() {
      _sosMarkers = {};
      
      for (var event in _activeSOSEvents) {
        final markerId = MarkerId(event['id']);
        final marker = Marker(
          markerId: markerId,
          position: LatLng(event['latitude'], event['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '🚨 SOS ACTIVE!',
            snippet: '${event['userName']} needs immediate help!\nTap to respond',
          ),
          onTap: () => _showSOSResponderModal(event),
        );
        _sosMarkers.add(marker);
      }
      
      debugPrint('📍 Updated SOS markers: ${_sosMarkers.length} active SOS events');
    });
  }

  // ============================================================
  // LOAD INCIDENTS AS MARKERS ON MAP
  // ============================================================
  void _loadIncidentsAsMarkers() {
    _incidentService.getAllIncidents().listen((incidents) {
      setState(() {
        _incidentMarkers = {};
        
        for (var incident in incidents) {
          // Only add markers if incident has coordinates
          if (incident.latitude != null && incident.longitude != null) {
            final markerId = MarkerId(incident.id);
            Color markerColor = _getTypeColor(incident.type);
            
            final marker = Marker(
              markerId: markerId,
              position: LatLng(incident.latitude!, incident.longitude!),
              icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(incident.type)),
              infoWindow: InfoWindow(
                title: incident.title,
                snippet: '${incident.type.toString().split('.').last}\nTap for details',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IncidentDetailScreen(incident: incident),
                  ),
                );
              },
            );
            _incidentMarkers.add(marker);
          }
        }
      });
    });
  }

  double _getMarkerHue(IncidentType type) {
    switch (type) {
      case IncidentType.missingPerson:
        return BitmapDescriptor.hueOrange;
      case IncidentType.harassment:
        return BitmapDescriptor.hueViolet;
      case IncidentType.crime:
        return BitmapDescriptor.hueRed;
      case IncidentType.accident:
        return BitmapDescriptor.hueYellow;
      default:
        return BitmapDescriptor.hueAzure;
    }
  }

  // ============================================================
  // SHOW SOS RESPONDER MODAL
  // ============================================================
  void _showSOSResponderModal(Map<String, dynamic> sosEvent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1a0f2e),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.red.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 12),
            const Text(
              '🚨 ACTIVE SOS EMERGENCY 🚨',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${sosEvent['userName']} needs immediate help!',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${sosEvent['responderCount']} people are on their way to help',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _respondToSOS(sosEvent);
                      _openNavigationToSOS(sosEvent);
                    },
                    icon: const Icon(Icons.directions_run),
                    label: const Text('I Can Help!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _respondToSOS(Map<String, dynamic> sosEvent) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String responderName = 'A helper';
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        responderName = userDoc.data()?['name'] ?? 'A helper';
      }
      
      await SOSAlertService.respondToSOS(
        sosEventId: sosEvent['id'],
        responderId: user?.uid ?? 'anonymous',
        responderName: responderName,
        responderLatitude: 0,
        responderLongitude: 0,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for helping! Navigation starting...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error responding to SOS: $e');
    }
  }
  
  void _openNavigationToSOS(Map<String, dynamic> sosEvent) async {
    final url = 'https://www.google.com/maps/dir//${sosEvent['latitude']},${sosEvent['longitude']}';
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ============================================================
  // BUILD UI
  // ============================================================
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
          title: const Text('Community Safety'),
          backgroundColor: const Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
          actions: [
            // Active SOS count badge
            if (_activeSOSEvents.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sos, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${_activeSOSEvents.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            // Toggle view button
            IconButton(
              icon: Icon(_selectedView == 'list' ? Icons.map : Icons.list),
              onPressed: () {
                setState(() {
                  _selectedView = _selectedView == 'list' ? 'map' : 'list';
                });
              },
              tooltip: _selectedView == 'list' ? 'Switch to Map View' : 'Switch to List View',
            ),
          ],
        ),
        body: _selectedView == 'map' ? _buildMapView() : _buildListView(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (context) => const PostChoiceModal(),
            );
          },
          backgroundColor: const Color(0xFF6A1B9A),
          child: const Icon(Icons.add_alert, color: Colors.white),
        ),
      ),
    );
  }

  // ============================================================
  // MAP VIEW WITH SOS MARKERS
  // ============================================================
  Widget _buildMapView() {
    return Column(
      children: [
        // Status bar showing active SOS count
        if (_activeSOSEvents.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              border: Border(bottom: BorderSide(color: Colors.red.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_activeSOSEvents.length} active SOS ${_activeSOSEvents.length == 1 ? 'alert' : 'alerts'} nearby',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Icon(Icons.warning, color: Colors.red, size: 16),
              ],
            ),
          ),
        
        // Google Map
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  setState(() => _isMapReady = true);
                },
                initialCameraPosition: const CameraPosition(
                  target: _saCenter,
                  zoom: 5.0,
                ),
                markers: {
                  ..._sosMarkers,
                  ..._incidentMarkers,
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                compassEnabled: true,
              ),
              
              // Loading indicator
              if (_isLoadingSOS)
                const Center(
                  child: CircularProgressIndicator(color: Colors.purple),
                ),
              
              // Legend overlay
              Positioned(
                bottom: 80,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(Colors.red, 'Active SOS'),
                      const SizedBox(height: 4),
                      _buildLegendItem(Colors.purple, 'Incident Report'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  // ============================================================
  // LIST VIEW (Incidents list without filter chips)
  // ============================================================
  Widget _buildListView() {
    return Column(
      children: [
        // Active SOS banner
        if (_activeSOSEvents.isNotEmpty)
          GestureDetector(
            onTap: () {
              setState(() => _selectedView = 'map');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Switch to Map View to see active SOS locations'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                border: Border(bottom: BorderSide(color: Colors.red.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sos, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_activeSOSEvents.length} Active SOS ${_activeSOSEvents.length == 1 ? 'Alert' : 'Alerts'}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tap to view on map and help someone in need',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.white70),
                ],
              ),
            ),
          ),
        
        // All incidents list (no filters)
        Expanded(
          child: StreamBuilder<List<Incident>>(
            stream: _incidentService.getAllIncidents(),
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
    );
  }

  // ============================================================
  // INCIDENT CARD
  // ============================================================
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