import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/safety/biometric_services.dart';
import 'package:purple_safety/authentication/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Next of kin data (loaded from Firestore)
  String _nextOfKinName = '';
  String _nextOfKinPhone = '';
  String _nextOfKinRelation = '';
  String _nextOfKinAltPhone = '';

  bool _isLoading = false;

  bool _useBiometrics = false;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadIsBiometricEnabled();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = _auth.getCurrentUser();
    if (user != null) {
      final data = await _auth.getUserData(user.uid);
      if (data != null) {
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _nextOfKinName = data['nextOfKinName'] ?? '';
        _nextOfKinPhone = data['nextOfKinPhone'] ?? '';
        _nextOfKinRelation = data['nextOfKinRelation'] ?? '';
        _nextOfKinAltPhone = data['nextOfKinAltPhone'] ?? '';
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveUserData() async {
    final authenticated = await BiometricService.authenticateWithUserPreference(
      context: context,
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

  Future<void> _loadIsBiometricEnabled() async {
    final available = await BiometricService.isFingerprintAvailable();
    final enabled = await BiometricService.isBiometricsEnabled();
    setState(() {
      _isBiometricAvailable = available;
      _useBiometrics = enabled;
    });
  }

  Future<void> _saveIsBiometricEnabled(bool value) async {
    await BiometricService.setBiometricsEnabled(value);
  }

  // ============================================================
  // CHANGE NEXT OF KIN
  // ============================================================
  Future<void> _changeNextOfKin() async {
    final nameController = TextEditingController(text: _nextOfKinName);
    final phoneController = TextEditingController(text: _nextOfKinPhone);
    final relationController = TextEditingController(text: _nextOfKinRelation);
    final altPhoneController = TextEditingController(text: _nextOfKinAltPhone);

    final formKey = GlobalKey<FormState>();
    bool hasChanges = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change Next of Kin'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Next of kin full name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (_) => setState(() => hasChanges = true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Primary contact number',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() => hasChanges = true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: relationController,
                      decoration: const InputDecoration(
                        labelText: 'Relationship',
                        hintText: 'e.g., Spouse, Parent, Sibling',
                        prefixIcon: Icon(Icons.people),
                      ),
                      onChanged: (_) => setState(() => hasChanges = true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: altPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Alternative Phone (Optional)',
                        hintText: 'Secondary contact number',
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() => hasChanges = true),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!hasChanges) {
                    Navigator.pop(context, false);
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    final authenticated = await BiometricService.authenticateWithUserPreference(
      context: context,
      reason: 'Authenticate to save next of kin changes',
    );
    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed. Changes not saved.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = _auth.getCurrentUser();
    if (user != null) {
      try {
        await _auth.updateNextOfKin(
          user.uid,
          name: nameController.text.trim().isNotEmpty
              ? nameController.text.trim()
              : null,
          phone: phoneController.text.trim().isNotEmpty
              ? phoneController.text.trim()
              : null,
          relation: relationController.text.trim().isNotEmpty
              ? relationController.text.trim()
              : null,
          altPhone: altPhoneController.text.trim().isNotEmpty
              ? altPhoneController.text.trim()
              : null,
        );
        setState(() {
          _nextOfKinName = nameController.text.trim();
          _nextOfKinPhone = phoneController.text.trim();
          _nextOfKinRelation = relationController.text.trim();
          _nextOfKinAltPhone = altPhoneController.text.trim();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Next of kin updated'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  // ============================================================
  // Change Password
  // ============================================================
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
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New passwords do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (currentPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your current password'),
                    backgroundColor: Colors.red,
                  ),
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
                    const SnackBar(
                      content: Text('Password changed successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                Navigator.pop(context);
                if (e.code == 'wrong-password') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Current password is incorrect'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Manage Biometrics
  // ============================================================
  void _showManageBiometricsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, sheetSetState) => Container(
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
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                value: _isBiometricAvailable ? _useBiometrics : false,
                onChanged: (value) async {
                  setState(() {
                    _useBiometrics = value;
                  });
                  sheetSetState(() {});
                  await _saveIsBiometricEnabled(value);
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
        ),
      ),
    );
  }

  Future<void> _openDeviceBiometricSettings() async {
    if (Platform.isAndroid) {
      AppSettings.openAppSettings(type: AppSettingsType.security);
    } else if (Platform.isIOS) {
      AppSettings.openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open your device settings to manage fingerprints'),
        ),
      );
    }
  }

  // ============================================================
  // Privacy Policy
  // ============================================================
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Privacy Matters',
                style: TextStyle(
                  color: Color(0xFFBF7DCB),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Purple Safety is committed to protecting your personal information. '
                'We collect only the data necessary to provide safety features:',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                '• Location data (only during active SOS or with your consent)',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '• Contacts (only the ones you manually add as trusted contacts)',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '• Incident reports (anonymously or with your name)',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                'Data Security',
                style: TextStyle(
                  color: Color(0xFFBF7DCB),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'All data is encrypted in transit and at rest. '
                'Your location is never shared without your explicit consent.',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                'Data Retention',
                style: TextStyle(
                  color: Color(0xFFBF7DCB),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Incident posts are automatically deleted after 24 hours\n'
                '• Account deletion removes all your data permanently\n'
                '• You can request data export at any time',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                'Contact Us',
                style: TextStyle(
                  color: Color(0xFFBF7DCB),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Email: privacy@purplesafety.com',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFBF7DCB)),
            ),
          ),
        ],
        backgroundColor: const Color(0xFF1a0f2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purple.withOpacity(0.3)),
        ),
      ),
    );
  }

  // ============================================================
  // Delete Account
  // ============================================================
  void _confirmDeleteAccount() async {
    final authenticated = await BiometricService.authenticateWithUserPreference(
      context: context,
      reason: 'Authenticate to delete your account',
    );
    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed. Account not deleted.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          '⚠️ WARNING: This action is PERMANENT and CANNOT be undone.\n\n'
          'All your data will be deleted:\n'
          '• Your profile information\n'
          '• Your trusted contacts\n'
          '• Your safety alerts\n'
          '• Your account credentials\n\n'
          'You will need to create a new account to use the app again.\n\n'
          'Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteAccount();
    }
  }

  Future<String?> _showPasswordDialog() async {
    String password = '';

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'WARNING: This action is permanent!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All your data will be permanently deleted.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Enter your password to confirm',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    onChanged: (value) {
                      password = value;
                      setState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: password.isEmpty
                      ? null
                      : () => Navigator.pop(context, password),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete Forever'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.email != null) {
        final password = await _showPasswordDialog();
        if (password == null) {
          setState(() => _isLoading = false);
          return;
        }

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Deleting account...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }

        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
        final contactsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('contacts')
            .get();
        if (contactsSnapshot.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in contactsSnapshot.docs) batch.delete(doc.reference);
          await batch.commit();
        }
        final alertsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('alerts')
            .get();
        if (alertsSnapshot.docs.isNotEmpty) {
          final alertsBatch = FirebaseFirestore.instance.batch();
          for (var doc in alertsSnapshot.docs)
            alertsBatch.delete(doc.reference);
          await alertsBatch.commit();
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await user.delete();

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account permanently deleted'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        if (mounted) {
          await _navigateToLoginWithAnimation();
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted && Navigator.of(context).canPop())
        Navigator.of(context).pop();
      if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect password. Account not deleted.'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please log out and log in again before deleting your account',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      } else if (e.code == 'user-not-found') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account already deleted or not found'),
            backgroundColor: Colors.orange,
          ),
        );
        await _navigateToLoginWithAnimation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted && Navigator.of(context).canPop())
        Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _navigateToLoginWithAnimation() async {
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _logout() async {
    final authenticated = await BiometricService.authenticateWithUserPreference(
      context: context,
      reason: 'Authenticate to log out',
    );
    if (authenticated) {
      await _auth.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
          ),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed. Logout cancelled.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper build methods
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
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
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

  String _formatPhoneForDisplay(String phone) {
    if (phone.isEmpty) return 'Not set';
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('27') && cleaned.length == 11) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.length == 9) {
      return '+27 ${cleaned.substring(0, 2)} ${cleaned.substring(2, 5)} ${cleaned.substring(5)}';
    }
    return phone;
  }

  Widget _buildNextOfKinDisplay() {
    final hasData = _nextOfKinName.isNotEmpty;
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
            'In case of emergency, other users will contact this person.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (hasData) ...[
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFFBF7DCB), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nextOfKinName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                    _nextOfKinRelation.isNotEmpty
                        ? _nextOfKinRelation
                        : 'Contact',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.white54, size: 14),
                const SizedBox(width: 8),
                Text(
                  _formatPhoneForDisplay(_nextOfKinPhone),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            if (_nextOfKinAltPhone.isNotEmpty)
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
                    Text(
                      _formatPhoneForDisplay(_nextOfKinAltPhone),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const Icon(Icons.person_outline, color: Colors.white38, size: 48),
            const SizedBox(height: 8),
            const Text(
              'No next of kin added',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _changeNextOfKin,
              icon: const Icon(Icons.edit, size: 18),
              label: Text(hasData ? 'Change Next of Kin' : 'Add Next of Kin'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFBF7DCB),
                side: const BorderSide(color: Color(0xFFBF7DCB)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1a0f2e),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFBF7DCB)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white70,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
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
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
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

                // Profile Information
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
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveUserData,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF6A1B9A),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Changes'),
                ),

                const SizedBox(height: 32),

                // Next of Kin Section
                _buildSectionTitle('Next of Kin'),
                const SizedBox(height: 8),
                _buildNextOfKinDisplay(),

                const SizedBox(height: 32),

                // Security Section
                _buildSectionTitle('Security'),
                const SizedBox(height: 8),
                _buildSettingTile(
                  icon: Icons.lock,
                  title: 'Change Password',
                  subtitle: 'Update your password with current password',
                  onTap: _showChangePasswordDialog,
                ),
                _buildSettingTile(
                  icon: Icons.fingerprint,
                  title: 'Manage Biometrics',
                  subtitle: 'Set up fingerprint for login',
                  onTap: _showManageBiometricsDialog,
                ),
                _buildSettingTile(
                  icon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  subtitle: 'Read how we protect your data',
                  onTap: _showPrivacyPolicy,
                ),

                const SizedBox(height: 24),

                // Account Actions Row
                _buildSectionTitle('Account Actions'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.logout,
                        label: 'Log Out',
                        color: Colors.orange,
                        onTap: _logout,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.delete_forever,
                        label: 'Delete Account',
                        color: Colors.red,
                        onTap: _confirmDeleteAccount,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Warning note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Deleting your account is permanent. All your data will be lost and you will need to create a new account.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
