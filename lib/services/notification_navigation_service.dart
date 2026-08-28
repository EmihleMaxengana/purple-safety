import 'package:flutter/foundation.dart';

enum NotificationDestination { sos, emergency }

class NotificationNavigationRequest {
  const NotificationNavigationRequest(this.destination, {this.sosEventId});

  final NotificationDestination destination;
  final String? sosEventId;
}

class NotificationNavigationService {
  NotificationNavigationService._();

  static final ValueNotifier<NotificationNavigationRequest?> request =
      ValueNotifier(null);

  static void openSOS({String? sosEventId}) {
    debugPrint(
      '[Notification Navigation] Queued Community map navigation '
      '(SOS: ${sosEventId ?? 'unspecified'})',
    );
    request.value = NotificationNavigationRequest(
      NotificationDestination.sos,
      sosEventId: sosEventId,
    );
  }

  static void openEmergency() {
    debugPrint('[Notification Navigation] Queued Emergency navigation');
    request.value = const NotificationNavigationRequest(
      NotificationDestination.emergency,
    );
  }

  static void consume(NotificationNavigationRequest handledRequest) {
    if (identical(request.value, handledRequest)) request.value = null;
  }
}
