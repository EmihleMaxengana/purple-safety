import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/services/cloud_functions_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';
import 'package:purple_safety/trip/full_map_screen.dart';
import 'package:purple_safety/contacts/manage_contacts_modal.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/contacts/firestore_service.dart';
import 'package:purple_safety/safety/biometric_services.dart';
import 'package:purple_safety/incidents/post_choice_modal.dart';
import 'package:purple_safety/emergency/sos_alert_service.dart';
import 'package:purple_safety/trip/trip_sharing_service.dart';
import 'package:purple_safety/Invitations/invite_contact_screen.dart';
import 'package:purple_safety/messaging/dm_service.dart' as dm_service;
import 'package:purple_safety/messaging/dm_screen.dart';
import 'package:purple_safety/models/incident_model.dart';
import 'package:purple_safety/map/map.dart';
import 'package:purple_safety/services/danger_zones_service.dart';
import 'package:purple_safety/utils/pref_keys.dart';

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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isSosActive = false;
  int _sosCountdown = 0;
  Timer? _countdownTimer;
  bool _isCountdownActive = false;

  bool _isEmergencyActive = false;

  bool _showSOSStatus = false;
  String _sosStatusMessage = '';

  Timer? _tripUpdateTimer;

  bool get _isSharingTrip => TripSharingService.isSharing;

  GoogleMapController? _mapController;
  final location.Location _location = location.Location();
  bool _locationEnabled = false;
  bool _isLocationLoading = false;
  LatLng? _currentPosition;
  Set<Circle> _dangerZones = {};
  StreamSubscription<location.LocationData>? _locationSubscription;

  bool _mapLoadFailed = false;
  Timer? _mapLoadTimer;

  List<Contact> _contacts = [];

  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _contactsSubscription;
  StreamSubscription? _alertsSubscription;
  bool _hasLoadedAlerts = false;

  static const LatLng _defaultPosition = LatLng(-30.5595, 22.9375);

  bool _hasCenteredMap = false;

  // privacy toggles
  bool _shareLocationWithContacts = true;
  bool _shareLocationWithCommunity = false;

  void _getAllDangerZones() async {
    try {
      final dangerZones = await DangerZoneService().loadDangerZonesCircle();

      setState(() {
        _dangerZones = dangerZones;
      });
    } catch (e) {
      debugPrint(
        "[Home Screen] Error getting danger zones from DangerZoneService: $e",
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocation();
    _getAllDangerZones();
    _syncEmergencyStateFromBackend();
    _listenToContacts();
    // TODO: consult on the removal of this function
    // _listenToIncomingSOSAlerts();
    _listenToEmergencyStatus(); //(ADDED: listen to EmergencyManager stream)
    TripSharingService.cleanupExpiredTrips();
    _restoreTripSharingState();
    _loadPrivacyToggles();
  }

  //(ADDED: listen to EmergencyManager stream for state changes)
  void _listenToEmergencyStatus() {
    EmergencyManager().emergencyStatusStream.listen((isEmergency) {
      if (mounted) {
        setState(() {
          _isEmergencyActive = isEmergency;
        });
        //(if deactivated, reset SOS button state)
        if (!isEmergency) {
          _isSosActive = false;
          _showSOSStatus = false;
        }
      }
    });
  }

  Future<void> _syncEmergencyStateFromBackend() async {
    final user = AuthService().getCurrentUser();
    if (user == null) return;

    final hasActiveSOS = await SOSAlertService.hasActiveSOSEventForUser(
      user.uid,
    );
    EmergencyManager().setEmergencyActive(hasActiveSOS);

    if (mounted) {
      setState(() {
        _isEmergencyActive = hasActiveSOS;
        if (!hasActiveSOS) {
          _isSosActive = false;
          _showSOSStatus = false;
        }
      });
    }
  }

  Future<void> _loadPrivacyToggles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shareLocationWithContacts =
          prefs.getBool(PrefKeys.shareLocationWithContacts) ?? true;
      _shareLocationWithCommunity =
          prefs.getBool(PrefKeys.shareLocationWithCommunity) ?? false;
    });
  }

  Future<void> _restoreTripSharingState() async {
    await TripSharingService.restoreTripSession();

    if (!mounted) return;

    setState(() {});

    if (TripSharingService.isSharing && _currentPosition != null) {
      _startTripUpdateTimer();
    }
  }

  void _startTripUpdateTimer() {
    _tripUpdateTimer?.cancel();
    _tripUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_currentPosition != null && TripSharingService.isSharing) {
        TripSharingService.updateLocation(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncEmergencyStateFromBackend();
      _restoreTripSharingState();
      _loadPrivacyToggles();
    }
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

  // TODO: compare and test functionality with 'FirebaseMessaging.onMessage.listen(_onForegroundMessage)'
  // void _listenToIncomingSOSAlerts() {
  //   final user = AuthService().getCurrentUser();
  //   if (user == null) return;

  //   _alertsSubscription = FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(user.uid)
  //       .collection('alerts')
  //       .snapshots()
  //       .listen((snapshot) {
  //         if (!_hasLoadedAlerts) {
  //           _hasLoadedAlerts = true;
  //           return;
  //         }

  //         for (final change in snapshot.docChanges) {
  //           if (change.type != DocumentChangeType.added) continue;

  //           final data = change.doc.data();
  //           if (data?['type'] != 'sos') continue;
  //         }

  //         for (final item in snapshot.docs) {
  //           final data = item.data();
  //           if (data['type'] == 'sos') {
  //             if (user.displayName != data['userName']) {
  //               _localNotificationsService.showNotification(
  //                 "SOS Alert",
  //                 data['message'],
  //                 null,
  //               );
  //             }
  //           }
  //         }
  //       });
  // }

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

        if (TripSharingService.isSharing) {
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapLoadTimer?.cancel();
    setState(() {
      _mapLoadFailed = false;
    });

    if (_currentPosition != null && !_hasCenteredMap) {
      _hasCenteredMap = true;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 13),
        ),
      );
    }
  }

  Future<void> _startSOSCountdown() async {
    if (_isCountdownActive || _isEmergencyActive) return;

    final user = AuthService().getCurrentUser();
    if (user == null) return;

    final hasActiveSOS = await SOSAlertService.hasActiveSOSEventForUser(
      user.uid,
    );
    if (!EmergencyManager.canActivateSOS(
      isEmergencyActive: _isEmergencyActive,
      hasActiveSOS: hasActiveSOS,
    )) {
      if (mounted) {
        setState(() {
          _isEmergencyActive = true;
        });
      }
      EmergencyManager().setEmergencyActive(true);
      return;
    }

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
  // TRIGGER SOS - WITH PRIVACY TOGGLE CHECKS
  // ============================================================
  void _triggerSOS() async {
    setState(() {
      _isCountdownActive = false;
      _sosCountdown = 0;
    });

    if (!EmergencyManager.canActivateSOS(
      isEmergencyActive: _isEmergencyActive,
      hasActiveSOS: false,
    )) {
      EmergencyManager().setEmergencyActive(true);
      setState(() {
        _isEmergencyActive = true;
      });
      return;
    }

    final user = AuthService().getCurrentUser();
    String userName = 'Someone';
    String userId = 'anonymous';

    if (user != null) {
      userId = user.uid;
      final userData = await AuthService().getUserData(user.uid);
      userName = userData?['name'] ?? 'A user';
    }

    // check if we should include location
    bool includeLocation = false;
    double? lat;
    double? lng;

    // if either toggle is on, we include location
    if (_shareLocationWithContacts || _shareLocationWithCommunity) {
      if (_currentPosition != null) {
        includeLocation = true;
        lat = _currentPosition!.latitude;
        lng = _currentPosition!.longitude;
      }
    }

    setState(() {
      _showSOSStatus = true;
      _sosStatusMessage = 'Sending SOS...';
    });

    try {
      if (includeLocation && lat != null && lng != null) {
        // send SOS with location
        await SOSAlertService.sendCommunitySOSAlert(
          userId: userId,
          userName: userName,
          latitude: lat,
          longitude: lng,
          shareWithContacts: _shareLocationWithContacts,
          shareWithCommunity: _shareLocationWithCommunity,
        );
      } else {
        // send SOS without location
        await SOSAlertService.sendCommunitySOSAlert(
          userId: userId,
          userName: userName,
          latitude: null,
          longitude: null,
          shareWithContacts: _shareLocationWithContacts,
          shareWithCommunity: _shareLocationWithCommunity,
        );
      }

      final users = await FirebaseFirestore.instance.collection('users').get();
      for (final user in users.docs) {
        final List<dynamic>? devices = user.data()['devices'];
        if (devices != null) {
          for (final device in devices) {
            if (device != null && device['token'] != null) {
              await CloudFunctionsService().sendSOSAlert(
                token: device['token'],
                title: "SOS Alert Testing",
                body: "SOS alert - by $userName - has been activated.",
              );
            }
          }
        }
      }

      setState(() {
        _sosStatusMessage = 'SOS sent!';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showSOSStatus = false;
          });
        }
      });
    } catch (e) {
      debugPrint("[Home Screen] Error - $e");
      // store pending SOS with or without location
      if (lat != null && lng != null) {
        await SOSAlertService.storeSOSLocally(
          userId: userId,
          userName: userName,
          triggerLat: lat,
          triggerLng: lng,
        );
      } else {
        await SOSAlertService.storeSOSLocally(
          userId: userId,
          userName: userName,
          triggerLat: null,
          triggerLng: null,
        );
      }

      setState(() {
        _sosStatusMessage = 'SOS pending - Will send when connected';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showSOSStatus = false;
          });
        }
      });

      // only send SMS fallback if location is available and contacts toggle is on
      if (lat != null && lng != null && _shareLocationWithContacts) {
        await _sendSMSFallback(userName, lat, lng);
      }
    }

    if (mounted) {
      setState(() {
        _isEmergencyActive = true;
        _isSosActive = true;
      });
    }
    EmergencyManager().setEmergencyActive(true);
    widget.onNavigateToTools?.call();
  }

  Future<void> _sendSMSFallback(String userName, double lat, double lng) async {
    if (_contacts.isEmpty) return;
    if (!_shareLocationWithContacts) return;

    final locationLink = 'https://maps.google.com/?q=$lat,$lng';
    final message =
        'SOS ALERT: $userName needs immediate help!\n\n'
        'Location: $locationLink\n\n'
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
      MaterialPageRoute(builder: (context) => FullMapScreen()),
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

  void _handleTripSharing() async {
    final user = AuthService().getCurrentUser();
    if (user == null) return;
    if (!_locationEnabled) return;
    if (_currentPosition == null) return;

    final userData = await AuthService().getUserData(user.uid);
    String userName = userData?['name'] ?? 'User';

    if (_isSharingTrip) {
      await TripSharingService.stopSharing();
      _tripUpdateTimer?.cancel();
      setState(() {});
    } else {
      try {
        final tripId = await TripSharingService.startSharing(
          userName: userName,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );

        setState(() {});

        _startTripUpdateTimer();

        try {
          final recipients = await dm_service.DmService.getSelectedRecipients();
          final userId = user.uid;
          if (userId.isNotEmpty && recipients.isNotEmpty) {
            for (var recipientId in recipients) {
              await dm_service.DmService.sendTripIdMessage(
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

        _showTripShareDialog(tripId, userName);
      } catch (e) {
        debugPrint('Trip sharing error: $e');
      }
    }
  }

  void _showTripShareDialog(String tripId, String userName) {
    final shareMessage =
        '$userName is sharing their live location with you!\n\n'
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
    WidgetsBinding.instance.removeObserver(this);
    _tripUpdateTimer?.cancel();
    _countdownTimer?.cancel();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    _contactsSubscription?.cancel();
    _alertsSubscription?.cancel();
    _mapLoadTimer?.cancel();
    super.dispose();
  }

  Widget _buildMapContent() {
    final targetPosition = _currentPosition ?? _defaultPosition;
    final hasLocation = _currentPosition != null;

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
            currentPosition: _defaultPosition,
            onMapCreate: _onMapCreated,
            myLocation: false,
            myLocationButton: false,
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
        currentPosition: _defaultPosition,
        onMapCreate: _onMapCreated,
        myLocation: true,
        myLocationButton: false,
        zoomControls: false,
      );
    }

    return MapWidget(
      currentPosition: targetPosition,
      onMapCreate: _onMapCreated,
      myLocation: true,
      myLocationButton: false,
      zoomControls: false,
      circles: _dangerZones,
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

  @override
  Widget build(BuildContext context) {
    final isMaxContacts = _contacts.length >= 5;

    //(determine button text and color based on state)
    String buttonText;
    Color buttonColor;
    VoidCallback? onButtonTap;

    if (_isCountdownActive) {
      buttonText = '$_sosCountdown';
      buttonColor = const Color(0xFFe060c0);
      onButtonTap = null;
    } else if (_isEmergencyActive) {
      buttonText = 'ACTIVE';
      buttonColor = Colors.red;
      onButtonTap = null;
    } else {
      buttonText = 'SOS';
      buttonColor = const Color(0xFFe060c0);
      onButtonTap = _startSOSCountdown;
    }

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
          height: 1000,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: onButtonTap,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  buttonColor,
                                  _isEmergencyActive
                                      ? Colors.red.shade900
                                      : const Color(0xFF5c0070),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _isEmergencyActive
                                      ? Colors.red.withOpacity(0.5)
                                      : Colors.purple.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                buttonText,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _isEmergencyActive ? 20 : 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: _isEmergencyActive ? 2 : 4,
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
                    action: 'Full Map ->',
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
                    action: _contacts.isNotEmpty ? 'Manage ->' : null,
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
                        if (!isMaxContacts) _buildAddContact(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        if (_showSOSStatus)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              color: Colors.orange.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sosStatusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showSOSStatus = false;
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
