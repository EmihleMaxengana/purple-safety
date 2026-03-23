import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class SafetyToolsScreen extends StatefulWidget {
  final VoidCallback onCallEmergency;
  const SafetyToolsScreen({Key? key, required this.onCallEmergency})
    : super(key: key);

  @override
  State<SafetyToolsScreen> createState() => _SafetyToolsScreenState();
}

class _SafetyToolsScreenState extends State<SafetyToolsScreen> {
  bool _isSharingLocation = true; // simulate sharing
  bool _isRecordingAudio = true; // simulate recording
  bool _isRecordingVideo = false; // simulate
  String _locationLink =
      'https://maps.google.com/?q=-26.2041,28.0473'; // placeholder

  void _stopSharing() {
    setState(() {
      _isSharingLocation = false;
    });
    // actual stop sharing logic would go here
  }

  void _copyLocationLink() {
    // copy to clipboard
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Location link copied!')));
  }

  void _stopAudioRecording() {
    setState(() {
      _isRecordingAudio = false;
    });
  }

  void _stopVideoRecording() {
    setState(() {
      _isRecordingVideo = false;
    });
  }

  void _takePhotoSilently() {
    // simulate taking photo
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Photo taken silently')));
  }

  void _soundAlarm() {
    // play sound
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Alarm sounding!')));
  }

  void _alertTrustedContacts() {
    // send alert
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert sent to trusted contacts')),
    );
  }

  void _sendSilentSOS() {
    // discreet alert
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Silent SOS sent')));
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
              // Emergency Mode Active header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ EMERGENCY MODE ACTIVE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sending alerts... Contacts notified 5s ago',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Location sharing ON',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Call Emergency Services
              ElevatedButton.icon(
                onPressed: widget.onCallEmergency,
                icon: const Icon(Icons.phone, color: Colors.white),
                label: const Text('Call Emergency Services'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Alert Trusted Contacts
              ElevatedButton.icon(
                onPressed: _alertTrustedContacts,
                icon: const Icon(Icons.people, color: Colors.white),
                label: const Text('Alert Trusted Contacts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Send Silent SOS
              ElevatedButton.icon(
                onPressed: _sendSilentSOS,
                icon: const Icon(Icons.notifications_off, color: Colors.white),
                label: const Text('Send Silent SOS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A0072),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Copy Location Link
              OutlinedButton.icon(
                onPressed: _copyLocationLink,
                icon: const Icon(Icons.copy, color: Colors.white70),
                label: const Text('Copy Location Link'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  foregroundColor: Colors.white70,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Live location shared section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a0f2e),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Live location shared with contacts',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: _stopSharing,
                          child: const Text(
                            'Stop Sharing →',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        TextButton(
                          onPressed: _copyLocationLink,
                          child: const Text(
                            'Copy Location Link',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recording section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a0f2e),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mic, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Recording in progress...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const Text(
                      'Audio recording active',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton(
                          onPressed: _stopVideoRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Stop Video Recording'),
                        ),
                        ElevatedButton(
                          onPressed: _stopAudioRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Stop Audio Recording'),
                        ),
                        ElevatedButton(
                          onPressed: _takePhotoSilently,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                          ),
                          child: const Text('Take Photo Silently'),
                        ),
                        ElevatedButton(
                          onPressed: _soundAlarm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                          ),
                          child: const Text('Sound Alarm'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Calming footer
              const Center(
                child: Text(
                  'Stay calm. Help is on the way.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
