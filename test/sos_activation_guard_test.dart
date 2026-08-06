import 'package:flutter_test/flutter_test.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';

void main() {
  group('SOS activation guard', () {
    test('allows activation when no active SOS exists', () {
      expect(
        EmergencyManager.canActivateSOS(
          isEmergencyActive: false,
          hasActiveSOS: false,
        ),
        isTrue,
      );
    });

    test('blocks activation when emergency is already active', () {
      expect(
        EmergencyManager.canActivateSOS(
          isEmergencyActive: true,
          hasActiveSOS: false,
        ),
        isFalse,
      );
    });

    test('blocks activation when the backend already has an active SOS', () {
      expect(
        EmergencyManager.canActivateSOS(
          isEmergencyActive: false,
          hasActiveSOS: true,
        ),
        isFalse,
      );
    });
  });
}
