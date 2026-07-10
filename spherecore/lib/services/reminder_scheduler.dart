import 'dart:async';
import 'package:intl/intl.dart';
import '../models/medicine/reminder_model.dart';
import 'notification_service.dart';
import 'reminder_service.dart';

class ReminderScheduler {
  static final ReminderScheduler _instance = ReminderScheduler._internal();
  factory ReminderScheduler() => _instance;
  ReminderScheduler._internal();

  Timer? _timer;
  List<ReminderWithId> _reminders = [];
  StreamSubscription? _subscription;

  static const _dayMap = {
    'Mon': 1,
    'Tue': 2,
    'Wed': 3,
    'Thu': 4,
    'Fri': 5,
    'Sat': 6,
    'Sun': 7,
  };

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  void start() {
    _subscription?.cancel();
    _subscription = ReminderService.getReminders().listen((reminders) {
      _reminders = reminders;
      _sync();
      _check();
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  void stop() {
    _subscription?.cancel();
    _timer?.cancel();
  }

  Future<void> _sync() async {
    final svc = NotificationService();
    await svc.cancelAll();

    for (final item in _reminders) {
      final reminder = item.reminder;
      try {
        final parsed = DateFormat('hh:mm a').parse(reminder.time);
        for (final day in reminder.days) {
          final weekday = _dayMap[day];
          if (weekday != null) {
            await svc.scheduleWeeklyReminder(
              id: (item.id + day).hashCode,
              title: 'Medication Reminder',
              body: "It's time for ${reminder.name} (${reminder.slot})",
              weekday: weekday,
              hour: parsed.hour,
              minute: parsed.minute,
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _check() async {
    if (_reminders.isEmpty) return;

    final now = DateTime.now();
    for (final item in _reminders) {
      final reminder = item.reminder;
      try {
        final parsed = DateFormat('hh:mm a').parse(reminder.time);
        final scheduled = DateTime(
          now.year, now.month, now.day, parsed.hour, parsed.minute,
        );
        if (!reminder.days.contains(_dayNames[now.weekday - 1])) continue;

        final diff = scheduled.difference(now).inMinutes;
        if (diff <= 5 && diff >= -2) {
          await NotificationService().showNotification(
            id: reminder.hashCode,
            title: 'Medicine Time: ${reminder.name}',
            body: 'It\'s time for your medication in Slot ${reminder.slot}.',
          );
        }
      } catch (_) {}
    }
  }
}
