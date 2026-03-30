import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';

class PresenceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Location _location = Location();

  static Future<void> setOnline(bool online) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': online,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) return;
    }

    final locationData = await _location.getLocation();
    if (locationData.latitude != null && locationData.longitude != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'currentLocation': GeoPoint(
          locationData.latitude!,
          locationData.longitude!,
        ),
        'lastActive': FieldValue.serverTimestamp(),
      });
    }
  }
}
