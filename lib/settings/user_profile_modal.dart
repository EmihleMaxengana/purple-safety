import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/contacts/firestore_service.dart';
import 'package:purple_safety/safety/biometric_services.dart';
import 'package:purple_safety/utils/pref_keys.dart';
import 'package:purple_safety/models/incident_model.dart';
import 'package:purple_safety/services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app_settings/app_settings.dart';

class UserProfileModal extends StatefulWidget {
  final List<Contact>? contacts;

  const UserProfileModal({Key? key, this.contacts}) : super(key: key);

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  String? _errorMessage;
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();

  List<Contact> _realContacts = [];
  bool _isLoadingContacts = true;

  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _contactsSubscription;

  bool _shareLocationWithContacts = true;
  bool _shareLocationWithCommunity = false;
  bool _useBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadLocationSharingPreferences();
    _listenToContacts();
    _loadBiometricPreference();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _contactsSubscription?.cancel();
    super.dispose();
  }

  void _listenToContacts() {
    final user = AuthService().getCurrentUser();
    if (user != null) {
      _contactsSubscription = _firestoreService
          .getContactsStream(user.uid)
          .listen((contacts) {
            setState(() {
              _realContacts = contacts;
              _isLoadingContacts = false;
            });
          });
    } else {
      setState(() {
        _isLoadingContacts = false;
      });
    }
  }

  Future<void> _loadLocationSharingPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shareLocationWithContacts =
          prefs.getBool(PrefKeys.shareLocationWithContacts) ?? true;
      _shareLocationWithCommunity =
          prefs.getBool(PrefKeys.shareLocationWithCommunity) ?? false;
    });
  }

  Future<void> _saveLocationSharingPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      PrefKeys.shareLocationWithContacts,
      _shareLocationWithContacts,
    );
    await prefs.setBool(
      PrefKeys.shareLocationWithCommunity,
      _shareLocationWithCommunity,
    );
  }

  Future<void> _loadBiometricPreference() async {
    final enabled = await BiometricService.isBiometricsEnabled();
    setState(() {
      _useBiometrics = enabled;
    });
  }

  void _showBiometricsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, sheetSetState) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1a0f2e),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Biometric Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                SwitchListTile(
                  title: const Text(
                    "Toggle Biometrics",
                    style: TextStyle(color: Colors.white70),
                  ),
                  subtitle: Text(
                    _useBiometrics ? "Disable biometrics" : "Enable biometrics",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  value: _useBiometrics,
                  onChanged: (value) async {
                    final authenticated = await BiometricService.authenticateWithUserPreference(
                      context: context,
                      reason: 'Authenticate to change biometrics setting',
                    );
                    if (authenticated) {
                      await BiometricService.setBiometricsEnabled(value);
                      setState(() {
                        _useBiometrics = value;
                      });
                      sheetSetState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value ? 'Biometrics enabled' : 'Biometrics disabled'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Authentication failed. Biometrics not changed.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  activeThumbColor: const Color(0xFF6A1B9A),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.settings, color: Color(0xFFBF7DCB)),
                  title: const Text(
                    'Device Biometric Settings',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Manage fingerprints in system settings',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openDeviceBiometricSettings();
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDeviceBiometricSettings() async {
    if (Platform.isAndroid) {
      AppSettings.openAppSettings(type: AppSettingsType.security);
    } else if (Platform.isIOS) {
      AppSettings.openAppSettings();
    }
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = AuthService().getCurrentUser();
      if (user != null) {
        final data = await AuthService().getUserData(user.uid);
        if (data != null) {
          setState(() {
            _userData = data;
          });
        } else {
          setState(() {
            _errorMessage = 'No user data found.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Not logged in.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfileImageUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(PrefKeys.profileImageUrl);
    } else {
      await prefs.setString(PrefKeys.profileImageUrl, url);
    }
  }

  Future<String?> _loadProfileImageUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PrefKeys.profileImageUrl);
  }

  Future<void> _loadProfileImage() async {
    final url = await _loadProfileImageUrl();
    if (url != null && url.isNotEmpty) {
      setState(() {
        _profileImageUrl = url;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final file = File(pickedFile.path);

      final user = AuthService().getCurrentUser();
      if (user != null) {
        try {
          final String? downloadUrl = await StorageService.uploadProfileImage(
            filePath: file.path,
            userId: user.uid,
          );

          if (downloadUrl != null) {
            await _saveProfileImageUrl(downloadUrl);
            setState(() {
              _profileImageUrl = downloadUrl;
              _profileImage = file;
            });
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload photo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a0f2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text(
                'Take a photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Remove photo',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _profileImage = null;
                  _profileImageUrl = null;
                });
                _saveProfileImageUrl(null);
              },
            ),
          ],
        ),
      ),
    );
  }

  // toggle with fingerprint - only for turning OFF
  Future<void> _toggleWithFingerprintForOff(
    String settingName,
    bool currentValue,
    Function(bool) onToggle,
  ) async {
    final authenticated = await BiometricService.authenticateWithUserPreference(
      context: context,
      reason: 'Authenticate to disable $settingName',
    );
    if (authenticated) {
      onToggle(!currentValue);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication failed. $settingName not changed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatPhoneForDisplay(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('27') && cleaned.length == 11) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.length == 9) {
      return '+27 ${cleaned.substring(0, 2)} ${cleaned.substring(2, 5)} ${cleaned.substring(5)}';
    }
    return phone;
  }

  // change password
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        backgroundColor: const Color(0xFF1a0f2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purple.withOpacity(0.3)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(color: Color(0xFFBF7DCB)),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFBF7DCB)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(color: Color(0xFFBF7DCB)),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock, color: Color(0xFFBF7DCB)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: TextStyle(color: Color(0xFFBF7DCB)),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFBF7DCB)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                );
                return;
              }
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.red),
                );
                return;
              }
              if (currentPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter current password'), backgroundColor: Colors.red),
                );
                return;
              }

              final authenticated = await BiometricService.authenticateWithUserPreference(
                context: context,
                reason: 'Authenticate to change your password',
              );

              if (!authenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Authentication failed'), backgroundColor: Colors.red),
                );
                return;
              }

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: Colors.purple),
                ),
              );

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && user.email != null) {
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPasswordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPasswordController.text);
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  // change pin
  void _showChangePinDialog() {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change PIN'),
        backgroundColor: const Color(0xFF1a0f2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purple.withOpacity(0.3)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPinController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                labelStyle: TextStyle(color: Color(0xFFBF7DCB)),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFBF7DCB)),
                hintText: 'Enter 6-digit PIN',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'New PIN',
                labelStyle: TextStyle(color: Color(0xFFBF7DCB)),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock, color: Color(0xFFBF7DCB)),
                hintText: 'Enter 6-digit PIN',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPinController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Confirm New PIN',
                labelStyle: TextStyle(color: Color(0xFFBF7DCB)),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFBF7DCB)),
                hintText: 'Confirm 6-digit PIN',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPinController.text != confirmPinController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match'), backgroundColor: Colors.red),
                );
                return;
              }
              if (newPinController.text.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be exactly 6 digits'), backgroundColor: Colors.red),
                );
                return;
              }
              if (currentPinController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter current PIN'), backgroundColor: Colors.red),
                );
                return;
              }

              final authenticated = await BiometricService.authenticateWithUserPreference(
                context: context,
                reason: 'Authenticate to change your PIN',
              );

              if (!authenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Authentication failed'), backgroundColor: Colors.red),
                );
                return;
              }

              // verify current pin
              final auth = AuthService();
              final isValid = await auth.reauthenticateWithPIN(currentPinController.text);
              if (!isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Current PIN is incorrect'), backgroundColor: Colors.red),
                );
                return;
              }

              // save new pin
              await auth.savePin(newPinController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN changed successfully!'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            child: const Text('Change PIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1a0f2e),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 50),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUser,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Emergency Contacts'),
                      _buildEmergencyContacts(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Next of Kin'),
                      _buildNextOfKinCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Privacy & Security'),
                      _buildPrivacySecurity(),
                      const SizedBox(height: 24),
                      _buildLogoutButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    return GestureDetector(
      onTap: _showImagePickerOptions,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2a1f3e),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.purple.withOpacity(0.5),
              backgroundImage: _profileImage != null
                  ? FileImage(_profileImage!)
                  : (_profileImageUrl != null
                      ? CachedNetworkImageProvider(_profileImageUrl!)
                      : null),
              child: _profileImage == null && _profileImageUrl == null
                  ? const Icon(Icons.person, color: Colors.white, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _userData['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: Colors.white, size: 12),
                            Text(
                              ' Verified',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData['phone'] ?? 'No phone',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (_userData['email'] != null)
                    Text(
                      _userData['email'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to change profile picture',
                    style: TextStyle(color: Colors.purple, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFa078c0),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    if (_isLoadingContacts) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2a1f3e),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 8),
              Text(
                'Loading contacts...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_realContacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2a1f3e),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.people_outline, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No trusted contacts yet',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Add contacts from the Home screen',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1f3e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Your Trusted Contacts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${_realContacts.length} contacts',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          ..._realContacts.map(
            (c) => ListTile(
              leading: CircleAvatar(
                backgroundColor: c.color.withOpacity(0.5),
                child: Text(
                  c.initials,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(c.name, style: const TextStyle(color: Colors.white)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.relationship != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        c.relationship!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  Text(
                    c.phone ?? 'No phone number',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
              trailing: c.active
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    )
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextOfKinCard() {
    final hasNextOfKin =
        (_userData['nextOfKinName'] != null &&
        _userData['nextOfKinName'].toString().isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1f3e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: hasNextOfKin
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emergency,
                      color: Color(0xFFBF7DCB),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _userData['nextOfKinName'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _userData['nextOfKinRelation'] ?? 'Contact',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.phone, color: Colors.white54, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatPhoneForDisplay(
                          _userData['nextOfKinPhone'] ?? 'No phone',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_userData['nextOfKinAltPhone'] != null &&
                    _userData['nextOfKinAltPhone'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_android,
                          color: Colors.white54,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatPhoneForDisplay(
                              _userData['nextOfKinAltPhone'],
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : const Column(
              children: [
                Icon(Icons.person_outline, color: Colors.white38, size: 48),
                SizedBox(height: 8),
                Text(
                  'No next of kin added',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'You can add one in Settings > Next of Kin',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
    );
  }

  // privacy & security - no biometric check for turning ON
  Widget _buildPrivacySecurity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1f3e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // share location with trusted contacts
          SwitchListTile(
            title: const Text(
              'Share location with trusted contacts',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Send your location to your trusted contacts every 15 minutes',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            value: _shareLocationWithContacts,
            onChanged: (value) {
              if (value == false) {
                // turning off - require authentication
                _toggleWithFingerprintForOff(
                  'Location Sharing with Contacts',
                  _shareLocationWithContacts,
                  (newVal) async {
                    setState(() => _shareLocationWithContacts = newVal);
                    await _saveLocationSharingPreferences();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Location sharing with contacts disabled'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                );
              } else {
                // turning on - no authentication needed
                setState(() => _shareLocationWithContacts = true);
                _saveLocationSharingPreferences();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Location sharing with contacts enabled'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            activeColor: Colors.purple,
          ),
          // share location with community
          SwitchListTile(
            title: const Text(
              'Share location with community',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Share your location with all Purple Safety users',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            value: _shareLocationWithCommunity,
            onChanged: (value) {
              if (value == false) {
                // turning off - require authentication
                _toggleWithFingerprintForOff(
                  'Location Sharing with Community',
                  _shareLocationWithCommunity,
                  (newVal) async {
                    setState(() => _shareLocationWithCommunity = newVal);
                    await _saveLocationSharingPreferences();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Location sharing with community disabled'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                );
              } else {
                // turning on - no authentication needed
                setState(() => _shareLocationWithCommunity = true);
                _saveLocationSharingPreferences();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Location sharing with community enabled'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            activeColor: Colors.purple,
          ),
          // biometrics on/off
          ListTile(
            leading: const Icon(Icons.fingerprint, color: Color(0xFFBF7DCB)),
            title: Text(
              _useBiometrics ? 'Biometrics On' : 'Biometrics Off',
              style: TextStyle(
                color: _useBiometrics ? Colors.green : Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              _useBiometrics ? 'Tap to manage biometrics' : 'Tap to enable biometrics',
              style: TextStyle(
                color: _useBiometrics ? Colors.green.withOpacity(0.7) : Colors.white38,
                fontSize: 12,
              ),
            ),
            trailing: Icon(
              _useBiometrics ? Icons.check_circle : Icons.circle,
              color: _useBiometrics ? Colors.green : Colors.white38,
              size: 20,
            ),
            onTap: _showBiometricsModal,
          ),
          const Divider(color: Colors.white24, height: 20),
          // change password
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Color(0xFFBF7DCB)),
            title: const Text(
              'Change Password',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Update your account password',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
            onTap: _showChangePasswordDialog,
          ),
          // change pin
          ListTile(
            leading: const Icon(Icons.lock, color: Color(0xFFBF7DCB)),
            title: const Text(
              'Change PIN',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Update your 6-digit PIN',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
            onTap: _showChangePinDialog,
          ),
          // device management
          ListTile(
            leading: const Icon(Icons.devices, color: Color(0xFFBF7DCB)),
            title: const Text(
              'Device management',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Manage linked devices',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
            onTap: () async {
              final authenticated =
                  await BiometricService.authenticateWithUserPreference(
                    context: context,
                    reason: 'Authenticate to manage devices',
                  );
              if (authenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device management (coming soon)'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Center(
      child: TextButton(
        onPressed: () async {
          final authenticated =
              await BiometricService.authenticateWithUserPreference(
                context: context,
                reason: 'Authenticate to log out',
              );
          if (authenticated) {
            await AuthService().logout();
            if (context.mounted) {
              Navigator.pop(context);
            }
          }
        },
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        child: const Text(
          'Log Out',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}