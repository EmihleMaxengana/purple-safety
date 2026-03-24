import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:io';
import 'home/home_screen.dart';
import 'services/location_sharing_service.dart';
import 'services/sos_alert_service.dart';
import 'emergency/emergency_manager.dart';

class SafetyToolsScreen extends StatefulWidget {
  final VoidCallback onCallEmergency;
  const SafetyToolsScreen({Key? key, required this.onCallEmergency})
    : super(key: key);

  @override
  State<SafetyToolsScreen> createState() => _SafetyToolsScreenState();
}

class _SafetyToolsScreenState extends State<SafetyToolsScreen> {
  // Emergency state
  bool _isEmergencyActive = true;
  bool _isSilentMode = false;
  bool _isRecordingAudio = false;
  bool _isRecordingVideo = false;
  bool _isFlashlightStrobe = false;
  bool _autoShareRecordings = true;
  Timer? _flashlightTimer;

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  // Location
  location.Location _location = location.Location();
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  StreamSubscription<location.LocationData>? _locationSubscription;
  bool _locationEnabled = false;

  // Contacts
  List<Contact> _contacts = [];
  String _securityNumber = '10111'; // Police

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _initLocation();
    _sendInitialAlerts();
  }

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
      if (!serviceEnabled) return;
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == location.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != location.PermissionStatus.granted) return;
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

  void _sendInitialAlerts() async {
    if (_contacts.isNotEmpty && _currentPosition != null) {
      final link =
          'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      await SOSAlertService.sendAlerts(_contacts, link);
      debugPrint('Initial SOS alerts resent');
    }
  }

  Future<void> _resendLocation() async {
    if (_currentPosition != null && _contacts.isNotEmpty) {
      final link =
          'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      await SOSAlertService.sendAlerts(_contacts, link);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location resent to contacts')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available yet')),
      );
    }
  }

  Future<void> _callNumber(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint('Could not call $number');
    }
  }

  void _triggerLoudAlarm() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🔊 Loud alarm triggered!')));
    debugPrint('Loud alarm');
  }

  void _toggleFlashlightStrobe() async {
    setState(() {
      _isFlashlightStrobe = !_isFlashlightStrobe;
    });
    if (_isFlashlightStrobe) {
      _flashlightTimer = Timer.periodic(const Duration(milliseconds: 200), (
        timer,
      ) {
        debugPrint('Flashlight strobe');
      });
    } else {
      _flashlightTimer?.cancel();
    }
  }

  void _fakeCall() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('📞 Fake call started!')));
    debugPrint('Fake call');
  }

  // -------------------------------------------------------------------
  // Video recording using camera with share option
  // -------------------------------------------------------------------
  Future<void> _recordVideo() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera permission denied')));
      return;
    }

    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      setState(() {
        _isRecordingVideo = true;
      });
      debugPrint('Video recorded: ${video.path}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video recorded successfully')),
      );

      if (_autoShareRecordings) {
        await _shareFile(video.path, 'video');
      } else {
        final shouldShare = await _showSharePrompt('Video');
        if (shouldShare) {
          await _shareFile(video.path, 'video');
        }
      }
    }
  }

  // -------------------------------------------------------------------
  // Audio recording (in‑app) with share option
  // -------------------------------------------------------------------
  Future<void> _startAudioRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Audio recording started')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot access microphone')));
    }
  }

  Future<void> _stopAudioRecording() async {
    if (_isRecordingAudio && await _audioRecorder.isRecording()) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecordingAudio = false);

      if (path != null) {
        debugPrint('Audio recording saved at: $path');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Audio recording saved')));

        if (_autoShareRecordings) {
          await _shareFile(path, 'audio');
        } else {
          final shouldShare = await _showSharePrompt('Audio');
          if (shouldShare) {
            await _shareFile(path, 'audio');
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save audio recording')),
        );
      }
    }
  }

  // -------------------------------------------------------------------
  // Share a file with trusted contacts using share_plus
  // -------------------------------------------------------------------
  Future<void> _shareFile(String filePath, String type) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('File does not exist: $filePath');
      return;
    }

    final time = DateTime.now().toLocal().toString();
    final message =
        '🚨 Emergency evidence: $type recording from $time\n\n'
        'Location: ${_currentPosition != null ? '${_currentPosition!.latitude},${_currentPosition!.longitude}' : 'unknown'}';

    await Share.shareXFiles(
      [XFile(filePath)],
      text: message,
      subject: 'Purple Safety - Emergency Evidence',
    );
  }

  Future<bool> _showSharePrompt(String type) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('$type recorded'),
            content: const Text(
              'Do you want to share it with your trusted contacts?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // -------------------------------------------------------------------
  // I'm Safe functionality
  // -------------------------------------------------------------------
  Future<void> _imSafe() async {
    bool authenticated = false;
    try {
      final localAuth = LocalAuthentication();
      authenticated = await localAuth.authenticate(
        localizedReason: 'Confirm you are safe to deactivate SOS',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Auth error: $e');
      authenticated = await _showPinDialog();
    }

    if (authenticated) {
      _stopEmergency();
      await _sendSafeMessage();
      EmergencyManager().deactivateEmergencyMode();
      setState(() {
        _isEmergencyActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ You are marked safe. SOS deactivated.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed. SOS remains active.'),
        ),
      );
    }
  }

  Future<bool> _showPinDialog() async {
    String? pin;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter PIN to confirm safe'),
        content: TextField(
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          onChanged: (value) => pin = value,
          decoration: const InputDecoration(hintText: '1234'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, pin == '1234'),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return pin == '1234';
  }

  void _stopEmergency() {
    LocationSharingService.stopSharing();
    if (_isRecordingAudio) {
      _stopAudioRecording();
    }
    _flashlightTimer?.cancel();
  }

  Future<void> _sendSafeMessage() async {
    if (_contacts.isNotEmpty) {
      final message = 'I am safe now. SOS deactivated.';
      for (var contact in _contacts) {
        await SOSAlertService.sendSMS(contact.phone!, message);
        if (contact.socialLinks.containsKey('whatsapp')) {
          await SOSAlertService.sendWhatsApp(contact, message);
        }
      }
      debugPrint('Safe message sent to contacts');
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _flashlightTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // UI Build
  // -------------------------------------------------------------------
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
              // Status Indicator
              _buildStatusIndicator(),
              const SizedBox(height: 24),

              // Recording Controls
              _buildRecordingControls(),
              const SizedBox(height: 16),

              // Auto‑share Toggle
              _buildAutoShareToggle(),
              const SizedBox(height: 24),

              // Live Location Map
              _buildLocationMap(),
              const SizedBox(height: 24),

              // Quick Call Buttons
              _buildQuickCallButtons(),
              const SizedBox(height: 24),

              // Attention Tools
              _buildAttentionTools(),
              const SizedBox(height: 24),

              // Silent Mode Toggle
              _buildSilentModeToggle(),
              const SizedBox(height: 24),

              // I'm Safe Button
              _buildImSafeButton(),
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
          _buildStatusRow(Icons.notifications_active, 'Alert sent', true),
          _buildStatusRow(Icons.videocam, 'Video recording', _isRecordingVideo),
          _buildStatusRow(Icons.mic, 'Audio recording', _isRecordingAudio),
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
            'Record Evidence',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRecordButton(
                icon: Icons.videocam,
                label: 'Video',
                onTap: _recordVideo,
                color: Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildRecordButton(
                icon: Icons.mic,
                label: _isRecordingAudio ? 'Stop Audio' : 'Audio',
                onTap: _isRecordingAudio
                    ? _stopAudioRecording
                    : _startAudioRecording,
                color: _isRecordingAudio ? Colors.red : Colors.green,
              ),
            ],
          ),
          if (_isRecordingAudio) ...[
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fiber_manual_record,
                    color: Colors.red,
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Recording audio...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

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
                'Send video/audio to contacts automatically',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Switch(
            value: _autoShareRecordings,
            onChanged: (value) => setState(() => _autoShareRecordings = value),
            activeColor: const Color(0xFF6A1B9A),
          ),
        ],
      ),
    );
  }

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
              GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition: CameraPosition(
                  target: _currentPosition!,
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
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
    while (buttons.length < 3) {
      buttons.add(const Expanded(child: SizedBox()));
    }
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

  Widget _buildAttentionTools() {
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
            'Attention Tools',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttentionButton(
                icon: Icons.volume_up,
                label: 'Loud Alarm',
                onTap: _triggerLoudAlarm,
                color: Colors.orange,
              ),
              _buildAttentionButton(
                icon: Icons.flash_on,
                label: 'Flashlight Strobe',
                onTap: _toggleFlashlightStrobe,
                color: Colors.yellow,
                isActive: _isFlashlightStrobe,
              ),
              _buildAttentionButton(
                icon: Icons.phone_iphone,
                label: 'Fake Call',
                onTap: _fakeCall,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.3) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isActive ? 0.8 : 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSilentModeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                'Silent Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Stealth mode: no alarm sounds',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Switch(
            value: _isSilentMode,
            onChanged: (value) {
              setState(() => _isSilentMode = value);
              debugPrint('Silent mode: $_isSilentMode');
            },
            activeColor: const Color(0xFF6A1B9A),
          ),
        ],
      ),
    );
  }

  Widget _buildImSafeButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _imSafe,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'I\'m Safe ✓',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
