import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';
import 'package:purple_safety/full_map_screen.dart';
import 'package:purple_safety/manage_contacts_modal.dart';
import 'package:purple_safety/add_contact_modal.dart';
import 'package:purple_safety/services/location_sharing_service.dart';
import 'package:purple_safety/services/auth_service.dart';
import 'package:purple_safety/services/firestore_service.dart';
import 'package:purple_safety/safety_alerts_screen.dart';

// Contact model with Firestore methods
class Contact {
  final String id;
  String name;
  String initials;
  Color color;
  bool active;
  String? phone;
  String? relationship;
  Map<String, String> socialLinks;

  Contact({
    required this.id,
    required this.name,
    required this.initials,
    required this.color,
    this.active = true,
    this.phone,
    this.relationship,
    this.socialLinks = const {},
  });

  factory Contact.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Contact(
      id: doc.id,
      name: data['name'],
      initials: data['initials'],
      color: Color(data['color']),
      active: data['active'],
      phone: data['phone'],
      relationship: data['relationship'],
      socialLinks: Map<String, String>.from(data['socialLinks'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'initials': initials,
      'color': color.value,
      'active': active,
      'phone': phone,
      'relationship': relationship,
      'socialLinks': socialLinks,
    };
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToEmergency;
  final VoidCallback? onNavigateToTools;

  const HomeScreen({
    Key? key,
    this.onNavigateToEmergency,
    this.onNavigateToTools,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // SOS state
  bool _isSosActive = false;
  int _sosCountdown = 0;
  Timer? _countdownTimer;
  Timer? _holdTimer;
  bool _isHolding = false;

  // Map state
  GoogleMapController? _mapController;
  location.Location _location = location.Location();
  bool _locationEnabled = false;
  bool _isLocationLoading = false;
  LatLng? _currentPosition;
  Set<Polygon> _dangerZones = {};
  StreamSubscription<location.LocationData>? _locationSubscription;

  // Contacts
  List<Contact> _contacts = [];
  bool _isSharingLocation = false;

  // Firestore
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _contactsSubscription;
  StreamSubscription? _alertsSubscription;
  int _unreadAlertsCount = 0;

  // Default map position (center of South Africa)
  static const LatLng _defaultPosition = LatLng(-30.5595, 22.9375);

  // Custom map style
  final String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1d2c3d"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8ec3b0"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1a3646"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b2e6b"
      },
      {
        "weight": 1.5
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#b9daa4"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8ec3b0"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2a5c4a"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#3c2b4f"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d4bfff"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#5a3e7a"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#f3d9ff"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#b9daa4"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2e5c8a"
      }
    ]
  }
]
  ''';

  @override
  void initState() {
    super.initState();
    _initLocation();
    _setupDangerZones();
    _listenToContacts();
    _listenToAlerts();
  }

  Future<void> _listenToContacts() async {
    final user = AuthService().getCurrentUser();
    if (user != null) {
      _contactsSubscription = _firestoreService
          .getContactsStream(user.uid)
          .listen((contacts) {
            setState(() {
              _contacts = contacts;
              EmergencyManager().setCurrentContacts(_contacts);
            });
          });
    } else {
      setState(() {
        _contacts = [];
      });
    }
  }

  void _listenToAlerts() async {
    final user = AuthService().getCurrentUser();
    if (user != null) {
      _alertsSubscription = _firestoreService.getAlertsStream(user.uid).listen((
        alerts,
      ) {
        setState(() {
          _unreadAlertsCount = alerts.where((a) => !a.read).length;
        });
      });
    }
  }

  Future<void> _initLocation() async {
    setState(() => _isLocationLoading = true);
    bool serviceEnabled;
    location.PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please enable location services to see your location.',
              ),
            ),
          );
        }
        setState(() {
          _locationEnabled = false;
          _isLocationLoading = false;
        });
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == location.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != location.PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required. Please grant it in settings.',
              ),
            ),
          );
        }
        setState(() {
          _locationEnabled = false;
          _isLocationLoading = false;
        });
        return;
      }
    }

    setState(() => _locationEnabled = true);

    _locationSubscription = _location.onLocationChanged.listen((event) {
      if (event.latitude != null && event.longitude != null) {
        setState(() {
          _currentPosition = LatLng(event.latitude!, event.longitude!);
          _isLocationLoading = false;
        });
      }
    });
  }

  void _setupDangerZones() {
    _dangerZones = {
      Polygon(
        polygonId: const PolygonId('johannesburg_zone'),
        points: const [
          LatLng(-26.1, 28.0),
          LatLng(-26.2, 28.1),
          LatLng(-26.3, 28.0),
          LatLng(-26.2, 27.9),
          LatLng(-26.1, 28.0),
        ],
        fillColor: Colors.purple.withOpacity(0.3),
        strokeColor: Colors.purple,
        strokeWidth: 2,
        geodesic: true,
      ),
    };
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController!.setMapStyle(_mapStyle);

    if (_currentPosition != null) {
      controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 5.5),
        ),
      );
    }
  }

  void _handleSOSPress() {
    setState(() => _isHolding = true);
    _holdTimer = Timer(const Duration(milliseconds: 800), () {
      _startSOSCountdown();
      setState(() => _isHolding = false);
    });
  }

  void _handleSOSRelease() {
    _holdTimer?.cancel();
    setState(() => _isHolding = false);
  }

  void _startSOSCountdown() {
    setState(() {
      _isSosActive = true;
      _sosCountdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _sosCountdown--);
      if (_sosCountdown == 0) {
        timer.cancel();
        _triggerSOS();
      }
    });
  }

  void _triggerSOS() {
    EmergencyManager().setCurrentContacts(_contacts);
    widget.onNavigateToTools?.call();
    setState(() => _isSosActive = false);
  }

  void _cancelSOS() {
    _countdownTimer?.cancel();
    setState(() {
      _isSosActive = false;
      _sosCountdown = 0;
    });
  }

  void _openFullMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FullMapScreen()),
    );
  }

  void _showAddContactModal() {
    final user = AuthService().getCurrentUser();
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AddContactModal(
        onAdd: (newContact) async {
          await _firestoreService.addContact(user.uid, newContact);
        },
        currentCount: _contacts.length,
      ),
    );
  }

  void _showManageContactsModal() {
    final user = AuthService().getCurrentUser();
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => ManageContactsModal(
        contacts: _contacts,
        onDelete: (id) async {
          await _firestoreService.deleteContact(user.uid, id);
        },
      ),
    );
  }

  (double?, double?) _getCoordinates() {
    return (_currentPosition?.latitude, _currentPosition?.longitude);
  }

  void _handleShareLocation() async {
    if (!_locationEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = AuthService().getCurrentUser();
    String userName = 'User';
    if (user != null) {
      final userData = await AuthService().getUserData(user.uid);
      userName = userData?['name'] ?? 'User';
    }

    if (_isSharingLocation) {
      LocationSharingService.stopSharing();
      setState(() => _isSharingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sharing stopped'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      LocationSharingService.startSharing(_contacts, userName, _getCoordinates);
      setState(() => _isSharingLocation = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sharing location with trusted contacts (every 15 min)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleCallEmergency() {
    if (widget.onNavigateToEmergency != null) {
      widget.onNavigateToEmergency!();
    } else {
      debugPrint('No navigation callback provided');
    }
  }

  @override
  void dispose() {
    LocationSharingService.stopSharing();
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    _contactsSubscription?.cancel();
    _alertsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SafetyAlertsScreen(),
                                ),
                              );
                            },
                          ),
                          if (_unreadAlertsCount > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SOS button
                  Center(
                    child: GestureDetector(
                      onTapDown: (_) => _handleSOSPress(),
                      onTapUp: (_) => _handleSOSRelease(),
                      onTapCancel: _handleSOSRelease,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFe060c0), Color(0xFF5c0070)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isHolding)
                              ...List.generate(
                                3,
                                (index) => TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 1.0, end: 1.7),
                                  duration: Duration(
                                    milliseconds: 1500 + index * 400,
                                  ),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Container(
                                      width: 140 * value,
                                      height: 140 * value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.red.withOpacity(
                                            0.5 * (1 - (value - 1) / 0.7),
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.sos, color: Colors.white, size: 28),
                                SizedBox(height: 4),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SectionHeader(
                    title: 'LIVE LOCATION',
                    action: 'Full Map →',
                    onActionTap: _openFullMap,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFa078c0).withOpacity(0.2),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildMapContent(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SectionHeader(title: 'QUICK ACTIONS'),
                  const SizedBox(height: 8),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3,
                    children: [
                      _buildQuickAction(
                        Icons.location_on,
                        _isSharingLocation ? 'Stop Sharing' : 'Share Location',
                        _isSharingLocation
                            ? Colors.red
                            : const Color(0xFF8260dc),
                        _handleShareLocation,
                      ),
                      _buildQuickAction(
                        Icons.phone,
                        'Call Emergency',
                        const Color(0xFFdc6080),
                        _handleCallEmergency,
                      ),
                      _buildQuickAction(
                        Icons.explore,
                        'Safe Route',
                        const Color(0xFF60dc80),
                        _openFullMap,
                      ),
                      _buildQuickAction(
                        Icons.warning,
                        'Report Incident',
                        const Color(0xFFdcb060),
                        () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SectionHeader(
                    title: 'TRUSTED CONTACTS',
                    action: 'Manage →',
                    onActionTap: _showManageContactsModal,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._contacts.map(
                          (c) => _buildContact(
                            c.initials,
                            c.name,
                            c.color,
                            c.active,
                          ),
                        ),
                        _buildAddContact(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SectionHeader(
                    title: 'SAFETY ALERTS',
                    action: 'All →',
                    onActionTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SafetyAlertsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Alert>>(
                    stream: _firestoreService.getAlertsStream(
                      AuthService().getCurrentUser()?.uid ?? '',
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No alerts yet',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      }
                      final alerts = snapshot.data!;
                      final recentAlerts = alerts.take(2).toList();
                      return Column(
                        children: recentAlerts.map((alert) {
                          Color color = alert.type == 'warning'
                              ? Colors.red
                              : Colors.blue;
                          return Container(
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
                                  child: Icon(
                                    alert.type == 'warning'
                                        ? Icons.warning
                                        : Icons.info,
                                    color: color,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    alert.message,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatTime(alert.timestamp),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        if (_isSosActive)
          Container(
            color: const Color(0xFF500032).withOpacity(0.97),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _sosCountdown > 0
                        ? 'Sending SOS in...'
                        : 'SOS Sent — Help is coming',
                    style: const TextStyle(
                      color: Color(0xFFf0a0d0),
                      fontSize: 16,
                    ),
                  ),
                  if (_sosCountdown > 0)
                    Text(
                      '$_sosCountdown',
                      style: const TextStyle(
                        color: Color(0xFFff60a0),
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _sosCountdown > 0
                        ? 'Alerting trusted contacts & emergency services'
                        : 'Your trusted contacts have been notified',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFf0a0d0),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _cancelSOS,
                    style: TextButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      _sosCountdown > 0 ? 'Cancel SOS' : 'Dismiss',
                      style: const TextStyle(color: Color(0xFFff8ab0)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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

  Widget _buildMapContent() {
    final LatLng targetPosition = _currentPosition ?? _defaultPosition;
    final bool hasLocation = _currentPosition != null;

    if (_isLocationLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 8),
            Text(
              'Getting location...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (!_locationEnabled) {
      return Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _defaultPosition,
              zoom: 5.5,
            ),
            myLocationEnabled: false,
            zoomControlsEnabled: false,
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Location services disabled',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      );
    }

    if (!hasLocation) {
      return GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _defaultPosition,
          zoom: 5.5,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        polygons: _dangerZones,
      );
    }

    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(target: targetPosition, zoom: 5.5),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      polygons: _dangerZones,
      markers: {
        Marker(
          markerId: const MarkerId('current'),
          position: targetPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
        ),
      },
    );
  }

  Widget _buildQuickAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContact(String initials, String name, Color color, bool active) {
    return Container(
      width: 60,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: color.withOpacity(0.5),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? Colors.green : Colors.orange,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildAddContact() {
    return GestureDetector(
      onTap: _showAddContactModal,
      child: Container(
        width: 46,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.add, color: Colors.purple, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  const SectionHeader({
    Key? key,
    required this.title,
    this.action,
    this.onActionTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFa078c0),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              action!,
              style: const TextStyle(color: Color(0xFFa078c0), fontSize: 11),
            ),
          ),
      ],
    );
  }
}