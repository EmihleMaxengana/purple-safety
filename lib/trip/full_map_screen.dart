import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purple_safety/trip/trip_sharing_service.dart';
import 'package:purple_safety/models/incident_model.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';

class FullMapScreen extends StatefulWidget {
  final String? initialTripId;
  final Set<Polygon>? dangerZones;

  const FullMapScreen({Key? key, this.initialTripId, this.dangerZones})
    : super(key: key);

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(-30.5595, 22.9375);
  Set<Marker> _tripMarkers = {};
  Set<Polyline> _tripPaths = {};
  Set<Marker> _sosMarkers = {};
  Set<Polygon> _dangerZones = {};

  // Multi‑trip tracking
  List<String> _followedTripIds = [];
  Map<String, StreamSubscription> _tripSubscriptions = {};
  Map<String, Map<String, dynamic>> _tripsData = {};
  Map<String, Color> _tripColors = {};
  bool _isLoading = false;
  bool _panelExpanded = false;

  // Pop-up message
  String? _popupMessage;
  Color? _popupColor;
  Timer? _popupTimer;

  // Predefined colours for multiple trips
  final List<Color> _colorPalette = [
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.pink,
    Colors.yellow.shade700,
    Colors.indigo,
    Colors.teal,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _listenToSOSEvents();
    _loadFollowedTrips();
    _loadDangerZones();
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
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
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

  void _loadDangerZones() {
    if (widget.dangerZones != null) {
      _dangerZones = widget.dangerZones!;
    }
  }

  Future<void> _loadFollowedTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList('followedTrips');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _followedTripIds = saved;
        _isLoading = true;
      });
      for (var tripId in saved) {
        _listenToSpecificTrip(tripId);
      }
    }
    if (widget.initialTripId != null &&
        !_followedTripIds.contains(widget.initialTripId)) {
      _addFollowedTrip(widget.initialTripId!);
    }
    setState(() {});
  }

  Future<void> _saveFollowedTrips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('followedTrips', _followedTripIds);
  }

  void _addFollowedTrip(String tripId) {
    if (_followedTripIds.contains(tripId)) {
      return;
    }
    setState(() {
      _followedTripIds.add(tripId);
      _isLoading = true;
    });
    _saveFollowedTrips();
    _listenToSpecificTrip(tripId);
  }

  void _removeFollowedTrip(String tripId, {bool showNotification = true}) {
    if (!_followedTripIds.contains(tripId)) return;

    _tripSubscriptions[tripId]?.cancel();
    _tripSubscriptions.remove(tripId);
    _tripsData.remove(tripId);
    _tripColors.remove(tripId);

    setState(() {
      _followedTripIds.remove(tripId);
      _updateMarkersAndPolylines();
    });
    _saveFollowedTrips();

    if (showNotification) {
      // Silent removal – no pop-up
    }
  }

  void _listenToSpecificTrip(String tripId) {
    _tripSubscriptions[tripId]?.cancel();

    bool _notifiedStart = false;
    bool _notifiedEnd = false;

    _tripSubscriptions[tripId] = TripSharingService.getTrip(tripId).listen((
      snapshot,
    ) {
      if (!mounted) return;
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'unknown';

        if (status == 'active') {
          final tripData = {
            'tripId': tripId,
            'userId': data['userId'],
            'userName': data['userName'] ?? 'Someone',
            'latitude': data['currentLatitude'],
            'longitude': data['currentLongitude'],
            'lastUpdate': data['lastUpdate'],
            'locationHistory': data['locationHistory'] ?? [],
            'status': status,
          };
          setState(() {
            _tripsData[tripId] = tripData;
            if (!_tripColors.containsKey(tripId)) {
              final index = _followedTripIds.indexOf(tripId);
              _tripColors[tripId] = _colorPalette[index % _colorPalette.length];
            }
            _updateMarkersAndPolylines();
          });
          // Show pop-up ONCE when person starts sharing
          if (!_notifiedStart) {
            _notifiedStart = true;
            _notifiedEnd = false;
            final userName = data['userName'] ?? 'Someone';
            _showPopupMessage(
              '$userName is now sharing their trip!',
              Colors.green,
            );
          }
        } else if (status == 'ended' || status == 'expired') {
          final userName = data['userName'] ?? 'Someone';
          // Show pop-up ONCE when person stops sharing
          if (!_notifiedEnd) {
            _notifiedEnd = true;
            _notifiedStart = false;
            _showPopupMessage(
              '$userName has stopped sharing their trip.',
              Colors.orange,
            );
          }
          _removeFollowedTrip(tripId, showNotification: false);
        }
      } else {
        _removeFollowedTrip(tripId, showNotification: false);
      }
    });
  }

  void _updateMarkersAndPolylines() {
    Set<Marker> newMarkers = {};
    Set<Polyline> newPolylines = {};

    for (var entry in _tripsData.entries) {
      final tripId = entry.key;
      final data = entry.value;
      final userName = data['userName'] ?? 'Someone';
      final latitude = data['latitude'] as double;
      final longitude = data['longitude'] as double;
      final lastUpdate = data['lastUpdate'] as Timestamp?;
      final locationHistory = data['locationHistory'] as List? ?? [];
      final color = _tripColors[tripId] ?? Colors.green;

      double hue = BitmapDescriptor.hueGreen;
      if (lastUpdate != null) {
        final minutesAgo = DateTime.now()
            .difference(lastUpdate.toDate())
            .inMinutes;
        if (minutesAgo > 5) {
          hue = BitmapDescriptor.hueRed;
        } else if (minutesAgo > 1) {
          hue = BitmapDescriptor.hueOrange;
        }
      }

      final marker = Marker(
        markerId: MarkerId(tripId),
        position: LatLng(latitude, longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(title: userName, snippet: 'Following this trip'),
        onTap: () => _zoomToTrip(tripId),
      );
      newMarkers.add(marker);

      if (locationHistory.isNotEmpty) {
        List<LatLng> points = [];
        for (var point in locationHistory) {
          points.add(LatLng(point['latitude'], point['longitude']));
        }
        if (points.length > 1) {
          final polyline = Polyline(
            polylineId: PolylineId('${tripId}_path'),
            points: points,
            color: color.withOpacity(0.7),
            width: 4,
            geodesic: true,
          );
          newPolylines.add(polyline);
        }
      }
    }

    setState(() {
      _tripMarkers = newMarkers;
      _tripPaths = newPolylines;
      _isLoading = false;
    });
  }

  void _zoomToTrip(String tripId) {
    final data = _tripsData[tripId];
    if (data != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(data['latitude'], data['longitude']),
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
      _addFollowedTrip(result);
    }
  }

  // ============================================================
  // POP-UP MESSAGE
  // ============================================================
  void _showPopupMessage(String message, Color color) {
    setState(() {
      _popupMessage = message;
      _popupColor = color;
    });

    _popupTimer?.cancel();
    _popupTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _popupMessage = null;
          _popupColor = null;
        });
      }
    });
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
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: _enterTripIdManually,
            tooltip: 'Enter Trip ID',
          ),
        ],
      ),
      body: Stack(
        children: [
          // GoogleMap(
          //   initialCameraPosition: CameraPosition(
          //     target: _initialPosition,
          //     zoom: 5.0,
          //   ),
          //   onMapCreated: (controller) => _mapController = controller,
          //   myLocationEnabled: true,
          //   myLocationButtonEnabled: true,
          //   zoomControlsEnabled: true,
          //   markers: {..._tripMarkers, ..._sosMarkers},
          //   polylines: _tripPaths,
          //   polygons: _dangerZones,
          // ),
          MapWidget(
            currentPosition: _initialPosition,
            onMapCreate: (controller) => _mapController = controller,
            myLocation: true,
            myLocationButton: true,
            zoomControls: true,
            markers: {..._tripMarkers, ..._sosMarkers},
            polylines: _tripPaths,
            polygons: _dangerZones,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            ),
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(30),
                color: Colors.black.withOpacity(0.85),
                child: InkWell(
                  onTap: () => setState(() => _panelExpanded = !_panelExpanded),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_alt,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_tripsData.length} following',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _panelExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_panelExpanded)
            Positioned(
              bottom: 50,
              left: 10,
              right: 10,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people_alt,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Following (${_tripsData.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _panelExpanded = false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Expanded(
                      child: _tripsData.isEmpty
                          ? const Center(
                              child: Text(
                                'No trips followed. Tap QR icon to follow.',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              itemCount: _tripsData.length,
                              itemBuilder: (context, index) {
                                final tripId = _tripsData.keys.elementAt(index);
                                final data = _tripsData[tripId]!;
                                final color =
                                    _tripColors[tripId] ?? Colors.grey;
                                final lastUpdate =
                                    data['lastUpdate'] as Timestamp?;
                                String statusText = 'Active now';
                                if (lastUpdate != null) {
                                  final minutesAgo = DateTime.now()
                                      .difference(lastUpdate.toDate())
                                      .inMinutes;
                                  if (minutesAgo > 5) {
                                    statusText =
                                        'Offline ($minutesAgo min ago)';
                                  } else if (minutesAgo > 1) {
                                    statusText = '$minutesAgo min ago';
                                  }
                                }
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: color,
                                    radius: 14,
                                    child: Text(
                                      data['userName'][0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    data['userName'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    statusText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        _removeFollowedTrip(tripId),
                                  ),
                                  onTap: () => _zoomToTrip(tripId),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          if (_popupMessage != null)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: _popupColor ?? Colors.grey,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _popupMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _popupTimer?.cancel();
                          setState(() {
                            _popupMessage = null;
                            _popupColor = null;
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var sub in _tripSubscriptions.values) {
      sub.cancel();
    }
    _mapController?.dispose();
    _popupTimer?.cancel();
    super.dispose();
  }
}
