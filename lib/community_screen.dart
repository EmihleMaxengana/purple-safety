import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:purple_safety/services/sos_event_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _messageController = TextEditingController();
  GoogleMapController? _mapController;
  bool _isLoading = false;

  // Data
  DocumentSnapshot? _activeSOS;
  List<QueryDocumentSnapshot> _activeMembers = [];
  List<dynamic> _policeStations = [];
  List<Map<String, dynamic>> _chatMessages = [];

  // Markers
  final Set<Marker> _markers = {};

  // Google Places API key – replace with your own
  static const String _placesApiKey = 'AIzaSyBKIeas0psJ9fDlQD18EXW9mtKSBKIi78k';

  @override
  void initState() {
    super.initState();
    _listenToSOS();
  }

  void _listenToSOS() {
    SOSEventService.getActiveSOS().listen((sos) {
      setState(() {
        _activeSOS = sos;
        if (sos != null) {
          _loadPoliceStations(sos);
          _listenToActiveMembers();
          _listenToChat(sos.id);
        } else {
          _activeMembers = [];
          _policeStations = [];
          _chatMessages = [];
          _markers.clear();
        }
      });
    });
  }

  void _listenToActiveMembers() {
    SOSEventService.getActiveMembers().listen((members) {
      setState(() {
        _activeMembers = members;
        _updateMarkers();
      });
    });
  }

  void _listenToChat(String sosEventId) {
    SOSEventService.getChatMessages(sosEventId).listen((messages) {
      setState(() {
        _chatMessages = messages;
      });
    });
  }

  Future<void> _loadPoliceStations(DocumentSnapshot sos) async {
    final data = sos.data() as Map<String, dynamic>;
    final location = data['location'] as GeoPoint;
    final lat = location.latitude;
    final lng = location.longitude;

    final results = await SOSEventService.fetchNearbyPoliceStations(
      lat,
      lng,
      _placesApiKey,
    );
    setState(() {
      _policeStations = results;
      _updateMarkers();
    });
  }

  void _updateMarkers() {
    if (_activeSOS == null) return;

    final markers = <Marker>{};

    // SOS user (purple)
    final sosData = _activeSOS!.data() as Map<String, dynamic>;
    final sosLoc = sosData['location'] as GeoPoint;
    markers.add(
      Marker(
        markerId: const MarkerId('sos_user'),
        position: LatLng(sosLoc.latitude, sosLoc.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(title: 'SOS Triggered'),
      ),
    );

    // Active members (green)
    for (var member in _activeMembers) {
      final memberData = member.data() as Map<String, dynamic>;
      final loc = memberData['currentLocation'] as GeoPoint?;
      if (loc != null) {
        markers.add(
          Marker(
            markerId: MarkerId(member.id),
            position: LatLng(loc.latitude, loc.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: memberData['name'] ?? 'Active Member',
            ),
          ),
        );
      }
    }

    // Police stations (blue)
    for (var station in _policeStations) {
      final loc = station['geometry']['location'];
      final name = station['name'];
      markers.add(
        Marker(
          markerId: MarkerId(name),
          position: LatLng(loc['lat'], loc['lng']),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: name),
        ),
      );
    }

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

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
      child: _activeSOS == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public, color: Colors.white70, size: 80),
                  SizedBox(height: 20),
                  Text(
                    'No active SOS',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  Text(
                    'When an SOS is triggered, you can see the location and chat here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    onMapCreated: (ctrl) => _mapController = ctrl,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        (_activeSOS!.data() as Map<String, dynamic>)['location']
                            .latitude,
                        (_activeSOS!.data() as Map<String, dynamic>)['location']
                            .longitude,
                      ),
                      zoom: 13,
                    ),
                    markers: _markers,
                    myLocationEnabled: true,
                    zoomControlsEnabled: true,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.black54,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            reverse: true,
                            itemCount: _chatMessages.length,
                            itemBuilder: (context, index) {
                              final msg = _chatMessages[index];
                              return ListTile(
                                title: Text(
                                  msg['userName'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  msg['message'],
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: Text(
                                  _formatTime(msg['timestamp']),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1a0f2e),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Write a comment...',
                                    hintStyle: const TextStyle(
                                      color: Colors.white38,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.send,
                                  color: Colors.white70,
                                ),
                                onPressed: _sendMessage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final msg = _messageController.text.trim();
    await SOSEventService.sendMessage(_activeSOS!.id, msg);
    _messageController.clear();
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final DateTime time = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
