import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:purple_safety/services/notification_navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _viewSOSAction = 'view_sos';
const _callEmergencyAction = 'call_emergency';
const _pendingActionKey = 'pending_notification_action';
const _pendingPayloadKey = 'pending_notification_payload';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  await _persistNotificationResponse(response);
}

Future<void> _persistNotificationResponse(NotificationResponse response) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pendingActionKey, response.actionId ?? '');
  await prefs.setString(_pendingPayloadKey, response.payload ?? '');
}

Future<void> _handleNotificationResponse(NotificationResponse response) async {
  // Keep every action durable until an active MainScreen confirms that it has
  // displayed the requested destination.
  await _persistNotificationResponse(response);
  _routeNotificationResponse(response);
}

void _routeNotificationResponse(NotificationResponse response) {
  Map<String, dynamic> data = const {};
  if (response.payload != null && response.payload!.isNotEmpty) {
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.payload!));
    } catch (_) {}
  }

  if (response.actionId == _callEmergencyAction) {
    debugPrint(
      '[Local Notifications Service - Notifications] Opening Emergency from notification action',
    );
    NotificationNavigationService.openEmergency();
  } else if (response.actionId == _viewSOSAction || data['type'] == 'sos') {
    final sosEventId = data['sosEventId'];
    debugPrint(
      '[Local Notifications Service - Notifications] Opening SOS from notification action',
    );
    NotificationNavigationService.openSOS(
      sosEventId: sosEventId is String && sosEventId.isNotEmpty
          ? sosEventId
          : null,
    );
  }
}

class LocalNotificationsService {
  LocalNotificationsService._internal();

  static final LocalNotificationsService _instance =
      LocalNotificationsService._internal();

  factory LocalNotificationsService.instance() => _instance;

  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  final _androidInitializationSettings = const AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );

  final _iosInitializationSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    notificationCategories: [
      DarwinNotificationCategory(
        'sos_category',
        actions: [
          DarwinNotificationAction.plain(_viewSOSAction, 'View SOS'),
          DarwinNotificationAction.plain(
            _callEmergencyAction,
            'Call emergency',
          ),
        ],
      ),
    ],
  );

  final _androidChannel = const AndroidNotificationChannel(
    'channel_id',
    'Channel name',
    description: 'Android push notification channel',
    importance: Importance.max,
  );

  bool _isFlutterLocalNotificationInitialized = false;

  int _notificationIdCounter = 0;

  Future<void> init() async {
    if (_isFlutterLocalNotificationInitialized) {
      return;
    }

    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    final initializationSettings = InitializationSettings(
      android: _androidInitializationSettings,
      iOS: _iosInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final launchDetails = await _flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      await _handleNotificationResponse(launchResponse);
    }

    await restorePendingNavigation();

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    _isFlutterLocalNotificationInitialized = true;
  }

  Future<void> restorePendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    // Notification actions may be written by a background isolate. Reload the
    // cache so this isolate sees values written after it was started.
    await prefs.reload();
    final actionId = prefs.getString(_pendingActionKey);
    final payload = prefs.getString(_pendingPayloadKey);
    if (actionId == null && payload == null) return;

    _routeNotificationResponse(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: actionId,
        payload: payload,
      ),
    );
  }

  Future<void> clearPendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingActionKey);
    await prefs.remove(_pendingPayloadKey);
  }

  Future<void> showNotification(
    String? title,
    String? body,
    String? payload,
  ) async {
    final data = _decodePayload(payload);
    final isSOS = data['type'] == 'sos';
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      actions: isSOS
          ? <AndroidNotificationAction>[
              AndroidNotificationAction(
                _viewSOSAction,
                'View SOS',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                _callEmergencyAction,
                'Call emergency',
                showsUserInterface: true,
              ),
            ]
          : const [],
    );

    final iosDetails = DarwinNotificationDetails(
      categoryIdentifier: isSOS ? 'sos_category' : null,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: _notificationIdCounter++,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(payload));
    } catch (_) {
      return const {};
    }
  }
}
