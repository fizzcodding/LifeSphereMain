import 'package:flutter/material.dart';
import '../../models/medicine/reminder_model.dart';
import '../../services/reminder_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/sidebar.dart';
import 'add_reminder_dialog.dart';
import 'scan_prescription_screen.dart';

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
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<ReminderWithId>>(
        stream: ReminderService.getReminders(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data ?? [];
          if (items.isEmpty) return const _EmptyReminders();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _ReminderCard(item: items[index]),
          );
        },
      ),
    );
  }
}

/// Two paths into the same reminder system: manual entry and prescription
/// scan. Both produce the same MedicineReminder data.
void _showAddOptions(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Medication', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 14),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              leading: const Icon(Icons.document_scanner_rounded,
                  color: AppTheme.secondary),
              title: const Text('Scan Prescription'),
              subtitle: const Text(
                'Photograph a prescription and review before saving',
                style: TextStyle(fontSize: 12.5),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ScanPrescriptionScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              leading: const Icon(Icons.edit_note_rounded,
                  color: AppTheme.secondary),
              title: const Text('Enter Manually'),
              subtitle: const Text(
                'Type the medicine details yourself',
                style: TextStyle(fontSize: 12.5),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => const AddReminderDialog(),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReminderCard extends StatelessWidget {
  final ReminderWithId item;

  const _ReminderCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final r = item.reminder;
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
            child: const Icon(Icons.medication_liquid_rounded, color: AppTheme.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _Pill(icon: Icons.access_time_rounded, text: r.time),
                    _Pill(icon: Icons.inventory_2_rounded, text: 'Slot ${r.slot}'),
                    _Pill(icon: Icons.calendar_month_rounded, text: r.days.join(', ')),
                  ],
                ),
                if (r.note != null && r.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(r.note!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (v) async {
              if (v == 'edit') {
                showDialog(
                  context: context,
                  builder: (_) => AddReminderDialog(initial: item),
                );
                return;
              }
              final ok = await _confirmDelete(context);
              if (ok) await ReminderService.deleteReminder(item.id);
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
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    ) ?? false;
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
