import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/services/trip_sharing_service.dart';

class FullMapScreen extends StatefulWidget {
  final String? initialTripId;
  
  const FullMapScreen({Key? key, this.initialTripId}) : super(key: key);

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(-30.5595, 22.9375);
  Set<Marker> _tripMarkers = {};
  Set<Polyline> _tripPaths = {};
  Set<Marker> _sosMarkers = {};
  Map<String, dynamic>? _followedTrip;
  bool _isLoading = true;
  String? _followedTripId;
  StreamSubscription? _tripSubscription;

  @override
  void initState() {
    super.initState();
    _listenToSOSEvents();
    
    if (widget.initialTripId != null) {
      _followTripId(widget.initialTripId!);
    }
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToSOSEvents() {
    FirebaseFirestore.instance
        .collection('active_sos_events')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      final sosMarkers = <Marker>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final marker = Marker(
          markerId: MarkerId('sos_${doc.id}'),
          position: LatLng(data['latitude'], data['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'SOS EMERGENCY',
            snippet: '${data['userName']} needs immediate help!',
          ),
        );
        sosMarkers.add(marker);
      }
      setState(() {
        _sosMarkers = sosMarkers;
      });
    });
  }

  void _listenToSpecificTrip(String tripId) {
    _tripSubscription?.cancel();
    
    _tripSubscription = TripSharingService.getTrip(tripId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'active') {
          setState(() {
            _followedTrip = {
              'tripId': snapshot.id,
              'userId': data['userId'],
              'userName': data['userName'],
              'latitude': data['currentLatitude'],
              'longitude': data['currentLongitude'],
              'lastUpdate': data['lastUpdate'],
              'locationHistory': data['locationHistory'] ?? [],
            };
            _isLoading = false;
            _updateTripMarkerAndPath();
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Now following ${data['userName']}\'s trip'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() {
            _followedTrip = null;
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('The trip has ended'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        setState(() {
          _followedTrip = null;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid trip ID or trip has expired'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void _followTripId(String tripId) {
    setState(() {
      _followedTripId = tripId;
      _followedTrip = null;
      _tripMarkers = {};
      _tripPaths = {};
      _isLoading = true;
    });
    _listenToSpecificTrip(tripId);
  }

  void _updateTripMarkerAndPath() {
    if (_followedTrip == null) return;

    Set<Marker> newMarkers = {};
    Set<Polyline> newPaths = {};

    final latitude = _followedTrip!['latitude'] as double;
    final longitude = _followedTrip!['longitude'] as double;
    final userName = _followedTrip!['userName'] ?? 'Someone';
    final lastUpdate = _followedTrip!['lastUpdate'] as Timestamp?;
    final locationHistory = _followedTrip!['locationHistory'] as List? ?? [];

    String statusText = 'Active now';
    Color markerColor = Colors.green;
    
    if (lastUpdate != null) {
      final minutesAgo = DateTime.now().difference(lastUpdate.toDate()).inMinutes;
      if (minutesAgo > 5) {
        statusText = 'Offline - $minutesAgo min ago';
        markerColor = Colors.red;
      } else if (minutesAgo > 1) {
        statusText = '$minutesAgo min ago';
        markerColor = Colors.orange;
      }
    }

    double hue = BitmapDescriptor.hueGreen;
    if (markerColor == Colors.red) {
      hue = BitmapDescriptor.hueRed;
    } else if (markerColor == Colors.orange) {
      hue = BitmapDescriptor.hueOrange;
    }
    
    final marker = Marker(
      markerId: const MarkerId('followed_trip'),
      position: LatLng(latitude, longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(
        title: userName,
        snippet: 'Status: $statusText',
      ),
      onTap: () => _zoomToCurrentLocation(),
    );
    newMarkers.add(marker);

    if (locationHistory.isNotEmpty) {
      List<LatLng> pathPoints = [];
      for (var point in locationHistory) {
        pathPoints.add(LatLng(point['latitude'], point['longitude']));
      }
      
      if (pathPoints.length > 1) {
        final polyline = Polyline(
          polylineId: const PolylineId('followed_trip_path'),
          points: pathPoints,
          color: Colors.purple.withOpacity(0.7),
          width: 3,
          geodesic: true,
        );
        newPaths.add(polyline);
      }
    }

    setState(() {
      _tripMarkers = newMarkers;
      _tripPaths = newPaths;
    });

    _zoomToCurrentLocation();
  }

  void _zoomToCurrentLocation() {
    if (_mapController != null && _followedTrip != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _followedTrip!['latitude'],
              _followedTrip!['longitude'],
            ),
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _enterTripIdManually() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Trip ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste Trip ID here',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            child: const Text('Follow'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      _followTripId(result);
    }
  }

  void _clearFollowedTrip() {
    setState(() {
      _followedTrip = null;
      _followedTripId = null;
      _tripMarkers = {};
      _tripPaths = {};
    });
    _tripSubscription?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stopped following trip'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          if (_sosMarkers.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sos, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_sosMarkers.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (_followedTrip != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Following',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: _enterTripIdManually,
            tooltip: 'Enter Trip ID',
          ),
          if (_followedTrip != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _clearFollowedTrip,
              tooltip: 'Stop following',
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 5.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            markers: {
              ..._tripMarkers,
              ..._sosMarkers,
            },
            polylines: _tripPaths,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            ),
          if (_sosMarkers.isEmpty && _followedTrip == null && !_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 64, color: Colors.white38),
                  SizedBox(height: 16),
                  Text(
                    'No active locations',
                    style: TextStyle(color: Colors.white70),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'SOS alerts appear here for everyone\nTap QR icon to follow a shared trip',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (_followedTrip != null && !_isLoading)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Following ${_followedTrip!['userName']}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _zoomToCurrentLocation,
                      child: const Text(
                        'CENTER',
                        style: TextStyle(color: Colors.purple, fontSize: 10),
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
}