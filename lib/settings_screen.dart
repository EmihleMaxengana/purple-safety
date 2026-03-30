import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purple_safety/services/auth_service.dart';
import 'package:purple_safety/services/biometric_services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  // Trigger settings
  bool _powerButtonTrigger = false;
  bool _shakeTrigger = false;
  bool _isAndroid = false;
  bool _platformChecked = false; // flag to avoid multiple checks

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTriggerSettings();
    // platform detection moved to didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Access Theme only after dependencies are ready
    if (!_platformChecked) {
      _platformChecked = true;
      _checkPlatform();
    }
  }

  void _checkPlatform() {
    _isAndroid = Theme.of(context).platform == TargetPlatform.android;
    // Force rebuild to show Android‑only UI if needed
    setState(() {});
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = _auth.getCurrentUser();
    if (user != null) {
      final data = await _auth.getUserData(user.uid);
      if (data != null) {
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadTriggerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _powerButtonTrigger = prefs.getBool('power_button_trigger') ?? false;
      _shakeTrigger = prefs.getBool('shake_trigger') ?? false;
    });
  }

  Future<void> _saveTriggerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('power_button_trigger', _powerButtonTrigger);
    await prefs.setBool('shake_trigger', _shakeTrigger);

    // Communicate with native service to start/stop background services
    if (_isAndroid) {
      final platform = MethodChannel('sos_trigger');
      try {
        await platform.invokeMethod('setTriggerSettings', {
          'powerButton': _powerButtonTrigger,
          'shake': _shakeTrigger,
        });
      } catch (e) {
        debugPrint('Failed to update native services: $e');
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trigger settings saved')));
  }

  Future<void> _saveUserData() async {
    final authenticated = await BiometricService.authenticate(
      reason: 'Authenticate to update your profile',
    );
    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = _auth.getCurrentUser();
    if (user == null) return;

    try {
      await _auth.updateUserData(user.uid, {
        'email': _emailController.text,
        'phone': _phoneController.text,
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _requireFingerprint() async {
    return await BiometricService.authenticate(
      reason: 'Authenticate to access this setting',
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Implement password change via Firebase Auth (requires re-authentication)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password change feature coming soon'),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your data is encrypted and stored securely. We never share your personal information without your consent.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent and cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Delete user from Firebase Auth and Firestore
      await _auth.logout(); // For now just logout
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
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
              const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Profile section
              _buildSectionTitle('Profile Information'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save Changes'),
              ),

              const SizedBox(height: 32),

              // SOS Triggers section
              _buildSectionTitle('SOS Triggers (Android only)'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a0f2e),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    if (!_isAndroid)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Background triggers are only available on Android devices.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SwitchListTile(
                      title: const Text(
                        'Power Button (5 presses)',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Press power button 5 times quickly to trigger SOS',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      value: _powerButtonTrigger && _isAndroid,
                      onChanged: _isAndroid
                          ? (value) {
                              setState(() => _powerButtonTrigger = value);
                              _saveTriggerSettings();
                            }
                          : null,
                      activeColor: Colors.red,
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Shake Phone Hard',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Shake your phone vigorously to trigger SOS',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      value: _shakeTrigger && _isAndroid,
                      onChanged: _isAndroid
                          ? (value) {
                              setState(() => _shakeTrigger = value);
                              _saveTriggerSettings();
                            }
                          : null,
                      activeColor: Colors.red,
                    ),
                    if (_isAndroid && (_powerButtonTrigger || _shakeTrigger))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Note: These features will run a background service.\n'
                          'Make sure to allow "Ignore battery optimizations" for this app in system settings.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Other settings (protected by fingerprint)
              _buildSectionTitle('Security'),
              const SizedBox(height: 8),
              _buildSettingTile(
                icon: Icons.lock,
                title: 'Change Password',
                onTap: () async {
                  if (await _requireFingerprint()) {
                    _showChangePasswordDialog();
                  }
                },
              ),
              _buildSettingTile(
                icon: Icons.fingerprint,
                title: 'Manage Biometrics',
                onTap: () async {
                  if (await _requireFingerprint()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Biometrics management (coming soon)'),
                      ),
                    );
                  }
                },
              ),
              _buildSettingTile(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () async {
                  if (await _requireFingerprint()) {
                    _showPrivacyPolicy();
                  }
                },
              ),
              _buildSettingTile(
                icon: Icons.delete_forever,
                title: 'Delete Account',
                color: Colors.red,
                onTap: () async {
                  if (await _requireFingerprint()) {
                    _confirmDeleteAccount();
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFa078c0),
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFBF7DCB)),
        prefixIcon: Icon(icon, color: const Color(0xFFBF7DCB)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Card(
      color: const Color(0xFF1a0f2e),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white70,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}
