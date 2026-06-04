import 'package:flutter/material.dart';
import 'package:purple_safety/login_screen.dart';
import 'package:purple_safety/home/home_screen.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';
import 'package:purple_safety/emergency/emergency_mode_screen.dart';
import 'package:purple_safety/app_header.dart';
import 'package:purple_safety/community_screen.dart';
import 'package:purple_safety/safety_tools_screen.dart';
import 'package:purple_safety/settings_screen.dart';
import 'package:purple_safety/user_profile_modal.dart';
import 'package:purple_safety/safety_alerts_screen.dart';
import 'package:purple_safety/full_map_screen.dart';
import 'package:purple_safety/services/firestore_service.dart';
import 'package:purple_safety/services/auth_service.dart';

class MainScreen extends StatefulWidget {
  final String? initialTripId;

  const MainScreen({Key? key, this.initialTripId}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isEmergencyMode = false;
  final EmergencyManager _emergencyManager = EmergencyManager();
  final FirestoreService _firestoreService = FirestoreService();
  int _unreadAlertsCount = 0;

  @override
  void initState() {
    super.initState();
    _emergencyManager.emergencyStatusStream.listen((isEmergency) {
      setState(() {
        _isEmergencyMode = isEmergency;
        if (isEmergency) {
          _selectedIndex = 1;
        }
      });
    });
    _listenToAlerts();
    _checkInitialTripId();

    WidgetsBinding.instance.addObserver(this);
  }

  void _listenToAlerts() async {
    final user = AuthService().getCurrentUser();
    if (user != null) {
      _firestoreService.getAlertsStream(user.uid).listen((alerts) {
        setState(() {
          _unreadAlertsCount = alerts.where((a) => !a.read).length;
        });
      });
    }
  }

  void _checkInitialTripId() {
    if (widget.initialTripId != null && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FullMapScreen(initialTripId: widget.initialTripId),
          ),
        );
      });
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

  void _openSafetyAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SafetyAlertsScreen()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in the foreground and active
        print("App has resumed.");
        break;
      case AppLifecycleState.inactive:
        // App is in an inactive state (e.g., phone call, split screen)
        print("App is inactive...");
        break;
      case AppLifecycleState.paused:
        // App is in the background
        print("App has paused.");
        break;
      case AppLifecycleState.detached:
        // App is terminated
        print("App is terminated.");
        break;
      case AppLifecycleState.hidden:
        // App is running but not visible (Flutter 3.13+)
        print("App is invisible.");
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isEmergencyMode
          ? const Color(0xFF2D1B47)
          : Colors.white,
      appBar: buildAppHeader(
        onAvatarPressed: _showUserProfileModal,
        unreadAlertsCount: _unreadAlertsCount,
        onNotificationPressed: _openSafetyAlerts,
      ),
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
