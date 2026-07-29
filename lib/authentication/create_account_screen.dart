import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:purple_safety/authentication/otp_verification_screen.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/utils/pref_keys.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({Key? key}) : super(key: key);

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  final _formKey = GlobalKey<FormState>();

  // name and surname
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();

  // email
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  bool _emailsMatch = false;
  bool _emailChecked = false;

  // phone
  final _phoneController = TextEditingController();

  // gender
  String? _selectedGender;
  final List<String> _genderOptions = ['Male', 'Female'];

  // next of kin
  final _nextOfKinNameController = TextEditingController();
  final _nextOfKinSurnameController = TextEditingController();
  final _nextOfKinPhoneController = TextEditingController();
  final _nextOfKinRelationController = TextEditingController();
  final _nextOfKinAltPhoneController = TextEditingController();

  // password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // pin
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _pinsMatch = false;
  bool _pinChecked = false;

  bool _useBiometrics = false;
  bool _isLoading = false;
  String _errorMessage = '';

  String _password = '';
  PasswordStrength _passwordStrength = PasswordStrength.weak;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _phoneController.dispose();
    _nextOfKinNameController.dispose();
    _nextOfKinSurnameController.dispose();
    _nextOfKinPhoneController.dispose();
    _nextOfKinRelationController.dispose();
    _nextOfKinAltPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  // auto-capitalize first letter while typing
  void _capitalizeWhileTyping(TextEditingController controller) {
    final text = controller.text;
    if (text.isNotEmpty) {
      final firstChar = text[0];
      if (firstChar != firstChar.toUpperCase()) {
        final capitalized = firstChar.toUpperCase() + text.substring(1);
        controller.value = TextEditingValue(
          text: capitalized,
          selection: TextSelection.collapsed(offset: capitalized.length),
        );
      }
    }
  }

  // check if emails match
  void _checkEmailsMatch() {
    final email = _emailController.text.trim();
    final confirmEmail = _confirmEmailController.text.trim();

    setState(() {
      _emailChecked = confirmEmail.isNotEmpty;
      if (_emailChecked) {
        _emailsMatch = email == confirmEmail && email.isNotEmpty;
      }
    });
  }

  // check if pins match
  void _checkPinsMatch() {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    setState(() {
      _pinChecked = confirmPin.isNotEmpty;
      if (_pinChecked) {
        _pinsMatch = pin == confirmPin && pin.isNotEmpty && pin.length == 6;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Security Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'High Security Account',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Enterprise-grade encryption & dual authentication',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),

                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),

                          // NAME
                          const Text(
                            'Name *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (value) => _capitalizeWhileTyping(_nameController),
                            decoration: InputDecoration(
                              hintText: 'Enter your first name',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Color(0xFFBF7DCB),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your first name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // SURNAME
                          const Text(
                            'Surname *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _surnameController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (value) => _capitalizeWhileTyping(_surnameController),
                            decoration: InputDecoration(
                              hintText: 'Enter your surname',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Color(0xFFBF7DCB),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your surname';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // EMAIL
                          const Text(
                            'Email *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (_) => _checkEmailsMatch(),
                            decoration: InputDecoration(
                              hintText: 'Enter your secure email',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.email,
                                color: Color(0xFFBF7DCB),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.white.withOpacity(0.7),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "We'll send verification codes to this email",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // CONFIRM EMAIL
                          const Text(
                            'Confirm Email *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmEmailController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (_) => _checkEmailsMatch(),
                            decoration: InputDecoration(
                              hintText: 'Confirm your email',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFFBF7DCB),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your email';
                              }
                              return null;
                            },
                          ),
                          // email match validation message
                          if (_emailChecked) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _emailsMatch ? Icons.check_circle : Icons.error,
                                  color: _emailsMatch ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _emailsMatch ? 'Emails match' : 'Emails do not match',
                                  style: TextStyle(
                                    color: _emailsMatch ? Colors.green : Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),

                          // PHONE NUMBER
                          const Text(
                            'Phone Number *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                              _SouthAfricanPhoneFormatter(),
                            ],
                            decoration: InputDecoration(
                              hintText: '71 234 5678',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.phone,
                                color: Color(0xFFBF7DCB),
                              ),
                              prefixText: '+27 ',
                              prefixStyle: const TextStyle(color: Colors.white),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              final digits = value.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              if (digits.length != 9) {
                                return 'Please enter a valid 9-digit SA number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // GENDER
                          const Text(
                            'Gender *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              dropdownColor: const Color(0xFF2a1f3e),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Select your gender',
                                hintStyle: const TextStyle(color: Color(0xFFBF7DCB)),
                                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFBF7DCB)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              ),
                              items: _genderOptions.map((option) {
                                return DropdownMenuItem(
                                  value: option,
                                  child: Text(option),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select your gender';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

                          // NEXT OF KIN
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: const Text(
                              'Next of Kin *',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFCCCCFF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // next of kin name
                          TextFormField(
                            controller: _nextOfKinNameController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (value) => _capitalizeWhileTyping(_nextOfKinNameController),
                            decoration: InputDecoration(
                              hintText: 'Next of kin first name *',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Color(0xFFBF7DCB),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter next of kin first name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // next of kin surname
                          TextFormField(
                            controller: _nextOfKinSurnameController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (value) => _capitalizeWhileTyping(_nextOfKinSurnameController),
                            decoration: InputDecoration(
                              hintText: 'Next of kin surname *',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Color(0xFFBF7DCB),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter next of kin surname';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // next of kin phone
                          TextFormField(
                            controller: _nextOfKinPhoneController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                              _SouthAfricanPhoneFormatter(),
                            ],
                            decoration: InputDecoration(
                              hintText: '71 234 5678 *',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.phone,
                                color: Color(0xFFBF7DCB),
                              ),
                              prefixText: '+27 ',
                              prefixStyle: const TextStyle(color: Colors.white),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter next of kin phone number';
                              }
                              final digits = value.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              if (digits.length != 9) {
                                return 'Please enter a valid 9-digit SA number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // next of kin relationship
                          TextFormField(
                            controller: _nextOfKinRelationController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Relationship (e.g., Spouse, Parent, Sibling) *',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.people,
                                color: Color(0xFFBF7DCB),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter relationship';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // next of kin alternative phone (optional)
                          TextFormField(
                            controller: _nextOfKinAltPhoneController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                              _SouthAfricanPhoneFormatter(),
                            ],
                            decoration: InputDecoration(
                              hintText: '71 234 5678 (optional)',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.phone_android,
                                color: Color(0xFFBF7DCB),
                              ),
                              prefixText: '+27 ',
                              prefixStyle: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // PASSWORD
                          const Text(
                            'Password *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (value) {
                              setState(() {
                                _password = value;
                                _passwordStrength = _calculatePasswordStrength(
                                  value,
                                );
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Create a strong password',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Color(0xFFBF7DCB),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFFBF7DCB),
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please create a password';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                return 'Include at least one uppercase letter';
                              }
                              if (!RegExp(r'[a-z]').hasMatch(value)) {
                                return 'Include at least one lowercase letter';
                              }
                              if (!RegExp(r'[0-9]').hasMatch(value)) {
                                return 'Include at least one number';
                              }
                              if (!RegExp(
                                r'[!@#$%^&*(),.?":{}|<>]',
                              ).hasMatch(value)) {
                                return 'Include at least one special character';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Password Strength Indicator
                          if (_password.isNotEmpty) ...[
                            Row(
                              children: [
                                Text(
                                  'Password Strength: ',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _passwordStrength
                                      .toString()
                                      .split('.')
                                      .last
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: _getPasswordStrengthColor(),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: _getPasswordStrengthValue(),
                              backgroundColor: Colors.grey[800],
                              color: _getPasswordStrengthColor(),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Password Requirements
                          if (_password.isNotEmpty) ...[
                            _buildPasswordRequirement(
                              'At least 8 characters',
                              _password.length >= 8,
                            ),
                            _buildPasswordRequirement(
                              'Uppercase letter',
                              RegExp(r'[A-Z]').hasMatch(_password),
                            ),
                            _buildPasswordRequirement(
                              'Lowercase letter',
                              RegExp(r'[a-z]').hasMatch(_password),
                            ),
                            _buildPasswordRequirement(
                              'Number',
                              RegExp(r'[0-9]').hasMatch(_password),
                            ),
                            _buildPasswordRequirement(
                              'Special character',
                              RegExp(
                                r'[!@#$%^&*(),.?":{}|<>]',
                              ).hasMatch(_password),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // CONFIRM PASSWORD
                          const Text(
                            'Confirm Password *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Confirm your password',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFFBF7DCB),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFFBF7DCB),
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // PIN
                          const Text(
                            'PIN (6 digits) *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pinController,
                            obscureText: _obscurePin,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (_) => _checkPinsMatch(),
                            decoration: InputDecoration(
                              hintText: 'Enter 6-digit PIN',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Color(0xFFBF7DCB),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePin
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFFBF7DCB),
                                ),
                                onPressed: () => setState(
                                  () => _obscurePin = !_obscurePin,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a PIN';
                              }
                              if (value.length != 6) {
                                return 'PIN must be exactly 6 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // CONFIRM PIN
                          const Text(
                            'Confirm PIN *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCCCCFF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPinController,
                            obscureText: _obscureConfirmPin,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (_) => _checkPinsMatch(),
                            decoration: InputDecoration(
                              hintText: 'Confirm your 6-digit PIN',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBF7DCB),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD105FF),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFFBF7DCB),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPin
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFFBF7DCB),
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPin =
                                      !_obscureConfirmPin,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your PIN';
                              }
                              if (value.length != 6) {
                                return 'PIN must be exactly 6 digits';
                              }
                              return null;
                            },
                          ),
                          // pin match validation message
                          if (_pinChecked) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _pinsMatch ? Icons.check_circle : Icons.error,
                                  color: _pinsMatch ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _pinsMatch ? 'PINs match' : 'PINs do not match',
                                  style: TextStyle(
                                    color: _pinsMatch ? Colors.green : Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),

                          // USE BIOMETRICS TOGGLE
                          SwitchListTile(
                            title: Text(
                              "Use Biometrics",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                            subtitle: Text(
                              "Do you wish to enable device biometrics for app authentication and confirmations?",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                              ),
                            ),
                            value: _useBiometrics,
                            onChanged: (value) async {
                              setState(() {
                                _useBiometrics = value;
                              });
                            },
                            activeThumbColor: const Color(0xFFD105FF),
                          ),
                          const SizedBox(height: 30),

                          // CONTINUE BUTTON
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  // check email match
                                  if (!_emailsMatch) {
                                    setState(() {
                                      _errorMessage = 'Emails do not match';
                                    });
                                    return;
                                  }
                                  // check pin match
                                  if (!_pinsMatch) {
                                    setState(() {
                                      _errorMessage = 'PINs do not match';
                                    });
                                    return;
                                  }
                                  setState(() {
                                    _isLoading = true;
                                    _errorMessage = '';
                                  });

                                  final auth = AuthService();
                                  final fullName = '${_nameController.text.trim()} ${_surnameController.text.trim()}';
                                  final nextOfKinFullName = '${_nextOfKinNameController.text.trim()} ${_nextOfKinSurnameController.text.trim()}';

                                  final user = await auth.registerWithEmail(
                                    fullName,
                                    _emailController.text.trim(),
                                    _passwordController.text.trim(),
                                    _phoneController.text.trim(),
                                    nextOfKinName: nextOfKinFullName,
                                    nextOfKinPhone: _nextOfKinPhoneController.text.trim(),
                                    nextOfKinRelation: _nextOfKinRelationController.text.trim(),
                                    nextOfKinAltPhone: _nextOfKinAltPhoneController.text.trim().isNotEmpty
                                        ? _nextOfKinAltPhoneController.text.trim()
                                        : null,
                                    gender: _selectedGender,
                                  );

                                  setState(() {
                                    _isLoading = false;
                                  });

                                  if (user != null) {
                                    // save pin to secure storage
                                    await auth.savePin(_pinController.text.trim());

                                    // save biometrics preference
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool(
                                      PrefKeys.useBiometrics,
                                      _useBiometrics,
                                    );

                                    if (mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => OTPVerificationScreen(
                                            email: _emailController.text.trim(),
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    setState(() {
                                      _errorMessage = 'Registration failed. Please try again.';
                                    });
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD105FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Continue to Verification',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Icon(Icons.verified, size: 22),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // SECURITY INFORMATION
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.security,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Security Information:',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildSecurityTip(
                                  'Biometric login adds an extra layer of security',
                                ),
                                _buildSecurityTip(
                                  'We never share your personal information',
                                ),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildSecurityTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle,
            color: met ? Colors.green : Colors.grey,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: met ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  Color _getPasswordStrengthColor() {
    switch (_passwordStrength) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.medium:
        return Colors.orange;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }

  double _getPasswordStrengthValue() {
    switch (_passwordStrength) {
      case PasswordStrength.weak:
        return 0.3;
      case PasswordStrength.medium:
        return 0.6;
      case PasswordStrength.strong:
        return 1.0;
    }
  }
}

enum PasswordStrength { weak, medium, strong }

class _SouthAfricanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 5) buffer.write(' ');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}