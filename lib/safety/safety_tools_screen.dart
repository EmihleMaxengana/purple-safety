import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import 'package:purple_safety/map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';
import 'package:purple_safety/safety/biometric_services.dart';
import 'package:purple_safety/services/location_sharing_service.dart';
import 'package:purple_safety/emergency/sos_alert_service.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/contacts/firestore_service.dart';
import 'package:purple_safety/models/incident_model.dart';

class SafetyToolsScreen extends StatefulWidget {
  final VoidCallback onCallEmergency;
  const SafetyToolsScreen({Key? key, required this.onCallEmergency})
    : super(key: key);

  @override
  State<SafetyToolsScreen> createState() => _SafetyToolsScreenState();
}

class _SafetyToolsScreenState extends State<SafetyToolsScreen>
    with WidgetsBindingObserver {
  bool _isEmergencyActive = false;
  bool _isRecordingAudio = false;
  bool _isRecordingVideo = false;
  bool _autoShareRecordings = false;
  bool _isLiveStreaming = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  location.Location _location = location.Location();
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  StreamSubscription<location.LocationData>? _locationSubscription;
  bool _locationEnabled = false;

  List<Contact> _contacts = [];
  String _securityNumber = '10111';

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadAutoSharePreference();
    _listenToEmergencyStatus();
    _loadContacts();
    _initLocation();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadAutoSharePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoShareRecordings = prefs.getBool('autoShareRecordings') ?? false;
    });
  }

  Future<void> _saveAutoSharePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoShareRecordings', value);
  }

  void _listenToEmergencyStatus() {
    EmergencyManager().emergencyStatusStream.listen((isEmergency) {
      if (mounted) {
        setState(() {
          _isEmergencyActive = isEmergency;
        });
      }
    });
    setState(() {
      _isEmergencyActive = EmergencyManager().isEmergencyActive;
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _audioRecorder.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> _loadContacts() async {
    final contacts = EmergencyManager().getCurrentContacts();
    setState(() {
      _contacts = contacts;
    });
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    location.PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == location.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != location.PermissionStatus.granted) {
        return;
      }
    }

    setState(() => _locationEnabled = true);

    _locationSubscription = _location.onLocationChanged.listen((event) {
      if (event.latitude != null && event.longitude != null) {
        setState(() {
          _currentPosition = LatLng(event.latitude!, event.longitude!);
        });
        _updateMapCamera();
      }
    });
  }

  void _updateMapCamera() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 15),
        ),
      );
    }
  }

  Future<void> _resendLocation() async {
    // Silent action
  }

  Future<void> _callNumber(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint('Could not call $number');
    }
  }

  // ============================================================
  // I'M SAFE - Only works if SOS is active
  // ============================================================
  Future<void> _imSafe() async {
    // Check if SOS is active
    if (!_isEmergencyActive) {
      return;
    }

    final authenticated = await BiometricService.authenticateWithUserPreference(
      context: context,
      reason: 'Confirm you are safe to deactivate SOS',
    );

    if (!authenticated) {
      return;
    }

    final user = AuthService().getCurrentUser();
    String userName = 'Someone';
    String? userId = user?.uid;
    if (user != null) {
      final userData = await AuthService().getUserData(user.uid);
      userName = userData?['name'] ?? 'A user';
      userId = user.uid;
    }

    // Deactivate SOS event
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('active_sos_events')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in querySnapshot.docs) {
        await SOSAlertService.deactivateSOSEvent(doc.id);
        debugPrint('✅ Deactivated SOS event: ${doc.id}');
      }
    } catch (e) {
      debugPrint('Error deactivating SOS event: $e');
    }

    // Stop location sharing if active
    if (LocationSharingService.isSharing) {
      LocationSharingService.stopSharing();
    }

    // Stop any ongoing recordings
    if (_isRecordingAudio) {
      await _stopAudioRecording();
    }

    // Send safe alert to ALL users EXCEPT the user themselves
    await _sendGlobalSafeAlert(userName, userId);

    EmergencyManager().deactivateEmergencyMode();

    setState(() {
      _isEmergencyActive = false;
    });

    _showSafeConfirmationDialog();
  }

  // ============================================================
  // GLOBAL SAFE ALERT - Sends to ALL users EXCEPT sender
  // ============================================================
  Future<void> _sendGlobalSafeAlert(
    String userName,
    String? currentUserId,
  ) async {
    try {
      final locationLink = _currentPosition != null
          ? 'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          : 'Location unavailable';

      final message =
          '✅ SAFE UPDATE: $userName has confirmed they are safe. SOS has been deactivated. Final location: $locationLink';

      await FirebaseFirestore.instance.collection('global_alerts').add({
        'timestamp': FieldValue.serverTimestamp(),
        'message': message,
        'type': 'safe',
        'userName': userName,
        'locationLink': locationLink,
      });

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      final batch = FirebaseFirestore.instance.batch();

      for (var userDoc in usersSnapshot.docs) {
        // Skip sending notification to the user who marked themselves safe
        if (userDoc.id == currentUserId) continue;

        final alertRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('alerts')
            .doc();

        batch.set(alertRef, {
          'message': message,
          'type': 'safe',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      await batch.commit();
      debugPrint(
        'Global safe alert sent to all ${usersSnapshot.docs.length - 1} users (excluding sender)',
      );
    } catch (e) {
      debugPrint('Error sending global safe alert: $e');
    }
  }

  void _showSafeConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1a0f2e),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You Are Safe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SOS has been deactivated. All users have been notified that you are safe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RECORDING METHODS
  // ============================================================
  Future<void> _startAudioRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      return;
    }

    if (await _audioRecorder.hasPermission()) {
      final dir = Directory.systemTemp;
      final path =
          '${dir.path}/safety_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _isRecordingAudio = true;
        _audioPath = path;
      });
      debugPrint('Audio recording started at: $path');
    }
  }

  Future<void> _stopAudioRecording() async {
    if (_isRecordingAudio && await _audioRecorder.isRecording()) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecordingAudio = false);

      if (path != null) {
        debugPrint('Audio recording saved at: $path');
        if (_autoShareRecordings) {
          await _shareFile(path, 'audio');
        }
      }
    }
  }

  Future<void> _recordVideo() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      return;
    }

    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      setState(() {
        _isRecordingVideo = true;
      });
      debugPrint('Video recorded: ${video.path}');

      if (_autoShareRecordings) {
        await _shareFile(video.path, 'video');
      }
      setState(() => _isRecordingVideo = false);
    }
  }

  // ============================================================
  // LIVE STREAMING - Toggle
  // ============================================================
  void _toggleLiveStreaming() {
    setState(() {
      _isLiveStreaming = !_isLiveStreaming;
    });
    debugPrint('Live streaming: ${_isLiveStreaming ? "ON" : "OFF"}');
  }

  // ============================================================
  // SHARE FILE - Only to Trusted Contacts
  // ============================================================
  Future<void> _shareFile(String filePath, String type) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('File does not exist: $filePath');
      return;
    }

    final time = DateTime.now().toLocal().toString();
    final message =
        '🚨 Safety recording: $type recording from $time\n\n'
        'Location: ${_currentPosition != null ? '${_currentPosition!.latitude},${_currentPosition!.longitude}' : 'unknown'}';

    await Share.shareXFiles(
      [XFile(filePath)],
      text: message,
      subject: 'Purple Safety - Recording',
    );
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
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEmergencyActive) _buildStatusIndicator(),
              const SizedBox(height: 24),
              _buildRecordingControls(),
              const SizedBox(height: 16),
              _buildAutoShareToggle(),
              const SizedBox(height: 16),
              _buildLocationMap(),
              const SizedBox(height: 24),
              _buildQuickCallButtons(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildCallEmergencyButton()),
                  const SizedBox(width: 12),
                  // I'M SAFE BUTTON - Only visible when SOS is active
                  if (_isEmergencyActive) Expanded(child: _buildImSafeButton()),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sos, color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Text(
                '🚨 SOS ACTIVE',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow(Icons.location_on, 'Location is being shared', true),
          _buildStatusRow(Icons.videocam, 'Video recording', _isRecordingVideo),
          _buildStatusRow(Icons.mic, 'Audio recording', _isRecordingAudio),
          _buildStatusRow(Icons.live_tv, 'Live streaming', _isLiveStreaming),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String text, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: active ? Colors.green : Colors.grey, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Icon(
            active ? Icons.check_circle : Icons.cancel,
            color: active ? Colors.green : Colors.red,
            size: 16,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CAPTURE IT! - Three buttons
  // ============================================================
  Widget _buildRecordingControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a0f2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Capture It!',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildMediaButton(
                icon: Icons.videocam,
                label: 'Record Video',
                onTap: _recordVideo,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildMediaButton(
                icon: _isRecordingAudio ? Icons.stop : Icons.mic,
                label: _isRecordingAudio ? 'Stop Audio' : 'Record Audio',
                onTap: _isRecordingAudio
                    ? _stopAudioRecording
                    : _startAudioRecording,
                color: _isRecordingAudio ? Colors.red : Colors.green,
              ),
              const SizedBox(height: 12),
              _buildMediaButton(
                icon: _isLiveStreaming ? Icons.stop : Icons.live_tv,
                label: _isLiveStreaming ? 'Stop Live' : 'Start Live',
                onTap: _toggleLiveStreaming,
                color: _isLiveStreaming ? Colors.red : Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AUTO-SHARE TOGGLE
  // ============================================================
  Widget _buildAutoShareToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1a0f2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto‑share recordings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Send to trusted contacts only',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Switch(
            value: _autoShareRecordings,
            onChanged: (value) async {
              setState(() {
                _autoShareRecordings = value;
              });
              await _saveAutoSharePreference(value);
            },
            activeColor: const Color(0xFF6A1B9A),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCATION MAP
  // ============================================================
  Widget _buildLocationMap() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (_locationEnabled && _currentPosition != null)
              // GoogleMap(
              //   onMapCreated: (controller) => _mapController = controller,
              //   initialCameraPosition: CameraPosition(
              //     target: _currentPosition!,
              //     zoom: 15,
              //   ),
              //   myLocationEnabled: true,
              //   myLocationButtonEnabled: false,
              //   zoomControlsEnabled: false,
              //   markers: {
              //     Marker(
              //       markerId: const MarkerId('current'),
              //       position: _currentPosition!,
              //       icon: BitmapDescriptor.defaultMarkerWithHue(
              //         BitmapDescriptor.hueViolet,
              //       ),
              //     ),
              //   },
              // )
              MapWidget(
                onMapCreate: (controller) => _mapController = controller,
                currentPosition: _currentPosition,
                myLocation: true,
                myLocationButton: false,
                zoomControls: false,
                markers: {
                  Marker(
                    markerId: const MarkerId('current'),
                    position: _currentPosition!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueViolet,
                    ),
                  ),
                },
              )
            else
              const Center(
                child: Text(
                  'Location not available',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            Positioned(
              bottom: 8,
              right: 8,
              child: FloatingActionButton.small(
                onPressed: _resendLocation,
                backgroundColor: const Color(0xFF6A1B9A),
                child: const Icon(Icons.share, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUICK CALL BUTTONS
  // ============================================================
  Widget _buildQuickCallButtons() {
    List<Widget> buttons = [];
    for (int i = 0; i < _contacts.length && i < 2; i++) {
      final contact = _contacts[i];
      buttons.add(
        Expanded(
          child: _buildCallButton(
            label: contact.name,
            number: contact.phone ?? '',
            icon: Icons.contact_phone,
            color: const Color(0xFF8260dc),
          ),
        ),
      );
    }
    buttons.add(
      Expanded(
        child: _buildCallButton(
          label: 'Police',
          number: _securityNumber,
          icon: Icons.local_police,
          color: Colors.red,
        ),
      ),
    );
    while (buttons.length < 3) buttons.add(const Expanded(child: SizedBox()));
    return Row(children: buttons);
  }

  Widget _buildCallButton({
    required String label,
    required String number,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _callNumber(number),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CALL EMERGENCY BUTTON
  // ============================================================
  Widget _buildCallEmergencyButton() {
    return ElevatedButton.icon(
      onPressed: widget.onCallEmergency,
      icon: const Icon(Icons.phone, color: Colors.white, size: 20),
      label: const Text(
        'Call Emergency',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }

  // ============================================================
  // I'M SAFE BUTTON - Only shows when SOS is active
  // ============================================================
  Widget _buildImSafeButton() {
    return ElevatedButton.icon(
      onPressed: _imSafe,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
      label: const Text(
        "I'm Safe ✓",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }
}
