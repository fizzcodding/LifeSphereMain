import 'package:flutter/material.dart';
import '../models/virtual_pin.dart';
import '../services/database_service.dart';
import '../themes/app_theme.dart';
import '../utils/toast.dart';
import '../widgets/sidebar.dart';

class VirtualPinTile extends StatelessWidget {
  final VirtualPin pin;

  const VirtualPinTile({super.key, required this.pin});

  @override
  Widget build(BuildContext context) {
    final active = pin.state;
    return PremiumPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.secondary.withValues(alpha: 0.16)
                  : AppTheme.background,
              shape: BoxShape.circle,
            ),
            child: Text(
              pin.pin.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? AppTheme.secondary : AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pin.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  active ? 'Active' : 'Inactive',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppTheme.secondary : AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Switch(
                  value: active,
                  onChanged: (value) {
                    DatabaseService.togglePinState(pin.id, value);
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (value) => _handleMenu(context, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit_label', child: Text('Edit Label')),
                    PopupMenuItem(value: 'edit_pin', child: Text('Edit Pin')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenu(BuildContext context, String action) async {
    switch (action) {
      case 'edit_label':
        final label = await _editDialog(context, 'Edit Label', pin.label);
        if (label != null && label.trim().isNotEmpty) {
          await DatabaseService.updatePin(pin.id, {'label': label.trim()});
          showSuccessToast('Label updated.');
        }
        return;
      case 'edit_pin':
        final value = await _editDialog(context, 'Edit Pin Number', pin.pin.toString());
        final num = int.tryParse(value ?? '');
        if (num == null) {
          showErrorToast('Invalid pin number.');
          return;
        }
        await DatabaseService.updatePin(pin.id, {'pin': num});
        showSuccessToast('Pin number updated.');
        return;
      case 'delete':
        final confirm = await _deleteConfirm(context);
        if (confirm) {
          await DatabaseService.deletePin(pin.id);
          showSuccessToast('Pin deleted.');
        }
        return;
    }
  }

  Future<String?> _editDialog(BuildContext context, String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _deleteConfirm(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pin'),
        content: const Text('Are you sure you want to delete this pin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    ) ?? false;
  }
}
