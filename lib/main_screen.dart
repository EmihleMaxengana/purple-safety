import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import 'home/home_screen.dart';
import 'emergency/emergency_manager.dart';
import 'emergency/emergency_mode_screen.dart';
import 'app_header.dart';
import 'community_screen.dart';
import 'safety_tools_screen.dart';
import 'settings_screen.dart';
import 'user_profile_modal.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isEmergencyMode = false;
  final EmergencyManager _emergencyManager = EmergencyManager();

  // Method channel for background SOS trigger (Android only)
  static const MethodChannel _channel = MethodChannel('sos_trigger');

  @override
  void initState() {
    super.initState();
    _emergencyManager.emergencyStatusStream.listen((isEmergency) {
      setState(() {
        _isEmergencyMode = isEmergency;
        if (isEmergency) {
          _selectedIndex = 1; // Emergency tab
        }
      });
    });
    _checkSosTrigger();
  }

  Future<void> _checkSosTrigger() async {
    try {
      final triggered = await _channel.invokeMethod('getTriggerStatus');
      if (triggered == true) {
        // Navigate to Tools tab (index 3)
        setState(() {
          _selectedIndex = 3;
        });
        // Optional: show a snackbar or notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOS triggered from background!')),
          );
        }
      }
    } catch (e) {
      // Method not available on iOS, ignore
    }
  }

  late final List<Widget> _pages = <Widget>[
    HomeScreen(
      onNavigateToTools: _goToToolsTab,
      onNavigateToEmergency: _goToEmergencyTab,
    ),
    const EmergencyModeScreen(),
    const CommunityScreen(),
    SafetyToolsScreen(onCallEmergency: _goToEmergencyTab),
    const SettingsScreen(),
  ];

  void _goToToolsTab() {
    setState(() {
      _selectedIndex = 3;
    });
  }

  void _goToEmergencyTab() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showUserProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UserProfileModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isEmergencyMode
          ? const Color(0xFF2D1B47)
          : Colors.white,
      appBar: buildAppHeader(onAvatarPressed: _showUserProfileModal),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF100c1f),
        selectedItemColor: const Color(0xFFc080ff),
        unselectedItemColor: const Color(0xFFa078c0),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Emergency',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.security), label: 'Tools'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
