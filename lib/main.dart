import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purple_safety/services/firebase_messaging_service.dart';
import 'package:purple_safety/services/local_notifications_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:location/location.dart' as location;
import 'package:purple_safety/authentication/login_screen.dart';
import 'package:purple_safety/navigation/main_screen.dart';
import 'package:purple_safety/authentication/reauth_screen.dart';
import 'package:purple_safety/incidents/incident_service.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/emergency/sos_alert_service.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final LocalNotificationsService localNotificationsService =
      LocalNotificationsService.instance();
  localNotificationsService.init();
  final FirebaseMessagingService firebaseMessagingService =
      FirebaseMessagingService.instance();
  firebaseMessagingService.init(
    localNotificationsService: localNotificationsService,
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
  PurpleSafetyAppState createState() => PurpleSafetyAppState();
}

class PurpleSafetyAppState extends State<PurpleSafetyApp>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  bool _needsReauth = false;
  bool _isLoading = true;
  bool _isSendingPending = false;

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

  Future<void> _checkPendingSOS() async {
    final hasPending = await SOSAlertService.hasPendingSOS();
    debugPrint('(checking pending SOS: hasPending = $hasPending)');

    if (!hasPending) {
      debugPrint('(no pending SOS found)');
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('(current connectivity: $connectivityResult');

    if (connectivityResult != ConnectivityResult.none) {
      debugPrint('(internet available, attempting to send pending SOS...)');
      await _sendPendingSOS();
    } else {
      debugPrint('(no internet, waiting for connection...)');
    }

    Connectivity().onConnectivityChanged.listen((result) async {
      debugPrint('(connectivity changed: $result)');
      if (result != ConnectivityResult.none) {
        debugPrint('(internet restored, sending pending SOS...)');
        await _sendPendingSOS();
      }
    });
  }

  Future<void> _sendPendingSOS() async {
    if (_isSendingPending) {
      debugPrint('(already sending pending SOS, skipping...)');
      return;
    }

    _isSendingPending = true;

    try {
      final pendingList = await SOSAlertService.getPendingSOS();
      debugPrint('(pending SOS list: $pendingList)');

      if (pendingList.isEmpty) {
        debugPrint('(no pending SOS to send)');
        _isSendingPending = false;
        return;
      }

      debugPrint('(getting current location...)');
      final locationPlugin = location.Location();

      bool serviceEnabled = await locationPlugin.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await locationPlugin.requestService();
        if (!serviceEnabled) {
          debugPrint('(location service not enabled)');
          _isSendingPending = false;
          return;
        }
      }

      final permission = await locationPlugin.hasPermission();
      if (permission == location.PermissionStatus.denied) {
        final requested = await locationPlugin.requestPermission();
        if (requested != location.PermissionStatus.granted) {
          debugPrint('(location permission denied)');
          _isSendingPending = false;
          return;
        }
      }

      final currentLocation = await locationPlugin.getLocation();
      if (currentLocation.latitude == null ||
          currentLocation.longitude == null) {
        debugPrint('(failed to get current location)');
        _isSendingPending = false;
        return;
      }

      debugPrint(
        '(current location: ${currentLocation.latitude}, ${currentLocation.longitude})',
      );

      int sentCount = 0;
      for (var sosData in pendingList) {
        try {
          debugPrint('(sending SOS for user: ${sosData['userId']})');
          await SOSAlertService.sendCommunitySOSAlert(
            userId: sosData['userId']!,
            userName: sosData['userName']!,
            latitude: currentLocation.latitude!,
            longitude: currentLocation.longitude!,
            triggerLat: sosData['triggerLat'],
            triggerLng: sosData['triggerLng'],
            triggerTimestamp: sosData['triggerTimestamp'],
          );
          sentCount++;
          debugPrint(
            '(pending SOS sent successfully for ${sosData['userId']})',
          );
        } catch (e) {
          debugPrint('(failed to send pending SOS: $e)');
        }
      }

      if (sentCount > 0) {
        await SOSAlertService.clearPendingSOS();
        debugPrint('(pending SOS cleared from storage)');
      }
    } catch (e) {
      debugPrint('(error in _sendPendingSOS: $e)');
    } finally {
      _isSendingPending = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool isEmergencyActive = EmergencyManager().isEmergencyActive;
    final bool isCameraActive = EmergencyManager().isCameraActive;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      if (!isEmergencyActive && !isCameraActive) {
        _authService.markRequireReauth();
      }
    }

    //(only check re-auth if the native camera is NOT currently active)
    if (state == AppLifecycleState.hidden && !isCameraActive) {
      _checkReauthRequired();
    }
  }

  Future<void> _checkReauthRequired() async {
    final req = await _authService.isRequireReauth();
    //(only rebuild if the lock status actually changes)
    if (_needsReauth != req) {
      setState(() {
        _needsReauth = req;
      });
    }
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
        key: const ValueKey('auth_stream'),
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
