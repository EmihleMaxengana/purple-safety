import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/services/cloud_functions_service.dart';
import 'package:purple_safety/services/local_notifications_service.dart';

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

    if (token != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(AuthService().getCurrentUser()?.uid)
          .update({
            'devices': [
              {'platform': Platform.operatingSystem, 'token': token},
            ],
          });
      debugPrint("[Firebase Messaging Service] FCM token: $token");
    }

    FirebaseMessaging.instance.onTokenRefresh
        .listen((fcmToken) {
          if (fcmToken.isNotEmpty) {
            debugPrint(
              '[Firebase Messaging Service] FCM token refreshed: $fcmToken',
            );
            FirebaseFirestore.instance
                .collection('users')
                .doc(AuthService().getCurrentUser()?.uid)
                .update({
                  'devices': [
                    {'platform': Platform.operatingSystem, 'token': fcmToken},
                  ],
                });
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
      '[Firebase Messaging Service] Foreground message received: ${message.data.toString()}',
    );
    debugPrint(
      '[Firebase Messaging Service] Notification title: ${message.notification.toString()}',
    );

    _localNotificationsService?.showNotification(
      message.notification?.title,
      message.notification?.body,
      null,
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint(
      'Notification caused the app to open: ${message.data.toString()}',
    );
    // TODO: Add navigation or specific handling based on message data
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  LocalNotificationsService.instance().showNotification(
    message.notification?.title,
    "A message has been received",
    null,
  );

  debugPrint(
    '[Firebase Messaging Service] Background message received: ${message.data.toString()}',
  );
  debugPrint(
    '[Firebase Messaging Service] Background message notification: ${message.notification?.toString()}',
  );
}
