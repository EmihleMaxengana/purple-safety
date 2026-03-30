import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';

class ShakeTrigger {
  static bool _listening = false;
  static double _lastX = 0, _lastY = 0, _lastZ = 0;
  static DateTime? _lastShakeTime;
  static const double _shakeThreshold = 15.0;
  static const Duration _shakeCooldown = Duration(seconds: 3);

  static Future<void> start() async {
    if (_listening) return;
    final prefs = await SharedPreferences.getInstance();
    final shakeEnabled = prefs.getBool('shake_trigger') ?? false;
    if (!shakeEnabled) return;

    _listening = true;
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (!_listening) return;
      final double deltaX = (event.x - _lastX).abs();
      final double deltaY = (event.y - _lastY).abs();
      final double deltaZ = (event.z - _lastZ).abs();
      final double totalDelta = deltaX + deltaY + deltaZ;

      if (totalDelta > _shakeThreshold) {
        final now = DateTime.now();
        if (_lastShakeTime == null ||
            now.difference(_lastShakeTime!) > _shakeCooldown) {
          _lastShakeTime = now;
          // Trigger SOS light (no navigation, just flag)
          EmergencyManager().activateEmergencyModeLight();
        }
      }
      _lastX = event.x;
      _lastY = event.y;
      _lastZ = event.z;
    });
  }

  static void stop() {
    _listening = false;
  }
}
