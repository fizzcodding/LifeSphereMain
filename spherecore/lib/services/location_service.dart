import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import '../models/gps_target.dart';

class LocationService {
  static final _db = FirebaseDatabase.instance.ref();
  static StreamSubscription<Position>? _subscription;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<bool> startTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    final uid = _uid;
    if (uid == null) return false;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _updateFirebase(uid, pos);
    } catch (_) {}

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (pos) => _updateFirebase(uid, pos),
      onError: (_) => stopTracking(),
      cancelOnError: true,
    );

    return true;
  }

  static void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }

  static Future<void> _updateFirebase(String uid, Position pos) async {
    try {
      await _db.child('users/$uid/target').set(
        GpsTarget(lat: pos.latitude, lon: pos.longitude).toJson(),
      );
    } catch (_) {}
  }

  static bool get isTracking => _subscription != null;
}
