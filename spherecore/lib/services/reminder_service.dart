import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/medicine/medicine_reminder.dart';
import '../models/medicine/reminder_model.dart';

class ReminderService {
  static final _db = FirebaseDatabase.instance.ref();
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Stream<List<ReminderWithId>> getReminders() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _db.child('users/$uid/reminders').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      return data.entries.map((entry) {
        final id = entry.key;
        final value = Map<String, dynamic>.from(entry.value);
        return ReminderWithId(
          id: id,
          reminder: MedicineReminder.fromJson(value),
        );
      }).toList();
    });
  }

  static Future<void> addReminder(MedicineReminder reminder) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.child('users/$uid/reminders').push().set(reminder.toJson());
  }

  static Future<void> updateReminder(
    String id,
    Map<String, dynamic> data,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.child('users/$uid/reminders/$id').update(data);
  }

  static Future<void> deleteReminder(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.child('users/$uid/reminders/$id').remove();
  }
}
