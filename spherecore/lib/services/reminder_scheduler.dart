import 'dart:async';
import 'package:intl/intl.dart';
import '../models/medicine/reminder_model.dart';
import 'notification_service.dart';
import 'reminder_service.dart';

class ReminderScheduler {
  static final ReminderScheduler _instance = ReminderScheduler._internal();
  factory ReminderScheduler() => _instance;
  ReminderScheduler._internal();

  Timer? _checkTimer;
  List<ReminderWithId> _currentReminders = [];
  StreamSubscription? _reminderSubscription;

  void start() {
    _reminderSubscription?.cancel();
    _reminderSubscription = ReminderService.getReminders().listen((reminders) {
      _currentReminders = reminders;
      _syncPersistentNotifications();
      _checkReminders();
    });

    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkReminders();
    });
  }

  void stop() {
    _reminderSubscription?.cancel();
    _checkTimer?.cancel();
  }

  Future<void> _syncPersistentNotifications() async {
    final notificationService = NotificationService();
    await notificationService.cancelAll();

    final dayMap = {
      "Mon": 1,
      "Tue": 2,
      "Wed": 3,
      "Thu": 4,
      "Fri": 5,
      "Sat": 6,
      "Sun": 7,
    };

    for (final item in _currentReminders) {
      final reminder = item.reminder;
      final format = DateFormat("hh:mm a");
      try {
        final parsedTime = format.parse(reminder.time);

        for (final day in reminder.days) {
          final weekday = dayMap[day];
          if (weekday != null) {
            final notificationId = (item.id + day).hashCode;

            await notificationService.scheduleWeeklyReminder(
              id: notificationId,
              title: "Medication Reminder",
              body: "It's time for ${reminder.name} (${reminder.slot})",
              weekday: weekday,
              hour: parsedTime.hour,
              minute: parsedTime.minute,
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _checkReminders() async {
    if (_currentReminders.isEmpty) {
      return;
    }

    final now = DateTime.now();
    for (final item in _currentReminders) {
      final reminder = item.reminder;
      final reminderTime = _parseReminderTime(reminder.time);
      if (reminderTime == null) continue;

      final dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      final todayName = dayNames[now.weekday - 1];
      if (!reminder.days.contains(todayName)) continue;

      final diff = reminderTime.difference(now).inMinutes;

      if (diff <= 5 && diff >= -2) {
        await NotificationService().showNotification(
          id: reminder.hashCode,
          title: "Medicine Time: ${reminder.name}",
          body: "It's time for your medication in Slot ${reminder.slot}.",
        );
      }
    }
  }

  DateTime? _parseReminderTime(String timeStr) {
    try {
      final now = DateTime.now();
      final format = DateFormat("hh:mm a");
      final parsedTime = format.parse(timeStr);
      return DateTime(
        now.year,
        now.month,
        now.day,
        parsedTime.hour,
        parsedTime.minute,
      );
    } catch (_) {
      return null;
    }
  }
}
