import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:purple_safety/services/local_notifications_service.dart';
import 'package:purple_safety/services/notification_navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseMessagingService {
  FirebaseMessagingService._internal();

  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService.instance() => _instance;
  LocalNotificationsService? _localNotificationsService;

  Future<void> init({
    required LocalNotificationsService localNotificationsService,
  }) async {
    _localNotificationsService = localNotificationsService;

    _handlePushNotificationsToken();
    _requestPermission();
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpenedApp(initialMessage);
    }
  }

  Future<void> _handlePushNotificationsToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcmToken', token as String);

    FirebaseMessaging.instance.onTokenRefresh
        .listen((fcmToken) async {
          if (fcmToken.isNotEmpty) {
            await prefs.setString('fcmToken', token);
          }
        })
        .onError((error) {
          debugPrint(
            '[Firebase Messaging Service] Error refreshing FCM token: $error',
          );
        });
  }

  Future<void> _requestPermission() async {
    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      '[Firebase Messaging Service] User granted permission: ${result.authorizationStatus}',
    );
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint(
      "[Firebase Messaging Service] Message received on app foreground: ${message.notification.toString()}",
    );

    _localNotificationsService?.showNotification(
      message.notification?.title,
      message.notification?.body,
      jsonEncode(message.data),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint(
      '[Firebase Messaging Service] Notification caused the app to open: ${message.data.toString()}',
    );
    if (message.data['type'] == 'sos') {
      NotificationNavigationService.openSOS(
        sosEventId: message.data['sosEventId'],
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotificationsService.instance().init();

  await LocalNotificationsService.instance().showNotification(
    message.notification?.title,
    message.notification?.body,
    jsonEncode(message.data),
  );
}
