import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/map.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';
import 'package:purple_safety/trip/full_map_screen.dart';
import 'package:purple_safety/contacts/manage_contacts_modal.dart';
import 'package:purple_safety/contacts/add_contact_screen.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/contacts/firestore_service.dart';
import 'package:purple_safety/safety/biometric_services.dart';
import 'package:purple_safety/incidents/post_choice_modal.dart';
import 'package:purple_safety/emergency/sos_alert_service.dart';
import 'package:purple_safety/trip/trip_sharing_service.dart';
import 'package:purple_safety/Invitations/invite_contact_screen.dart';
import 'package:purple_safety/messaging/dm_service.dart';
import 'package:purple_safety/messaging/dm_screen.dart';
import 'package:purple_safety/models/incident_model.dart';

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
  bool _isCountdownActive = false;

  // Trip sharing state
  bool _isSharingTrip = false;
  Timer? _tripUpdateTimer;

  // Map state
  GoogleMapController? _mapController;
  final location.Location _location = location.Location();
  bool _locationEnabled = false;
  bool _isLocationLoading = false;
  LatLng? _currentPosition;
  Set<Polygon> _dangerZones = {};
  StreamSubscription<location.LocationData>? _locationSubscription;

  // Map retry
  bool _mapLoadFailed = false;
  Timer? _mapLoadTimer;

  // Contacts
  List<Contact> _contacts = [];

  // Firestore
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _contactsSubscription;

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
  bool _hasCenteredMap = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _setupDangerZones();
    _listenToContacts();
    TripSharingService.cleanupExpiredTrips();
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

  Future<void> _initLocation() async {
    setState(() => _isLocationLoading = true);
    bool serviceEnabled;
    location.PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
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
        setState(() {
          _locationEnabled = false;
          _isLocationLoading = false;
        });
        return;
      }
    }

    setState(() => _locationEnabled = true);
    _startMapLoadTimer();

    _locationSubscription = _location.onLocationChanged.listen((event) {
      if (event.latitude != null && event.longitude != null) {
        setState(() {
          _currentPosition = LatLng(event.latitude!, event.longitude!);
          _isLocationLoading = false;
        });
        if (!_hasCenteredMap && _mapController != null) {
          _hasCenteredMap = true;
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _currentPosition!, zoom: 14),
            ),
          );
        }

        if (_isSharingTrip && TripSharingService.isSharing) {
          TripSharingService.updateLocation(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
          );
        }
      }
    });
  }

  void _startMapLoadTimer() {
    _mapLoadTimer?.cancel();
    _mapLoadTimer = Timer(const Duration(seconds: 10), () {
      if (_mapController == null && mounted) {
        setState(() {
          _mapLoadFailed = true;
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
    _mapLoadTimer?.cancel();
    setState(() {
      _mapLoadFailed = false;
    });

    if (_currentPosition != null && !_hasCenteredMap) {
      _hasCenteredMap = true;
      controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 14),
        ),
      );
    }
  }

  // ============================================================
  // SOS BUTTON - Single tap with countdown
  // ============================================================
  void _startSOSCountdown() {
    if (_isCountdownActive) return;
    setState(() {
      _isCountdownActive = true;
      _sosCountdown = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sosCountdown--;
      });
      if (_sosCountdown == 0) {
        timer.cancel();
        _triggerSOS();
      }
    });
  }

  void _cancelSOS() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountdownActive = false;
      _sosCountdown = 0;
    });
  }

  // ============================================================
  // FIXED: SOS triggers Tools page (not Emergency)
  // ============================================================
  void _triggerSOS() async {
    // Reset countdown state
    setState(() {
      _isCountdownActive = false;
      _sosCountdown = 0;
    });

    final user = AuthService().getCurrentUser();
    String userName = 'Someone';
    String userId = 'anonymous';

    if (user != null) {
      userId = user.uid;
      final userData = await AuthService().getUserData(user.uid);
      userName = userData?['name'] ?? 'A user';
    }

    if (_currentPosition == null) {
      // No location – we can't send SOS
      return;
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    // Try Firebase first
    try {
      await SOSAlertService.sendCommunitySOSAlert(
        userId: userId,
        userName: userName,
        latitude: lat,
        longitude: lng,
      );
    } catch (e) {
      // If Firebase fails, try SMS fallback
      await _sendSMSFallback(userName, lat, lng);
    }

    // ✅ SET EMERGENCY ACTIVE (NO SCREEN PUSH)
    EmergencyManager().setEmergencyActive(true);

    // ✅ NAVIGATE DIRECTLY TO TOOLS PAGE (index 3)
    widget.onNavigateToTools?.call();
  }

  // ============================================================
  // SMS FALLBACK - Send SMS to trusted contacts when offline
  // ============================================================
  Future<void> _sendSMSFallback(String userName, double lat, double lng) async {
    if (_contacts.isEmpty) return;

    final locationLink = 'https://maps.google.com/?q=$lat,$lng';
    final message =
        '🚨 SOS ALERT: $userName needs immediate help!\n\n'
        '📍 Location: $locationLink\n\n'
        'This is an automated safety alert from Purple Safety.\n'
        'Please check on them or contact emergency services.';

    for (var contact in _contacts) {
      if (contact.phone != null && contact.phone!.isNotEmpty) {
        try {
          await SOSAlertService.sendSMS(
            phoneNumber: contact.phone!,
            message: message,
          );
        } catch (e) {
          debugPrint('SMS fallback failed for ${contact.name}: $e');
        }
      }
    }
  }

  void _openFullMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullMapScreen(dangerZones: _dangerZones),
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
          final authenticated =
              await BiometricService.authenticateWithUserPreference(
                context: context,
                reason: 'Authenticate to delete this contact',
              );
          if (authenticated) {
            await _firestoreService.deleteContact(user.uid, id);
          }
        },
        onUpdate: (updatedContact) async {
          await _firestoreService.updateContact(user.uid, updatedContact);
        },
      ),
    );
  }

  void _openReportIncident() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PostChoiceModal(),
    );
  }

  (double?, double?) _getCoordinates() {
    return (_currentPosition?.latitude, _currentPosition?.longitude);
  }

  void _handleTripSharing() async {
    final user = AuthService().getCurrentUser();
    if (user == null) return;

    if (!_locationEnabled) return;

    if (_currentPosition == null) return;

    String userName = 'User';
    final userData = await AuthService().getUserData(user.uid);
    userName = userData?['name'] ?? 'User';

    if (_isSharingTrip) {
      await TripSharingService.stopSharing();
      _tripUpdateTimer?.cancel();
      setState(() {
        _isSharingTrip = false;
      });
    } else {
      try {
        final tripId = await TripSharingService.startSharing(
          userName: userName,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );

        setState(() {
          _isSharingTrip = true;
        });

        // Periodic location updates - 15 seconds
        _tripUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
          if (_currentPosition != null && TripSharingService.isSharing) {
            TripSharingService.updateLocation(
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
            );
          }
        });

        // Auto send trip ID to pre-selected DM recipients
        try {
          final recipients = await DmService.getSelectedRecipients();
          final userId = user.uid;
          if (userId != null && recipients.isNotEmpty) {
            for (var recipientId in recipients) {
              await DmService.sendTripIdMessage(
                recipientUserId: recipientId,
                senderName: userName,
                tripId: tripId,
                senderId: userId,
              );
            }
          }
        } catch (e) {
          debugPrint('Auto DM error: $e');
        }

        // Show share modal (unchanged)
        _showTripShareDialog(tripId, userName);
      } catch (e) {
        debugPrint('Trip sharing error: $e');
      }
    }
  }

  void _showTripShareDialog(String tripId, String userName) {
    final shareMessage =
        '🔴 $userName is sharing their live location with you!\n\n'
        'Open Purple Safety app, go to Full Map, tap the ID icon, and enter this Trip ID:\n\n'
        'TRIP ID: $tripId\n\n'
        '(Download Purple Safety if you don\'t have it)';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1a0f2e),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.share_location, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Trip Sharing Active!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this Trip ID with friends. They can enter it in the Full Map to watch your journey.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trip ID',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                        Text(
                          tripId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.purple,
                      size: 20,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tripId));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        shareMessage,
                        subject: 'Live Location - Purple Safety',
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Trip ID'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DMScreen(shareTripId: tripId),
                    ),
                  );
                },
                icon: const Icon(Icons.people, color: Color(0xFFBF7DCB)),
                label: const Text(
                  'Share with trusted contacts',
                  style: TextStyle(color: Color(0xFFBF7DCB)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBF7DCB)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Note: Friend needs Purple Safety app installed',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
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
    TripSharingService.stopSharing();
    _tripUpdateTimer?.cancel();
    _countdownTimer?.cancel();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    _contactsSubscription?.cancel();
    _mapLoadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMaxContacts = _contacts.length >= 5;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
        ),
      ),
      height: 1000,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // SOS Button
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isCountdownActive ? null : _startSOSCountdown,
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
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _isCountdownActive ? '$_sosCountdown' : 'SOS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_isCountdownActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton(
                          onPressed: _cancelSOS,
                          style: TextButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Cancel SOS',
                            style: TextStyle(color: Color(0xFFff8ab0)),
                          ),
                        ),
                      ),
                  ],
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
                    Icons.share_location,
                    _isSharingTrip ? 'Stop Sharing Trip' : 'Share Trip',
                    _isSharingTrip ? Colors.red : const Color(0xFF8260dc),
                    _handleTripSharing,
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
                    Icons.report,
                    'Report Incident',
                    const Color(0xFFdcb060),
                    _openReportIncident,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              SectionHeader(
                title: 'TRUSTED CONTACTS (${_contacts.length}/5)',
                action: _contacts.isNotEmpty ? 'Manage →' : null,
                onActionTap: _showManageContactsModal,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._contacts.map(
                      (c) =>
                          _buildContact(c.initials, c.name, c.color, c.active),
                    ),
                    if (!isMaxContacts) _buildAddContact(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapContent() {
    final LatLng targetPosition = _currentPosition ?? _defaultPosition;
    final bool hasLocation = _currentPosition != null;

    if (_mapLoadFailed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'Failed to load map',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _mapLoadFailed = false;
                  _mapController = null;
                });
                _startMapLoadTimer();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

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
          MapWidget(
            onMapCreate: _onMapCreated,
            currentPosition: _defaultPosition,
            myLocation: false,
            zoomControls: false,
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
      return MapWidget(
        onMapCreate: _onMapCreated,
        currentPosition: _defaultPosition,
        myLocation: true,
        myLocationButton: false,
        zoomControls: false,
        polygons: _dangerZones,
      );
    }

    return MapWidget(
      onMapCreate: _onMapCreated,
      currentPosition: targetPosition,
      myLocation: true,
      myLocationButton: false,
      zoomControls: false,
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InviteContactScreen()),
        );
      },
      child: Container(
        width: 60,
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
                  child: Icon(Icons.add, color: Colors.purple, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Invite',
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