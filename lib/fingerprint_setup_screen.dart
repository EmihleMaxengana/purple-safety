import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purple_safety/services/biometric_services.dart';
import 'dart:ui'; // for ImageFilter
import 'main_screen.dart';

class FingerprintSetupScreen extends StatefulWidget {
  const FingerprintSetupScreen({Key? key}) : super(key: key);

  @override
  State<FingerprintSetupScreen> createState() => _FingerprintSetupScreenState();
}

class _FingerprintSetupScreenState extends State<FingerprintSetupScreen> {
  bool _isLoading = true;
  bool _fingerprintAvailable = false;
  bool _hasAnyBiometrics = false;
  bool _sosEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkFingerprintStatus();
  }

  Future<void> _checkFingerprintStatus() async {
    setState(() => _isLoading = true);

    final fingerprintAvail = await BiometricService.isFingerprintAvailable();
    final anyBiometrics = await BiometricService.hasAnyBiometrics();
    final sos = await BiometricService.isSOSFingerprintEnabled();

    setState(() {
      _fingerprintAvailable = fingerprintAvail;
      _hasAnyBiometrics = anyBiometrics;
      _sosEnabled = sos;
      _isLoading = false;
    });
  }

  Future<void> _setupSOSFingerprint() async {
    final success = await BiometricService.enableSOSFingerprint();
    if (success) {
      setState(() => _sosEnabled = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SOS fingerprint enabled!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS setup failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fingerprint Setup'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF800080), Color(0xFF4B0082)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.fingerprint,
                              size: 80,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'SOS Fingerprint Setup',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Set up a fingerprint to instantly trigger SOS in emergencies',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 30),

                            if (!_fingerprintAvailable)
                              _buildFingerprintUnavailableCard()
                            else
                              _buildSetupCard(
                                title: 'SOS Fingerprint',
                                description:
                                    'Use this fingerprint to instantly trigger emergency mode',
                                isEnabled: _sosEnabled,
                                icon: Icons.warning_amber_rounded,
                                onSetup: _setupSOSFingerprint,
                              ),

                            const SizedBox(height: 24),

                            if (_sosEnabled)
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const MainScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD105FF),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Continue to App'),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFingerprintUnavailableCard() {
    String message;
    if (!_hasAnyBiometrics) {
      message =
          'No fingerprint sensor found.\n\n'
          'Please ensure your device has a fingerprint sensor and that you have enrolled at least one fingerprint in your device settings.';
    } else {
      message =
          'Fingerprint is not available on this device.\n\n'
          'This app requires a fingerprint sensor. Your device may have face recognition, but we require fingerprint for security.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          Text(
            'Fingerprint Not Available',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // TODO: Open fingerprint settings (optional)
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupCard({
    required String title,
    required String description,
    required bool isEnabled,
    required IconData icon,
    required VoidCallback onSetup,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled
            ? Colors.green.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? Colors.green : Colors.orange.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isEnabled ? Colors.green : Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ENABLED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          if (!isEnabled) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSetup,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Setup SOS Fingerprint'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
