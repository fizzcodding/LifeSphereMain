 import 'package:flutter/material.dart';
import '../../models/medicine/reminder_model.dart';
import '../../services/reminder_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/sidebar.dart';
import 'add_reminder_dialog.dart';

class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoTitle(),
        actions: const [AppUserAvatar()],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/reminders'),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(context: context, builder: (_) => const AddReminderDialog());
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<ReminderWithId>>(
        stream: ReminderService.getReminders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const _EmptyReminders();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              return _ReminderCard(item: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final ReminderWithId item;

  const _ReminderCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final reminder = item.reminder;
    return PremiumPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.medication_liquid_rounded,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _Pill(icon: Icons.access_time_rounded, text: reminder.time),
                    _Pill(icon: Icons.inventory_2_rounded, text: 'Slot ${reminder.slot}'),
                    _Pill(icon: Icons.calendar_month_rounded, text: reminder.days.join(', ')),
                  ],
                ),
                if (reminder.note != null && reminder.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(reminder.note!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) async {
              if (value == 'edit') {
                showDialog(
                  context: context,
                  builder: (_) => AddReminderDialog(initialReminder: item),
                );
                return;
              }
              final confirm = await _confirmDelete(context);
              if (confirm) await ReminderService.deleteReminder(item.id);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Reminder?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Yes', style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.secondary),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: PremiumPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.medication_outlined,
                size: 52,
                color: AppTheme.secondary.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 16),
              Text('No reminders found', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
