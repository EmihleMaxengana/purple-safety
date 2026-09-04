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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';
import 'package:purple_safety/safety/biometric_services.dart';
import 'package:purple_safety/services/location_sharing_service.dart';
import 'package:purple_safety/emergency/sos_alert_service.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/contacts/firestore_service.dart';
import 'package:purple_safety/models/incident_model.dart';
import 'package:purple_safety/map/map.dart';
import 'package:purple_safety/services/storage_service.dart';

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
  bool _autoShareRecordings = false;
  bool _isCameraActive = false;
  bool _isUploading = false;

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
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAutoSharePreference();
    _listenToEmergencyStatus();
    _loadContacts();
    _initLocation();
    _syncEmergencyStateFromBackend();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isCameraActive) {
        debugPrint('Preserving tab: returned from native camera picker.');
        return;
      }
      _syncEmergencyStateFromBackend();
    }
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
      });
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

  Future<void> _resendLocation() async {}

  Future<void> _callNumber(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint('Could not call $number');
    }
  }

  Future<void> _imSafe() async {
    if (!_isEmergencyActive) return;

    final authenticated = await BiometricService.authenticateWithUserPreference(
      context: context,
      reason: 'Confirm you are safe to deactivate SOS',
    );

    if (!authenticated) return;

    final user = AuthService().getCurrentUser();
    String userName = 'Someone';
    String? userId = user?.uid;
    if (user != null) {
      final userData = await AuthService().getUserData(user.uid);
      userName = userData?['name'] ?? 'A user';
      userId = user.uid;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('active_sos_events')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in querySnapshot.docs) {
        await SOSAlertService.deactivateSOSEvent(
          doc.id,
          userId: userId,
          finalLat: _currentPosition?.latitude,
          finalLng: _currentPosition?.longitude,
        );
        debugPrint('Deactivated SOS event: ${doc.id}');
      }
    } catch (e) {
      debugPrint('Error deactivating SOS event: $e');
    }

    if (LocationSharingService.isSharing) {
      LocationSharingService.stopSharing();
    }

    if (_isRecordingAudio) {
      await _stopAudioRecording();
    }

    await _sendGlobalSafeAlert(userName, userId);

    EmergencyManager().deactivateEmergencyMode();

    setState(() {
      _isEmergencyActive = false;
    });

    _showSafeConfirmationDialog();
  }

  Future<void> _sendGlobalSafeAlert(
    String userName,
    String? currentUserId,
  ) async {
    try {
      final locationLink = _currentPosition != null
          ? 'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          : 'Location unavailable';

      final message =
          'SAFE UPDATE: $userName has confirmed they are safe. SOS has been deactivated. Final location: $locationLink';

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

  void _showPopup(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Info'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showShareSheet({
    required File file,
    required String type,
    required String localPath,
    String? storageUrl,
  }) {
    final String shareMessage = 'Emergency evidence captured via Purple Safety';
    
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
            const Icon(Icons.share, color: Color(0xFFBF7DCB), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Share Evidence',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this $type with your trusted contacts or outside the app',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            
            if (_contacts.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _shareWithTrustedContacts(
                      type: type,
                      localPath: localPath,
                      storageUrl: storageUrl,
                    );
                  },
                  icon: const Icon(Icons.people, color: Colors.white),
                  label: const Text(
                    'Share with Trusted Contacts',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            
            if (_contacts.isNotEmpty) const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _shareOutsideApp(
                    file: file,
                    type: type,
                    message: shareMessage,
                  );
                },
                icon: const Icon(Icons.share, color: Color(0xFFBF7DCB)),
                label: const Text(
                  'Share Outside App',
                  style: TextStyle(color: Color(0xFFBF7DCB)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBF7DCB)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareWithTrustedContacts({
    required String type,
    required String localPath,
    String? storageUrl,
  }) async {
    final user = AuthService().getCurrentUser();
    if (user == null) {
      _showPopup(context, 'You must be logged in');
      return;
    }

    final userData = await AuthService().getUserData(user.uid);
    final userName = userData?['name'] ?? 'User';

    await _shareMediaWithContacts(
      type: type,
      localPath: localPath,
      storageUrl: storageUrl,
      userName: userName,
    );
    
    _showPopup(context, 'Shared with ${_contacts.length} trusted contacts');
  }

  Future<void> _shareOutsideApp({
    required File file,
    required String type,
    required String message,
  }) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: message,
      subject: 'Purple Safety - $type',
    );
  }

  Future<void> _takePhoto() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _showPopup(context, 'Camera permission is required to take photos');
      return;
    }

    setState(() {
      _isCameraActive = true;
      EmergencyManager().isCameraActive = true;
    });
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 1200,
    );
    setState(() {
      _isCameraActive = false;
      EmergencyManager().isCameraActive = false;
    });

    if (photo == null) return;

    setState(() => _isUploading = true);

    final file = File(photo.path);
    final user = AuthService().getCurrentUser();

    if (user == null) {
      setState(() => _isUploading = false);
      _showPopup(context, 'You must be logged in');
      return;
    }

    final userData = await AuthService().getUserData(user.uid);
    final userName = userData?['name'] ?? 'User';

    final String localPath = await _saveToLocalStorage(file, 'photo');

    String? storageUrl;
    try {
      storageUrl = await StorageService.uploadRecording(
        file: file,
        userId: user.uid,
        subFolder: _isEmergencyActive ? 'sos' : 'recordings',
      );
    } catch (e) {
      debugPrint('Failed to upload photo to storage: $e');
    }

    await _saveToFirestore(
      type: 'photo',
      localPath: localPath,
      storageUrl: storageUrl,
      userName: userName,
      userId: user.uid,
    );

    setState(() => _isUploading = false);

    _showPhotoSavedDialog(
      file: file,
      type: 'photo',
      localPath: localPath,
      storageUrl: storageUrl,
    );
  }

  Future<void> _recordVideo() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _showPopup(context, 'Camera permission is required');
      return;
    }

    setState(() {
      _isCameraActive = true;
      EmergencyManager().isCameraActive = true;
    });
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 15),
    );
    setState(() {
      _isCameraActive = false;
      EmergencyManager().isCameraActive = false;
    });

    if (video == null) return;

    setState(() => _isUploading = true);

    final file = File(video.path);
    final user = AuthService().getCurrentUser();

    if (user == null) {
      setState(() => _isUploading = false);
      _showPopup(context, 'You must be logged in');
      return;
    }

    final userData = await AuthService().getUserData(user.uid);
    final userName = userData?['name'] ?? 'User';

    final String localPath = await _saveToLocalStorage(file, 'video');

    String? storageUrl;
    try {
      storageUrl = await StorageService.uploadRecording(
        file: file,
        userId: user.uid,
        subFolder: _isEmergencyActive ? 'sos' : 'recordings',
      );
    } catch (e) {
      debugPrint('Failed to upload video to storage: $e');
    }

    await _saveToFirestore(
      type: 'video',
      localPath: localPath,
      storageUrl: storageUrl,
      userName: userName,
      userId: user.uid,
    );

    setState(() => _isUploading = false);

    _showVideoSavedDialog(
      file: file,
      type: 'video',
      localPath: localPath,
      storageUrl: storageUrl,
    );
  }

  Future<void> _startAudioRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _showPopup(context, 'Microphone permission is required');
      return;
    }

    if (await _audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
        setState(() => _isUploading = true);

        final file = File(path);
        final user = AuthService().getCurrentUser();

        if (user != null) {
          final userData = await AuthService().getUserData(user.uid);
          final userName = userData?['name'] ?? 'User';

          final localPath = path;

          String? storageUrl;
          try {
            storageUrl = await StorageService.uploadRecording(
              file: file,
              userId: user.uid,
              subFolder: _isEmergencyActive ? 'sos' : 'recordings',
            );
          } catch (e) {
            debugPrint('Failed to upload audio to storage: $e');
          }

          await _saveToFirestore(
            type: 'audio',
            localPath: localPath,
            storageUrl: storageUrl,
            userName: userName,
            userId: user.uid,
          );

          setState(() => _isUploading = false);

          _showAudioSavedDialog(
            file: file,
            type: 'audio',
            localPath: localPath,
            storageUrl: storageUrl,
          );
        } else {
          setState(() => _isUploading = false);
          _showPopup(context, 'You must be logged in');
        }
      }
    }
  }

  void _showPhotoSavedDialog({
    required File file,
    required String type,
    required String localPath,
    String? storageUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1a0f2e),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt,
                color: Colors.blue,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Photo Saved',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your photo evidence has been saved.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _takePhoto();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Future.delayed(Duration.zero, () {
                          if (!mounted) return;
                          if (_autoShareRecordings) {
                            _showPopup(context, 'Photo saved and shared with trusted contacts');
                          } else {
                            _showShareSheet(
                              file: file,
                              type: type,
                              localPath: localPath,
                              storageUrl: storageUrl,
                            );
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoSavedDialog({
    required File file,
    required String type,
    required String localPath,
    String? storageUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1a0f2e),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam,
                color: Colors.blue,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Video Saved',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your video evidence has been saved.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _recordVideo();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Future.delayed(Duration.zero, () {
                          if (!mounted) return;
                          if (_autoShareRecordings) {
                            _showPopup(context, 'Video saved and shared with trusted contacts');
                          } else {
                            _showShareSheet(
                              file: file,
                              type: type,
                              localPath: localPath,
                              storageUrl: storageUrl,
                            );
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAudioSavedDialog({
    required File file,
    required String type,
    required String localPath,
    String? storageUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1a0f2e),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mic,
                color: Colors.green,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Audio Recording Saved',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your audio evidence has been saved.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _startAudioRecording();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Future.delayed(Duration.zero, () {
                          if (!mounted) return;
                          if (_autoShareRecordings) {
                            _showPopup(context, 'Audio saved and shared with trusted contacts');
                          } else {
                            _showShareSheet(
                              file: file,
                              type: type,
                              localPath: localPath,
                              storageUrl: storageUrl,
                            );
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _saveToLocalStorage(File file, String type) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${type}_$timestamp.${file.path.split('.').last}';
      final localPath = '${directory.path}/$fileName';
      await file.copy(localPath);
      debugPrint('Saved locally: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('Error saving locally: $e');
      return file.path;
    }
  }

  Future<void> _saveToFirestore({
    required String type,
    required String localPath,
    String? storageUrl,
    required String userName,
    required String userId,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'type': type,
        'localPath': localPath,
        'storageUrl': storageUrl ?? '',
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'locationLink': _currentPosition != null
            ? 'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            : null,
        'sharedWithContacts': _autoShareRecordings,
        'isSOS': _isEmergencyActive,
      };

      await FirebaseFirestore.instance.collection('user_media').add(data);

      debugPrint('Saved to Firestore: $type');
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
    }
  }

  Future<void> _shareMediaWithContacts({
    required String type,
    required String localPath,
    String? storageUrl,
    required String userName,
  }) async {
    if (_contacts.isEmpty) {
      debugPrint('No trusted contacts to share with');
      return;
    }

    final currentUser = AuthService().getCurrentUser();
    if (currentUser == null) return;

    for (var contact in _contacts) {
      if (contact.id == currentUser.uid) continue;

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(contact.id)
            .collection('alerts')
            .add({
              'message': '$userName shared a $type with you. Tap to view.',
              'type': 'media_share',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'mediaType': type,
              'mediaUrl': storageUrl ?? localPath,
              'userName': userName,
              'userId': currentUser.uid,
            });
      } catch (e) {
        debugPrint('Error sending alert to ${contact.name}: $e');
      }
    }

    debugPrint('Shared $type with ${_contacts.length} contacts');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEmergencyActive) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                color: Colors.white38,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Safety Tools Locked',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Safety Tools are only available during an active SOS emergency.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please trigger SOS from the Home screen first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
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
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      Expanded(child: _buildImSafeButton()),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
        if (_isUploading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Saving evidence...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
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
                icon: Icons.camera_alt,
                label: 'Take Photo',
                onTap: _takePhoto,
                color: Colors.purple,
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
                'Auto-share recordings',
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

  Widget _buildLocationMap() {
    if (!_locationEnabled || _currentPosition == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        child: const Center(
          child: Text(
            'Location not available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

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
            MapWidget(
              currentPosition: _currentPosition!,
              onMapCreate: (controller) => _mapController = controller,
              myLocation: false,
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
            ),
            Positioned(
              bottom: 8,
              left: 8,
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

  Widget _buildImSafeButton() {
    return ElevatedButton.icon(
      onPressed: _imSafe,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
      label: const Text(
        "I'm Safe",
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