import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purple_safety/authentication/otp_service.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/navigation/main_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final String password;
  final String phone;
  final String? nextOfKinName;
  final String? nextOfKinPhone;
  final String? nextOfKinRelation;
  final String? nextOfKinAltPhone;
  final String? gender;

  const OTPVerificationScreen({
    Key? key,
    required this.email,
    required this.fullName,
    required this.password,
    required this.phone,
    this.nextOfKinName,
    this.nextOfKinPhone,
    this.nextOfKinRelation,
    this.nextOfKinAltPhone,
    this.gender,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  late TextEditingController _otpController;
  bool _isLoading = false;
  bool _isVerified = false;
  String _errorMessage = '';
  Timer? _countdownTimer;
  int _remainingSeconds = 600; // 10 minutes
  int _attemptsRemaining = 5;

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
    _sendOTP();
    _startCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await OTPService.sendOTPForRegistration(widget.email);

    setState(() {
      _isLoading = false;
    });

    if (result?['success'] != true) {
      setState(() {
        _errorMessage = result?['message'] ?? 'Failed to send OTP. Please try again.';
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        timer.cancel();
        setState(() {
          _errorMessage = 'OTP has expired. Please request a new one.';
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit OTP.';
      });
      return;
    }

    if (otp.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Verify OTP
      final verifyResult = await OTPService.verifyOTP(widget.email, otp);

      if (verifyResult['success'] != true) {
        setState(() {
          _isLoading = false;
          _errorMessage = verifyResult['message'] ?? 'Invalid OTP.';
          if (verifyResult.containsKey('attemptsRemaining')) {
            _attemptsRemaining = verifyResult['attemptsRemaining'] ?? 0;
          }
        });
        return;
      }

      // OTP verified! Now register the user
      setState(() {
        _isVerified = true;
      });
      _countdownTimer?.cancel();

      final authService = AuthService();
      final user = await authService.registerWithEmail(
        widget.fullName,
        widget.email,
        widget.password,
        widget.phone,
        nextOfKinName: widget.nextOfKinName,
        nextOfKinPhone: widget.nextOfKinPhone,
        nextOfKinRelation: widget.nextOfKinRelation,
        nextOfKinAltPhone: widget.nextOfKinAltPhone,
        gender: widget.gender,
      );

      if (user != null) {
        // Clean up OTP after successful registration
        await OTPService.cleanupOTP(widget.email);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Registration failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _otpController.clear();
    });

    final result = await OTPService.resendOTP(widget.email);

    setState(() {
      _isLoading = false;
      _remainingSeconds = 600; // Reset timer
      _attemptsRemaining = 5; // Reset attempts
    });

    _countdownTimer?.cancel();
    _startCountdown();

    if (result?['success'] != true) {
      setState(() {
        _errorMessage = result?['message'] ?? 'Failed to resend OTP.';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        elevation: 0,
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
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Icon
                      const Icon(
                        Icons.security,
                        size: 60,
                        color: Color(0xFFD105FF),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      const Text(
                        'Verify Your Email',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Email Display
                      Text(
                        'We sent a 6-digit code to:\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // OTP Input Field
                      TextField(
                        controller: _otpController,
                        enabled: !_isLoading && !_isVerified,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 10,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 32,
                            letterSpacing: 10,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD105FF),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          if (value.length == 6) {
                            _verifyOTP();
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Timer and Error Messages
                      if (!_isVerified)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Expires in: ${_formatTime(_remainingSeconds)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_attemptsRemaining < 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Attempts remaining: $_attemptsRemaining',
                                  style: TextStyle(
                                    color: _attemptsRemaining <= 1
                                        ? Colors.red
                                        : Colors.yellow,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),

                      // Error Message
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Verify Button
                      if (!_isVerified)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  (_isLoading || _otpController.text.length != 6)
                                      ? null
                                      : _verifyOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD105FF),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFFD105FF).withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Verify OTP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                      // Success Message
                      if (_isVerified)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 60,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'OTP Verified!',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Completing registration...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Resend Button
                      if (!_isVerified && _remainingSeconds <= 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _resendOTP,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFD105FF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Resend OTP',
                                style: TextStyle(
                                  color: Color(0xFFD105FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (!_isVerified && _remainingSeconds > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: TextButton(
                            onPressed: _isLoading ? null : _resendOTP,
                            child: const Text(
                              'Resend OTP',
                              style: TextStyle(
                                color: Color(0xFFCCCCFF),
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
      ),
    );
  }
}