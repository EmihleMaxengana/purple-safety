import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:purple_safety/services/user_service.dart';
import 'package:purple_safety/home/home_screen.dart'; // for Contact model (temporary)

class UserProfileModal extends StatefulWidget {
  // Optional: pass contacts from HomeScreen later
  final List<Contact>? contacts;

  const UserProfileModal({Key? key, this.contacts}) : super(key: key);

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  Map<String, String?> _userData = {};
  bool _isLoading = true;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // Dummy contacts for now
  List<Contact> _dummyContacts = [
    Contact(
      id: '1',
      name: 'Oyama',
      initials: 'O',
      color: Colors.purple,
      active: true,
      phone: '+27 12 345 6789',
    ),
    Contact(
      id: '2',
      name: 'Likhona',
      initials: 'L',
      color: Colors.deepPurple,
      active: true,
      phone: '+27 98 765 4321',
    ),
  ];

  // Panic trigger settings
  bool _fingerprintTrigger = true;
  bool _powerButtonTrigger = false;
  bool _shakeTrigger = false;

  // Privacy settings
  bool _shareLocationWithContacts = true;
  bool _shareLocationWithCommunity = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final data = await UserService.getUser();
    setState(() {
      _userData = data;
      _isLoading = false;
    });
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

  void _testTrigger() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trigger test: This would activate emergency mode.'),
        backgroundColor: Colors.green,
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
              : SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
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
                      // Profile header with image picker
                      _buildProfileHeader(),
                      const SizedBox(height: 24),

                      // Emergency Contacts (no "Add" button)
                      _buildSectionTitle('Emergency Contacts'),
                      _buildEmergencyContacts(),
                      const SizedBox(height: 24),

                      // Panic Trigger Setup
                      _buildSectionTitle('Panic Trigger Setup'),
                      _buildTriggerSetup(),
                      const SizedBox(height: 24),

                      // Privacy & Security
                      _buildSectionTitle('Privacy & Security'),
                      _buildPrivacySecurity(),
                      const SizedBox(height: 24),

                      // Logout button (simple text button)
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
                      _userData['email']!,
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
    // Use passed contacts if available, otherwise dummy
    final displayContacts = widget.contacts ?? _dummyContacts;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1f3e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Trusted Contacts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Divider(color: Colors.white24),
          ...displayContacts.map(
            (c) => ListTile(
              leading: CircleAvatar(
                backgroundColor: c.color.withOpacity(0.5),
                child: Text(
                  c.initials,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(c.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                c.phone ?? '',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          if (displayContacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'No contacts added yet.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTriggerSetup() {
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
              'Fingerprint',
              style: TextStyle(color: Colors.white),
            ),
            value: _fingerprintTrigger,
            onChanged: (value) => setState(() => _fingerprintTrigger = value),
            activeColor: Colors.purple,
          ),
          SwitchListTile(
            title: const Text(
              'Power Button (press 5 times)',
              style: TextStyle(color: Colors.white),
            ),
            value: _powerButtonTrigger,
            onChanged: (value) => setState(() => _powerButtonTrigger = value),
            activeColor: Colors.purple,
          ),
          SwitchListTile(
            title: const Text(
              'Shake Phone',
              style: TextStyle(color: Colors.white),
            ),
            value: _shakeTrigger,
            onChanged: (value) => setState(() => _shakeTrigger = value),
            activeColor: Colors.purple,
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _testTrigger,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Trigger'),
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
            value: _shareLocationWithContacts,
            onChanged: (value) =>
                setState(() => _shareLocationWithContacts = value),
            activeColor: Colors.purple,
          ),
          SwitchListTile(
            title: const Text(
              'Share location with community',
              style: TextStyle(color: Colors.white),
            ),
            value: _shareLocationWithCommunity,
            onChanged: (value) =>
                setState(() => _shareLocationWithCommunity = value),
            activeColor: Colors.purple,
          ),
          ListTile(
            title: const Text(
              'Data sharing settings',
              style: TextStyle(color: Colors.white),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
            onTap: () {},
          ),
          ListTile(
            title: const Text(
              'Change PIN / Biometrics',
              style: TextStyle(color: Colors.white),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
            onTap: () {},
          ),
          ListTile(
            title: const Text(
              'Device management',
              style: TextStyle(color: Colors.white),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Center(
      child: TextButton(
        onPressed: () async {
          await UserService.clearUser();
          if (context.mounted) {
            Navigator.pop(context); // close modal
            Navigator.pushReplacementNamed(context, '/login');
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
