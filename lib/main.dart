import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purple_safety/authentication/login_screen.dart';
import 'package:purple_safety/navigation/main_screen.dart';
import 'package:purple_safety/authentication/reauth_screen.dart';
import 'package:purple_safety/services/incident_service.dart';
import 'package:purple_safety/services/auth_service.dart';
import 'package:purple_safety/utils/pref_keys.dart';
import 'package:purple_safety/safety/discreet_calculator_screen.dart';

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
  bool _isDiscreetMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDiscreetMode();
    _checkReauthRequired();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkDiscreetMode() async {
    final prefs = await SharedPreferences.getInstance();
    final discreetMode = prefs.getBool(PrefKeys.discreetMode) ?? false;
    setState(() {
      _isDiscreetMode = discreetMode;
      _isLoading = false;
    });
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
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
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

            // ✅ Discreet Calculator Mode
            if (_isDiscreetMode) {
              return const DiscreetCalculatorScreen();
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