import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/virtual_pin.dart';

class DatabaseService {
  static final _db = FirebaseDatabase.instance.ref();
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser?.uid ?? 'UNKNOWN';

  static DatabaseReference get _pinRef =>
      _db.child('users/$_uid/virtualPins');

  static Stream<List<VirtualPin>> getPins() {
    return _pinRef.onValue.map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return [];

      return data.entries.map((entry) {
        final id = entry.key;
        final pinData = Map<String, dynamic>.from(entry.value);
        return VirtualPin.fromJson(pinData).copyWith(id: id);
      }).toList();
    });
  }

  static Future<void> addPin(VirtualPin pin) async {
    final newRef = _pinRef.push();
    final newPin = pin.copyWith(id: newRef.key!);
    await newRef.set(newPin.toJson());
  }

  static Future<void> deletePin(String id) async {
    await _pinRef.child(id).remove();
  }

  static Future<void> togglePinState(String id, bool newState) async {
    await _pinRef.child(id).update({'state': newState});
  }

  static Future<void> updatePin(String id, Map<String, dynamic> data) async {
    await _pinRef.child(id).update(data);
  }

  static Future<void> updatePinD(String id, String newLabel, int newPin) async {
    await _pinRef.child(id).update({'label': newLabel, 'pin': newPin});
  }
}
