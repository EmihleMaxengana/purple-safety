import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purple_safety/login_screen.dart';
import 'package:purple_safety/main_screen.dart';
import 'package:purple_safety/services/shake_trigger.dart';
import 'package:purple_safety/services/presence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Start shake detection (if enabled in settings)
  await ShakeTrigger.start();

  // Set up lifecycle observer for presence
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const PurpleSafetyApp());
}

class PurpleSafetyApp extends StatelessWidget {
  const PurpleSafetyApp({super.key});

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
              return const LoginScreen();
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

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PresenceService.setOnline(true);
    } else if (state == AppLifecycleState.paused) {
      PresenceService.setOnline(false);
    }
  }
}
