import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:purple_safety/services/biometric_services.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';
import 'package:purple_safety/full_map_screen.dart';
import 'package:purple_safety/manage_contacts_modal.dart';
import 'package:purple_safety/add_contact_modal.dart';
import 'package:purple_safety/services/location_sharing_service.dart';
import 'package:purple_safety/services/user_service.dart';

// Contact model
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
  bool _sosFingerprintEnabled = false;

  // Map state
  GoogleMapController? _mapController;
  location.Location _location = location.Location();
  bool _locationEnabled = false;
  LatLng? _currentPosition;
  Set<Polygon> _dangerZones = {};
  StreamSubscription<location.LocationData>? _locationSubscription;

  // Contacts – default Evile
  List<Contact> _contacts = [
    Contact(
      id: '1',
      name: 'Evile',
      initials: 'E',
      color: Colors.purple,
      active: true,
      phone: '+27 62 140 1847',
      relationship: 'Friend',
    ),
  ];

  // Location sharing state
  bool _isSharingLocation = false;

  final String _mapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {"color": "#1d2c4d"}
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {"color": "#8ec3b9"}
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {"color": "#1a3646"}
      ]
    },
    {
      "featureType": "administrative.country",
      "elementType": "geometry.stroke",
      "stylers": [
        {"color": "#4b6e8c"}
      ]
    },
    {
      "featureType": "administrative.land_parcel",
      "elementType": "labels.text.fill",
      "stylers": [
        {"color": "#64779e"}
      ]
    },
    {
      "featureType": "administrative.province",
      "elementType": "geometry.stroke",
      "stylers": [
        {"color": "#4b6e8c"}
      ]
    },
    {
      "featureType": "landscape.man_made",
      "elementType": "geometry.stroke",
      "stylers": [
        {"color": "#334e87"}
      ]
    },
    {
      "featureType": "landscape.natural",
      "elementType": "geometry",
      "stylers": [
        {"color": "#023e58"}
      ]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [
        {"color": "#283d6a"}
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {"color": "#6f9ba5"}
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.stroke",
      "stylers": [
        {"color": "#1d2c4d"}
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.fill",
      "stylers": [
        {"color": "#304a7d"}
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [
        {"color": "#1d2c4d"}
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {"color": "#98a5be"}
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.stroke",
      "stylers": [
        {"color": "#1d2c4d"}
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {"color": "#2c6675"}
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        {"color": "#255868"}
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [
        {"color": "#b0d5ce"}
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.stroke",
      "stylers": [
        {"color": "#023e58"}
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.fill",
      "stylers": [
        {"color": "#98a5be"}
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.stroke",
      "stylers": [
        {"color": "#1d2c4d"}
      ]
    },
    {
      "featureType": "transit.line",
      "elementType": "geometry.fill",
      "stylers": [
        {"color": "#283d6a"}
      ]
    },
    {
      "featureType": "transit.station",
      "elementType": "geometry",
      "stylers": [
        {"color": "#3a4762"}
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {"color": "#0e1626"}
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {"color": "#4e6d70"}
      ]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadSOSStatus();
    _initLocation();
    _setupDangerZones();
    // Initialize EmergencyManager with initial contacts
    EmergencyManager().setCurrentContacts(_contacts);
  }

  Future<void> _loadSOSStatus() async {
    final enabled = await BiometricService.isSOSFingerprintEnabled();
    setState(() => _sosFingerprintEnabled = enabled);
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    location.PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == location.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != location.PermissionStatus.granted) return;
    }

    setState(() => _locationEnabled = true);

    _locationSubscription = _location.onLocationChanged.listen((
      location.LocationData currentLocation,
    ) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        setState(() {
          _currentPosition = LatLng(
            currentLocation.latitude!,
            currentLocation.longitude!,
          );
        });
        _checkDangerZone(_currentPosition!);
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

  void _checkDangerZone(LatLng position) {
    bool inside = false;
    for (Polygon polygon in _dangerZones) {
      if (_pointInPolygon(position, polygon.points.toList())) {
        inside = true;
        break;
      }
    }
    if (inside) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ You are entering a danger zone! Stay alert.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length - 1; i++) {
      if (_rayCastIntersect(point, polygon[i], polygon[i + 1])) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  bool _rayCastIntersect(LatLng point, LatLng vertA, LatLng vertB) {
    double aY = vertA.latitude;
    double bY = vertB.latitude;
    double aX = vertA.longitude;
    double bX = vertB.longitude;

    if (aY > bY) {
      double temp = aY;
      aY = bY;
      bY = temp;
      temp = aX;
      aX = bX;
      bX = temp;
    }

    if (point.latitude == aY || point.latitude == bY) return true;
    if (point.latitude < aY || point.latitude > bY) return false;
    if (point.longitude > (aX + (point.latitude - aY) / (bY - aY) * (bX - aX)))
      return true;
    return false;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController!.setMapStyle(_mapStyle);
  }

  void _handleSOSPress() {
    setState(() => _isHolding = true);
    _holdTimer = Timer(const Duration(milliseconds: 800), () async {
      if (_sosFingerprintEnabled) {
        final authenticated =
            await BiometricService.triggerSOSWithFingerprint();
        if (!authenticated) {
          setState(() => _isHolding = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint authentication failed.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
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
    // Store current contacts in EmergencyManager so they are available in the tools screen
    EmergencyManager().setCurrentContacts(_contacts);
    // Navigate to Tools page (emergency mode UI)
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

  // Navigation
  void _openFullMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FullMapScreen()),
    );
  }

  void _showManageContactsModal() {
    showDialog(
      context: context,
      builder: (context) => ManageContactsModal(
        contacts: _contacts,
        onDelete: (id) {
          setState(() {
            _contacts.removeWhere((c) => c.id == id);
            // Update EmergencyManager after deletion
            EmergencyManager().setCurrentContacts(_contacts);
          });
        },
      ),
    );
  }

  void _showAddContactModal() {
    showDialog(
      context: context,
      builder: (context) => AddContactModal(
        onAdd: (newContact) {
          setState(() {
            _contacts.add(newContact);
            // Update EmergencyManager with the new contacts list
            EmergencyManager().setCurrentContacts(_contacts);
          });
        },
        currentCount: _contacts.length,
      ),
    );
  }

  // Quick action handlers
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

    final smsStatus = await permission.Permission.sms.request();
    if (!smsStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission required to share location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = await UserService.getUser();
    final userName = user['name'] ?? 'User';
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
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Purple Safety',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Syne',
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Protected',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications,
                                  color: Colors.white70,
                                ),
                                onPressed: () {},
                              ),
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
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SOS Button
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

                  // Live Location Map
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
                      child: _locationEnabled
                          ? GoogleMap(
                              onMapCreated: _onMapCreated,
                              initialCameraPosition: const CameraPosition(
                                target: LatLng(-30.5595, 22.9375),
                                zoom: 5.0,
                              ),
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              polygons: _dangerZones,
                              markers: _currentPosition != null
                                  ? {
                                      Marker(
                                        markerId: const MarkerId('current'),
                                        position: _currentPosition!,
                                        icon:
                                            BitmapDescriptor.defaultMarkerWithHue(
                                              BitmapDescriptor.hueViolet,
                                            ),
                                      ),
                                    }
                                  : {},
                            )
                          : const Center(
                              child: Text(
                                'Location not available',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions
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

                  // Trusted Contacts
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

                  // Safety Alerts
                  const SectionHeader(title: 'SAFETY ALERTS', action: 'All →'),
                  const SizedBox(height: 8),
                  _buildAlert(
                    type: 'warning',
                    icon: Icons.warning,
                    message: 'Incident reported 0.3mi NE',
                    time: '2m ago',
                  ),
                  const SizedBox(height: 4),
                  _buildAlert(
                    type: 'info',
                    icon: Icons.info,
                    message: 'Safe zone: Central Park active',
                    time: '15m ago',
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        // SOS Overlay
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

  // Helper methods
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

  Widget _buildAlert({
    required String type,
    required IconData icon,
    required String message,
    required String time,
  }) {
    Color color = type == 'warning' ? Colors.red : Colors.blue;
    return Container(
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
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
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
