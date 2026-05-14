import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/services/auth_service.dart';
import 'package:purple_safety/home/home_screen.dart';
import 'package:purple_safety/services/biometric_services.dart';
import 'package:purple_safety/services/firestore_service.dart';
import 'dart:async';

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
  final ImagePicker _picker = ImagePicker();
  
  // Real contacts from Firestore
  List<Contact> _realContacts = [];
  bool _isLoadingContacts = true;
  
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _contactsSubscription;

  // Location sharing preferences
  bool _shareLocationWithContacts = true;
  bool _shareLocationWithCommunity = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadLocationSharingPreferences();
    _listenToContacts();
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
      _shareLocationWithContacts = prefs.getBool('shareLocationWithContacts') ?? true;
      _shareLocationWithCommunity = prefs.getBool('shareLocationWithCommunity') ?? false;
    });
  }

  Future<void> _saveLocationSharingPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shareLocationWithContacts', _shareLocationWithContacts);
    await prefs.setBool('shareLocationWithCommunity', _shareLocationWithCommunity);
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

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
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
          ],
        ),
      ),
    );
  }

  // Wrapper for toggles that require fingerprint
  Future<void> _toggleWithFingerprint(
    String settingName,
    bool currentValue,
    Function(bool) onToggle,
  ) async {
    final authenticated = await BiometricService.authenticate(
      reason: 'Authenticate to change $settingName',
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
                  : null,
              child: _profileImage == null
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
    // Show loading indicator while fetching contacts
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

    // Show real contacts from Firestore
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
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
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

  Widget _buildPrivacySecurity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1f3e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
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
            onChanged: (value) => _toggleWithFingerprint(
              'Location Sharing with Contacts',
              _shareLocationWithContacts,
              (newVal) async {
                setState(() => _shareLocationWithContacts = newVal);
                await _saveLocationSharingPreferences();
                if (newVal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location sharing with contacts enabled'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location sharing with contacts disabled'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
            activeColor: Colors.purple,
          ),
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
            onChanged: (value) => _toggleWithFingerprint(
              'Location Sharing with Community',
              _shareLocationWithCommunity,
              (newVal) async {
                setState(() => _shareLocationWithCommunity = newVal);
                await _saveLocationSharingPreferences();
                if (newVal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location sharing with community enabled'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location sharing with community disabled'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
            activeColor: Colors.purple,
          ),
          const Divider(color: Colors.white24, height: 20),
          ListTile(
            leading: const Icon(Icons.data_usage, color: Color(0xFFBF7DCB)),
            title: const Text(
              'Data sharing settings',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Manage how your data is used',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
            onTap: () async {
              final authenticated = await BiometricService.authenticate(
                reason: 'Authenticate to view data sharing settings',
              );
              if (authenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data sharing settings (coming soon)'),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: Color(0xFFBF7DCB)),
            title: const Text(
              'Change PIN / Biometrics',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Update your security credentials',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
            onTap: () async {
              final authenticated = await BiometricService.authenticate(
                reason: 'Authenticate to change biometrics settings',
              );
              if (authenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Biometrics settings (coming soon)'),
                  ),
                );
              }
            },
          ),
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
              final authenticated = await BiometricService.authenticate(
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
          final authenticated = await BiometricService.authenticate(
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