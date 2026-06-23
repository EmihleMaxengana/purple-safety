import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purple_safety/authentication/login_screen.dart';
import 'package:purple_safety/navigation/main_screen.dart';
import 'package:purple_safety/authentication/reauth_screen.dart';
import 'package:purple_safety/incidents/incident_service.dart';
import 'package:purple_safety/authentication/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Start periodic cleanup of expired incidents
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check if reauth was requested from previous run
    _checkReauthRequired();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app is backgrounded or detached, require re-auth on next resume.
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
