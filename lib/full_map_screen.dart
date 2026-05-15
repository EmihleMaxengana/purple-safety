import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/services/trip_sharing_service.dart';

class FullMapScreen extends StatefulWidget {
  const FullMapScreen({Key? key}) : super(key: key);

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(-30.5595, 22.9375);
  Set<Marker> _tripMarkers = {};
  Set<Polyline> _tripPaths = {};
  List<Map<String, dynamic>> _activeTrips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToActiveTrips();
  }

  void _listenToActiveTrips() {
    TripSharingService.getActiveTrips().listen((trips) {
      setState(() {
        _activeTrips = trips;
        _isLoading = false;
        _updateMarkersAndPaths();
      });
    });
  }

  void _updateMarkersAndPaths() {
    Set<Marker> newMarkers = {};
    Set<Polyline> newPaths = {};

    for (var trip in _activeTrips) {
      final latitude = trip['latitude'] as double;
      final longitude = trip['longitude'] as double;
      final userName = trip['userName'] ?? 'Someone';
      final lastUpdate = trip['lastUpdate'] as Timestamp?;
      final locationHistory = trip['locationHistory'] as List? ?? [];

      // Calculate time since last update
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
        } else {
          statusText = 'Active now';
          markerColor = Colors.green;
        }
      }

      // Add marker
      double hue = BitmapDescriptor.hueGreen;
      if (markerColor == Colors.red) {
        hue = BitmapDescriptor.hueRed;
      } else if (markerColor == Colors.orange) {
        hue = BitmapDescriptor.hueOrange;
      }
      
      final marker = Marker(
        markerId: MarkerId(trip['tripId']),
        position: LatLng(latitude, longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: userName,
          snippet: 'Status: $statusText\nTap to see route',
        ),
      );
      newMarkers.add(marker);

      // Draw path trail from location history
      if (locationHistory.isNotEmpty) {
        List<LatLng> pathPoints = [];
        for (var point in locationHistory) {
          pathPoints.add(LatLng(point['latitude'], point['longitude']));
        }
        
        if (pathPoints.length > 1) {
          final polyline = Polyline(
            polylineId: PolylineId('path_${trip['tripId']}'),
            points: pathPoints,
            color: Colors.purple.withOpacity(0.7),
            width: 3,
            geodesic: true,
          );
          newPaths.add(polyline);
        }
      }
    }

    setState(() {
      _tripMarkers = newMarkers;
      _tripPaths = newPaths;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Trips Map'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          if (_activeTrips.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_activeTrips.length} active ${_activeTrips.length == 1 ? 'trip' : 'trips'}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
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
            markers: _tripMarkers,
            polylines: _tripPaths,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            ),
          if (_activeTrips.isEmpty && !_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_pin_circle, size: 64, color: Colors.white38),
                  SizedBox(height: 16),
                  Text(
                    'No active trips to display',
                    style: TextStyle(color: Colors.white70),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ask friends to share their trip with you',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}