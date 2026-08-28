import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/map/map.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/incident_model.dart';
import '../incidents/incident_service.dart';
import '../emergency/sos_alert_service.dart';
import '../incidents/incident_detail_screen.dart';
import '../settings/next_of_kin_modal.dart';
import '../services/danger_zones_service.dart';
import '../contacts/firestore_service.dart';

class CommunityScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const CommunityScreen({Key? key, this.arguments}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with WidgetsBindingObserver {
  final IncidentService _incidentService = IncidentService();
  String _selectedView = 'list';
  String? _sosEventIdToFocus;

  GoogleMapController? _mapController;
  Set<Marker> _sosMarkers = {};
  Set<Marker> _incidentMarkers = {};
  bool _isMapReady = false;
  bool _mapLoadFailed = false;

  List<Map<String, dynamic>> _activeSOSEvents = [];
  bool _isLoadingSOS = true;

  bool _showDeactivationModal = false;
  Map<String, dynamic>? _deactivationSOSData;
  bool _isDeactivationModalVisible = false;
  String? _handledDeactivationSOSId;

  static const LatLng _saCenter = LatLng(-28.4795, 24.6728);

  Set<Circle> _dangerZones = {};

  final User _user = FirebaseAuth.instance.currentUser!;

  final FirestoreService _firestoreService = FirestoreService();

  void _getAllDangerZones() async {
    try {
      final dangerZones = await DangerZoneService().loadDangerZonesCircle();
      setState(() {
        _dangerZones = dangerZones;
      });
    } catch (e) {
      debugPrint(
        "[Full map screen] Error getting danger zones from DangerZoneService: $e",
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToActiveSOS();
    _loadIncidentsAsMarkers();
    _startMapLoadTimer();
    _getAllDangerZones();
    _handleNavigationArguments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDeactivationModal();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _listenToActiveSOS();
      _loadIncidentsAsMarkers();
      print('Refreshed community data on app resume');
    }
  }

  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.arguments != oldWidget.arguments) {
      _handleNavigationArguments();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDeactivationModal();
      });
    }
  }

  void _handleNavigationArguments() {
    if (widget.arguments?['showMap'] != true) return;
    _selectedView = 'map';
    _sosEventIdToFocus = widget.arguments?['sosEventId'] as String?;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusRequestedSOS());
  }

  void _focusRequestedSOS() {
    final controller = _mapController;
    if (controller == null || _sosEventIdToFocus == null) return;

    final matches = _activeSOSEvents.where(
      (event) => event['id'] == _sosEventIdToFocus,
    );
    if (matches.isEmpty) return;

    final event = matches.first;
    final latitude = event['latitude'];
    final longitude = event['longitude'];
    if (latitude is! num || longitude is! num) return;

    controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(latitude.toDouble(), longitude.toDouble()),
        16,
      ),
    );
  }

  void _startMapLoadTimer() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isMapReady && mounted) {
        setState(() {
          _mapLoadFailed = true;
        });
      }
    });
  }

  void _handleDeactivationModal() {
    final args = widget.arguments;
    if (args == null || args is! Map<String, dynamic>) return;

    if (args['showDeactivationModal'] != true) return;

    final sosEventId = args['sosEventId'] as String?;
    if (sosEventId == null || sosEventId.isEmpty) return;
    if (_handledDeactivationSOSId == sosEventId) return;

    _handledDeactivationSOSId = sosEventId;
    _loadDeactivationSOSData(sosEventId);
  }

  Future<void> _loadDeactivationSOSData(String sosEventId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('active_sos_events')
          .doc(sosEventId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _deactivationSOSData = data;
          _showDeactivationModal = true;
          _isDeactivationModalVisible = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading deactivation SOS data: $e');
    }
  }

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
            _focusRequestedSOS();
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
            title: 'SOS ACTIVE!',
            snippet: event['userId'] != _user.uid
                ? '${event['userName']} needs immediate help!\nTap to respond'
                : null,
          ),
          onTap: () => _showSOSResponderModal(event),
        );
        _sosMarkers.add(marker);
      }

      debugPrint(
        'Updated SOS markers: ${_sosMarkers.length} active SOS events',
      );
    });
  }

  void _loadIncidentsAsMarkers() {
    _incidentService.getAllIncidents().listen((incidents) {
      setState(() {
        _incidentMarkers = {};

        for (var incident in incidents) {
          if (incident.latitude != null && incident.longitude != null) {
            final markerId = MarkerId(incident.id);

            final marker = Marker(
              markerId: markerId,
              position: LatLng(incident.latitude!, incident.longitude!),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerHue(incident.type),
              ),
              infoWindow: InfoWindow(
                title: incident.title,
                snippet:
                    '${incident.type.toString().split('.').last}\nTap for details',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        IncidentDetailScreen(incident: incident),
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

  //(check if current user is a trusted contact of the SOS trigger user)
  Future<bool> _isTrustedContact(String triggerUserId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || triggerUserId == currentUser.uid) {
        return false;
      }

      final contactCheck = await FirebaseFirestore.instance
          .collection('users')
          .doc(triggerUserId)
          .collection('contacts')
          .where('userId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      return contactCheck.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking trusted contact: $e');
      return false;
    }
  }

  //(get next of kin data for a user)
  Future<Map<String, dynamic>?> _getNextOfKinData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) return null;
      final data = userDoc.data();
      return {
        'name': data?['nextOfKinName'] as String?,
        'phone': data?['nextOfKinPhone'] as String?,
        'relation': data?['nextOfKinRelation'] as String?,
        'altPhone': data?['nextOfKinAltPhone'] as String?,
      };
    } catch (e) {
      debugPrint('Error getting next of kin data: $e');
      return null;
    }
  }

  void _showSOSResponderModal(Map<String, dynamic> sosEvent) {
    final triggerUserId = sosEvent['userId'] as String?;
    final triggerUserName = sosEvent['userName'] as String? ?? 'Someone';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<bool>(
        future: _isTrustedContact(triggerUserId ?? ''),
        builder: (context, trustedSnapshot) {
          final isTrusted = trustedSnapshot.data ?? false;

          return FutureBuilder<Map<String, dynamic>?>(
            future: isTrusted
                ? _getNextOfKinData(triggerUserId ?? '')
                : Future.value(null),
            builder: (context, kinSnapshot) {
              final nextOfKinData = kinSnapshot.data;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a0f2e),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //(header with user avatar)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => showNextOfKinModal(
                              context,
                              sosEvent['userId'],
                              sosEvent['userName'],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.red.withOpacity(0.2),
                                child: Text(
                                  (sosEvent['userName'] as String).isNotEmpty
                                      ? (sosEvent['userName'] as String)[0]
                                            .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ACTIVE SOS EMERGENCY',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  sosEvent['userName'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),

                      //(show next of kin details only for trusted contacts)
                      if (isTrusted && nextOfKinData != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Next of Kin Information',
                          style: TextStyle(
                            color: Color(0xFFa078c0),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (nextOfKinData['name'] != null &&
                            nextOfKinData['name']!.isNotEmpty) ...[
                          _buildInfoRow(
                            icon: Icons.person,
                            label: 'Name',
                            value: nextOfKinData['name']!,
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (nextOfKinData['relation'] != null &&
                            nextOfKinData['relation']!.isNotEmpty) ...[
                          _buildInfoRow(
                            icon: Icons.people,
                            label: 'Relationship',
                            value: nextOfKinData['relation']!,
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (nextOfKinData['phone'] != null &&
                            nextOfKinData['phone']!.isNotEmpty) ...[
                          _buildClickablePhoneRow(
                            label: 'Phone',
                            value: nextOfKinData['phone']!,
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (nextOfKinData['altPhone'] != null &&
                            nextOfKinData['altPhone']!.isNotEmpty) ...[
                          _buildClickablePhoneRow(
                            label: 'Alternative',
                            value: nextOfKinData['altPhone']!,
                          ),
                          const SizedBox(height: 6),
                        ],
                        const Divider(color: Colors.white24),
                      ],

                      //(responder count)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${sosEvent['responderCount']} people are on their way to help',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      //(action buttons)
                      Row(
                        children: [
                          if (sosEvent['userId'] != _user.uid)
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          if (sosEvent['userId'] != _user.uid)
                            const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              label: const Text('Close'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFBF7DCB), size: 16),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClickablePhoneRow({
    required String label,
    required String value,
  }) {
    final cleanedNumber = value.replaceAll(RegExp(r'\D'), '');
    final displayNumber = _formatPhoneForDisplay(value);

    return Row(
      children: [
        const Icon(Icons.phone, color: Colors.green, size: 16),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final Uri url = Uri(scheme: 'tel', path: cleanedNumber);
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            child: Text(
              displayNumber,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatPhoneForDisplay(String phone) {
    if (phone.isEmpty) return 'Not set';
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('27') && cleaned.length == 11) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.length == 9) {
      return '+27 ${cleaned.substring(0, 2)} ${cleaned.substring(2, 5)} ${cleaned.substring(5)}';
    }
    return phone;
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

      if (mounted) {}
    } catch (e) {
      debugPrint('Error responding to SOS: $e');
    }
  }

  void _openNavigationToSOS(Map<String, dynamic> sosEvent) async {
    final url =
        'https://www.google.com/maps/dir//${sosEvent['latitude']},${sosEvent['longitude']}';
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openNavigationToLocation(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildDeactivationModal() {
    if (!_showDeactivationModal || _deactivationSOSData == null) {
      return const SizedBox();
    }

    final data = _deactivationSOSData!;
    final userName = data['userName'] ?? 'Someone';
    final userId = data['userId'] ?? '';
    final triggerLat =
        _toDouble(data['triggerLat']) ?? _toDouble(data['latitude']);
    final triggerLng =
        _toDouble(data['triggerLng']) ?? _toDouble(data['longitude']);
    final triggerTimestamp = data['triggerTimestamp'];
    final finalLat =
        _toDouble(data['finalLatitude']) ?? _toDouble(data['latitude']);
    final finalLng =
        _toDouble(data['finalLongitude']) ?? _toDouble(data['longitude']);
    final resolvedAt = data['resolvedAt'];
    final deactivationReason = data['deactivationReason'] as String?;

    final String startLocation = _coordinateString(triggerLat, triggerLng);
    final String endLocation = _coordinateString(finalLat, finalLng);

    final String triggerTime =
        _formatDateTimeFromData(triggerTimestamp) ??
        _formatDateTimeFromData(data['timestamp']) ??
        'Unknown';
    final String resolvedTime =
        _formatDateTimeFromData(resolvedAt) ??
        _formatDateTimeFromData(data['timestamp']) ??
        'Unknown';

    String deactivationType = deactivationReason == 'user_safe'
        ? 'User marked themselves safe'
        : 'System ended (device offline or inactive)';

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1a0f2e),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SOS Deactivated',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$userName\'s SOS alert has been deactivated',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.person,
                            label: 'Triggered by',
                            value: userName,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.location_on,
                            label: 'Start location',
                            value: startLocation,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.location_off,
                            label: 'End location',
                            value: endLocation,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.timer,
                            label: 'Triggered at',
                            value: triggerTime,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.check_circle,
                            label: 'Deactivated at',
                            value: resolvedTime,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.info_outline,
                            label: 'Status',
                            value: deactivationType,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showDeactivationModal = false;
                            _isDeactivationModalVisible = false;
                            _deactivationSOSData = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A1B9A),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFBF7DCB), size: 16),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime time) {
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String? _formatDateTimeFromData(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return _formatDateTime(timestamp.toDate());
    }

    if (timestamp is DateTime) {
      return _formatDateTime(timestamp);
    }

    if (timestamp is String) {
      try {
        return _formatDateTime(DateTime.parse(timestamp));
      } catch (_) {
        return timestamp;
      }
    }

    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _coordinateString(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return 'Location not available';
    }
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Community Safety'),
          backgroundColor: const Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
          actions: [
            if (_activeSOSEvents.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: Icon(_selectedView == 'list' ? Icons.map : Icons.list),
              onPressed: () {
                setState(() {
                  _selectedView = _selectedView == 'list' ? 'map' : 'list';
                });
              },
              tooltip: _selectedView == 'list'
                  ? 'Switch to Map View'
                  : 'Switch to List View',
            ),
          ],
        ),
        body: Stack(
          children: [
            _selectedView == 'map' ? _buildMapView() : _buildListView(),
            if (_showDeactivationModal && _deactivationSOSData != null)
              _buildDeactivationModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Column(
      children: [
        if (_activeSOSEvents.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              border: Border(
                bottom: BorderSide(color: Colors.red.withOpacity(0.3)),
              ),
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
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.warning, color: Colors.red, size: 16),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              if (_mapLoadFailed)
                Center(
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
                            _isMapReady = false;
                          });
                          _startMapLoadTimer();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                MapWidget(
                  onMapCreate: (controller) {
                    controller.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(target: _saCenter, zoom: 5),
                      ),
                    );

                    _mapController = controller;
                    setState(() => _isMapReady = true);
                    _focusRequestedSOS();
                  },
                  markers: {..._sosMarkers, ..._incidentMarkers},
                  myLocation: true,
                  myLocationButton: true,
                  zoomControls: true,
                  compass: true,
                  currentPosition: _saCenter,
                  circles: {..._dangerZones},
                ),
              if (_isLoadingSOS && !_mapLoadFailed)
                const Center(
                  child: CircularProgressIndicator(color: Colors.purple),
                ),
              Positioned(
                bottom: 80,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildLegendItem(Colors.red, 'Active SOS'),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        if (_activeSOSEvents.isNotEmpty)
          GestureDetector(
            onTap: () {
              setState(() => _selectedView = 'map');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                border: Border(
                  bottom: BorderSide(color: Colors.red.withOpacity(0.3)),
                ),
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
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('incidents')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                        'Tap Report Incident on Home screen to post',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                );
              }

              final incidents = snapshot.data!.docs
                  .map((doc) => Incident.fromFirestore(doc))
                  .toList();
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
              if (incident.type == IncidentType.missingPerson &&
                  incident.missingPersonName != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_search,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MISSING: ${incident.missingPersonName}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (incident.missingPersonAge != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Age: ${incident.missingPersonAge}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (incident.lastSeenLocation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Last seen: ${incident.lastSeenLocation}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (incident.missingPersonImageUrl != null &&
                          incident.missingPersonImageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Scaffold(
                                    backgroundColor: Colors.black,
                                    appBar: AppBar(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                    ),
                                    body: Center(
                                      child: InteractiveViewer(
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              incident.missingPersonImageUrl!,
                                          placeholder: (context, url) =>
                                              const CircularProgressIndicator(),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                Icons.broken_image,
                                                color: Colors.white54,
                                                size: 60,
                                              ),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: incident.missingPersonImageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white54,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      incident.location,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
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
                    incident.isAnonymous
                        ? 'Anonymous'
                        : (incident.userName ?? 'User'),
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
                          builder: (context) =>
                              IncidentDetailScreen(incident: incident),
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
    final message =
        '''
${incident.title}

${incident.description}

Location: ${incident.location}
Reported: ${_formatTime(incident.timestamp)}
Reported by: ${incident.isAnonymous ? 'Anonymous' : incident.userName ?? 'User'}

${incident.type == IncidentType.missingPerson ? 'MISSING PERSON: ${incident.missingPersonName}\nAge: ${incident.missingPersonAge}\nLast seen: ${incident.lastSeenLocation}\n' : ''}
Please share to help spread awareness.
''';

    await Share.share(message);
    await _incidentService.shareIncident(incident.id);

    setState(() {});
  }
}
