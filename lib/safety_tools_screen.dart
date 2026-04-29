import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purple_safety/home/home_screen.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';

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
  bool _isSilentMode = false;
  bool _isRecordingAudio = false;
  bool _isRecordingVideo = false;
  bool _autoShareRecordings = false;

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  // Live streaming
  bool _isLiveStreaming = false;
  CameraController? _cameraController;
  String? _streamUrl;
  String? _liveStreamRoomId;

  location.Location _location = location.Location();
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  StreamSubscription<location.LocationData>? _locationSubscription;
  bool _locationEnabled = false;

  List<Contact> _contacts = [];
  String _securityNumber = '10111';

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
    _stopLiveStreaming();
    _locationSubscription?.cancel();
    _audioRecorder.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _cameraController != null) {
      _cameraController!.dispose();
      _cameraController = null;
    }
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
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please enable location services to use this feature.',
              ),
            ),
          );
        }
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
    if (_currentPosition != null && _contacts.isNotEmpty) {
      final link =
          'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location link ready to share')),
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

  // ---------- Audio Recording ----------
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔴 Audio recording started')),
      );
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

        await _shareFile(path, 'audio');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save audio recording')),
        );
      }
    }
  }

  // ---------- Video Recording ----------
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
      setState(() => _isRecordingVideo = false);
    }
  }

  // ---------- Live Streaming ----------
  Future<void> _startLiveStreaming() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera permission denied')));
      return;
    }
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No camera available')));
      return;
    }

    final camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(camera, ResolutionPreset.medium);
    try {
      await _cameraController!.initialize();
      await _cameraController!.startImageStream((CameraImage image) {});
      setState(() {
        _isLiveStreaming = true;
      });
      debugPrint('Live streaming started');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Live stream started')));

      _liveStreamRoomId = DateTime.now().millisecondsSinceEpoch.toString();
      _streamUrl = 'https://live.purplesafety.com/room/$_liveStreamRoomId';

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream ready to share')),
      );
    } catch (e) {
      debugPrint('Failed to start camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start live stream')),
      );
      _cameraController = null;
    }
  }

  Future<void> _stopLiveStreaming() async {
    if (_cameraController != null) {
      await _cameraController!.stopImageStream();
      await _cameraController!.dispose();
      _cameraController = null;
    }
    setState(() {
      _isLiveStreaming = false;
      _streamUrl = null;
      _liveStreamRoomId = null;
    });
    debugPrint('Live stream stopped');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Live stream ended')));
  }

  // ---------- Sharing ----------
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

  Future<bool> _showSharePrompt(String type) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('$type recorded'),
            content: const Text('Do you want to share it?'),
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

  void _stopEmergency() {
    if (_isRecordingAudio) {
      _stopAudioRecording();
    }
    if (_isLiveStreaming) {
      _stopLiveStreaming();
    }
  }

  // ---------- Build UI ----------
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
              const SizedBox(height: 24),
              if (_isLiveStreaming && _cameraController != null)
                _buildLivePreview(),
              const SizedBox(height: 24),
              _buildLocationMap(),
              const SizedBox(height: 24),
              _buildQuickCallButtons(),
              const SizedBox(height: 24),
              _buildSilentModeToggle(),
              const SizedBox(height: 24),
              _buildCallEmergencyButton(),
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
            'Record & Stream',
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
                icon: _isLiveStreaming ? Icons.stop_circle : Icons.live_tv,
                label: _isLiveStreaming ? 'Stop Live' : 'Go Live',
                onTap: _isLiveStreaming
                    ? _stopLiveStreaming
                    : _startLiveStreaming,
                color: _isLiveStreaming ? Colors.red : Colors.purple,
              ),
              const SizedBox(height: 12),
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

  Widget _buildLivePreview() {
    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CameraPreview(_cameraController!),
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
                'Send video/audio automatically',
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

  Widget _buildCallEmergencyButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: widget.onCallEmergency,
        icon: const Icon(Icons.phone, color: Colors.white),
        label: const Text(
          'Call Emergency Services',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );    
  }
}