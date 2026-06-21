import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import '../models/gps_target.dart';

class LocationService {
  static final _db = FirebaseDatabase.instance.ref();
  static StreamSubscription<Position>? _positionStreamSubscription;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<bool> startTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    final uid = _uid;
    if (uid == null) return false;

    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _updateFirebase(uid, initialPosition);
    } catch (_) {}

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        ).listen(
          (Position position) {
            _updateFirebase(uid, position);
          },
          onError: (_) {
            stopTracking();
          },
          cancelOnError: true,
        );

    return true;
  }

  static void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  static Future<void> _updateFirebase(String uid, Position position) async {
    try {
      final targetRef = _db.child("users/$uid/target");
      final gpsData = GpsTarget(
        lat: position.latitude,
        lon: position.longitude,
      );
      await targetRef.set(gpsData.toJson());
    } catch (_) {}
  }

  static bool get isTracking => _positionStreamSubscription != null;
}
