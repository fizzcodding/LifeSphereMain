import 'package:flutter/material.dart';
import '../../models/virtual_pin.dart';
import '../../services/database_service.dart';
import '../../themes/app_theme.dart';
import '../../utils/toast.dart';

class AddPinDialog extends StatefulWidget {
  const AddPinDialog({super.key});

  @override
  State<AddPinDialog> createState() => _AddPinDialogState();
}

class _AddPinDialogState extends State<AddPinDialog> {
  final _labelCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final label = _labelCtrl.text.trim();
    final pin = int.tryParse(_pinCtrl.text.trim());
    if (label.isEmpty || pin == null) {
      showErrorToast('Please enter a valid label and pin number');
      return;
    }

    setState(() => _loading = true);
    try {
      await DatabaseService.addPin(VirtualPin(id: '', label: label, pin: pin, state: false));
      showSuccessToast('Pin added');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      showErrorToast('Failed to add pin');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Virtual Pin'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pin'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _add,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.surface),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
