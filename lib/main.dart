import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:location/location.dart' as location;
import 'package:purple_safety/authentication/login_screen.dart';
import 'package:purple_safety/navigation/main_screen.dart';
import 'package:purple_safety/authentication/reauth_screen.dart';
import 'package:purple_safety/incidents/incident_service.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/emergency/sos_alert_service.dart';
import 'package:purple_safety/utils/pref_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final incidentService = IncidentService();
  incidentService.deleteExpiredIncidents();
  Timer.periodic(const Duration(hours: 1), (timer) {
    incidentService.deleteExpiredIncidents();
  });

  runApp(const PurpleSafetyApp());
}

class PurpleSafetyApp extends StatefulWidget {
  const PurpleSafetyApp({super.key});

  @override
  State<PurpleSafetyApp> createState() => _PurpleSafetyAppState();
}

class _PurpleSafetyAppState extends State<PurpleSafetyApp>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  bool _needsReauth = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkReauthRequired();
    _checkPendingSOS();
    _setLoadingFalse();
  }

  void _setLoadingFalse() {
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================================
  // CHECK FOR PENDING SOS ON APP START AND CONNECTIVITY CHANGE
  // ============================================================
  Future<void> _checkPendingSOS() async {
    final hasPending = await SOSAlertService.hasPendingSOS();
    if (!hasPending) return;

    // Check if we have internet
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _sendPendingSOS();
    }

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        await _sendPendingSOS();
      }
    });
  }

  // ============================================================
  // SEND PENDING SOS WITH CURRENT LOCATION
  // ============================================================
  Future<void> _sendPendingSOS() async {
    final pendingList = await SOSAlertService.getPendingSOS();
    if (pendingList.isEmpty) return;

    // Get current location
    final locationPlugin = location.Location();
    bool serviceEnabled = await locationPlugin.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationPlugin.requestService();
      if (!serviceEnabled) return;
    }

    final permission = await locationPlugin.hasPermission();
    if (permission == location.PermissionStatus.denied) {
      final requested = await locationPlugin.requestPermission();
      if (requested != location.PermissionStatus.granted) return;
    }

    final currentLocation = await locationPlugin.getLocation();
    if (currentLocation.latitude == null || currentLocation.longitude == null) {
      return;
    }

    for (var sosData in pendingList) {
      try {
        await SOSAlertService.sendCommunitySOSAlert(
          userId: sosData['userId']!,
          userName: sosData['userName']!,
          latitude: currentLocation.latitude!,
          longitude: currentLocation.longitude!,
          triggerLat: sosData['triggerLat'],
          triggerLng: sosData['triggerLng'],
          triggerTimestamp: sosData['triggerTimestamp'],
        );
        debugPrint('✅ Pending SOS sent for ${sosData['userId']}');
      } catch (e) {
        debugPrint('❌ Failed to send pending SOS: $e');
      }
    }

    await SOSAlertService.clearPendingSOS();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _authService.markRequireReauth();
    }

    if (state == AppLifecycleState.hidden) {
      _checkReauthRequired();
    }
  }

  Future<void> _checkReauthRequired() async {
    final req = await _authService.isRequireReauth();
    setState(() {
      _needsReauth = req;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator(color: Colors.purple)),
        ),
      );
    }

    return MaterialApp(
      title: 'Purple Safety',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user == null) {
              _needsReauth = false;
              return const LoginScreen();
            }

            if (_needsReauth) {
              return ReauthScreen(
                onAuthenticated: () async {
                  await _authService.clearRequireReauth();
                  setState(() {
                    _needsReauth = false;
                  });
                },
              );
            }

            return const MainScreen();
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}