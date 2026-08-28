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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final LocalNotificationsService localNotificationsService =
      LocalNotificationsService.instance();
  await localNotificationsService.init();
  final FirebaseMessagingService firebaseMessagingService =
      FirebaseMessagingService.instance();
  await firebaseMessagingService.init(
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
  State<PurpleSafetyApp> createState() => _PurpleSafetyAppState();
}

class _PurpleSafetyAppState extends State<PurpleSafetyApp>
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
    print('(checking pending SOS: hasPending = $hasPending');

    if (!hasPending) {
      print('(no pending SOS found');
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    print('(current connectivity: $connectivityResult');

    if (connectivityResult != ConnectivityResult.none) {
      print('(internet available, attempting to send pending SOS...');
      await _sendPendingSOS();
    } else {
      print('(no internet, waiting for connection...');
    }

    Connectivity().onConnectivityChanged.listen((result) async {
      print('(connectivity changed: $result');
      if (result != ConnectivityResult.none) {
        print('(internet restored, sending pending SOS...');
        await _sendPendingSOS();
      }
    });
  }

  Future<void> _sendPendingSOS() async {
    if (_isSendingPending) {
      print('(already sending pending SOS, skipping...');
      return;
    }

    _isSendingPending = true;

    try {
      final pendingList = await SOSAlertService.getPendingSOS();
      print('(pending SOS list: $pendingList');

      if (pendingList.isEmpty) {
        print('(no pending SOS to send');
        _isSendingPending = false;
        return;
      }

      print('(getting current location...');
      final locationPlugin = location.Location();

      bool serviceEnabled = await locationPlugin.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await locationPlugin.requestService();
        if (!serviceEnabled) {
          print('(location service not enabled');
          _isSendingPending = false;
          return;
        }
      }

      final permission = await locationPlugin.hasPermission();
      if (permission == location.PermissionStatus.denied) {
        final requested = await locationPlugin.requestPermission();
        if (requested != location.PermissionStatus.granted) {
          print('(location permission denied');
          _isSendingPending = false;
          return;
        }
      }

      final currentLocation = await locationPlugin.getLocation();
      if (currentLocation.latitude == null ||
          currentLocation.longitude == null) {
        print('(failed to get current location');
        _isSendingPending = false;
        return;
      }

      print(
        '(current location: ${currentLocation.latitude}, ${currentLocation.longitude}',
      );

      int sentCount = 0;
      for (var sosData in pendingList) {
        try {
          print('(sending SOS for user: ${sosData['userId']}');
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
          print('(pending SOS sent successfully for ${sosData['userId']}');
        } catch (e) {
          print('(failed to send pending SOS: $e');
        }
      }

      if (sentCount > 0) {
        await SOSAlertService.clearPendingSOS();
        print('(pending SOS cleared from storage');
      }
    } catch (e) {
      print('(error in _sendPendingSOS: $e');
    } finally {
      _isSendingPending = false;
    }
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