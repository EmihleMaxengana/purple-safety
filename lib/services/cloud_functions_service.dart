import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> sendWelcomeNotification({required String token}) async {
    try {
      final callable = _functions.httpsCallableFromUrl(
        'https://sendnotification-6qju6ualcq-uc.a.run.app',
      );

      final result = await callable.call({
        'token': token,
        'title': 'Welcome to Purple Safety',
        'body': 'Thank you for joining our community!',
      });

      debugPrint(
        "[Cloud Functions Service] result.data: ${result.data} for token: $token",
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[Cloud Functions Service] Firebase Functions error\n'
        'Code: ${e.code}\n'
        'Message: ${e.message}\n'
        'Details: ${e.details}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Unexpected error: $e\n'
        '${stackTrace as String?}',
      );
    }
  }

  Future<void> sendTestNotification({required String token}) async {
    try {
      final callable = _functions.httpsCallableFromUrl(
        'https://sendnotification-6qju6ualcq-uc.a.run.app',
      );

      final result = await callable.call({
        'token': token,
        'title': 'Test notification',
        'body': 'Hello from Dart Cloud Functions!',
      });

      debugPrint(
        "[Cloud Functions Service] result.data: ${result.data} for token: $token",
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[Cloud Functions Service] Firebase Functions error\n'
        'Code: ${e.code}\n'
        'Message: ${e.message}\n'
        'Details: ${e.details}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Unexpected error: $e\n'
        '${stackTrace as String?}',
      );
    }
  }

  Future<void> sendSOSAlert({
    required String group,
    String? title,
    String? body,
    String? sosEventId,
  }) async {
    if (!['trusted contacts', 'community'].contains(group)) {
      throw Exception('Allowed groups are "trusted contacts" & "community".');
    }

    try {
      final callable = _functions.httpsCallableFromUrl(
        'https://sendnotification-6qju6ualcq-uc.a.run.app',
      );

      final result = await callable.call({
        'group': group,
        'title': title,
        'body': body,
        'sosEventId': ?sosEventId,
      });

      debugPrint(
        "[Cloud Functions Service] result.data: ${result.data} for token: $group",
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[Cloud Functions Service] Firebase Functions error\n'
        'Code: ${e.code}\n'
        'Message: ${e.message}\n'
        'Details: ${e.details}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Unexpected error: $e\n'
        '${stackTrace as String?}',
      );
    }
  }
}
