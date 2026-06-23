import 'package:flutter/material.dart';
import '../../models/virtual_pin.dart';
import '../../services/firestore_service.dart';
import '../../themes/app_theme.dart';
import '../../utils/toast.dart';

class AddPinDialog extends StatefulWidget {
  const AddPinDialog({super.key});
  @override
  State<AddPinDialog> createState() => _AddPinDialogState();
}

class _AddPinDialogState extends State<AddPinDialog> {
  final _labelController = TextEditingController();
  final _pinController = TextEditingController();
  bool isLoading = false;
  @override
  void dispose() {
    _labelController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _addPin() async {
    final label = _labelController.text.trim();
    final pin = int.tryParse(_pinController.text.trim());
    if (label.isEmpty || pin == null) {
      showErrorToast('Please enter a valid label and pin number');
      return;
    }
    setState(() => isLoading = true);
    final newPin = VirtualPin(id: '', label: label, pin: pin, state: false);
    try {
      await FirestoreService.addPin(newPin);
      showSuccessToast('Pin added');
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      showErrorToast('Failed to add pin');
    } finally {
      if (mounted) setState(() => isLoading = false);
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
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pin'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _addPin,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.surface,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
