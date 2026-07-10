import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/members_service.dart';
import '../../themes/app_theme.dart';
import '../../utils/toast.dart';

class AddMemberDialog extends StatefulWidget {
  const AddMemberDialog({super.key});

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _nameCtrl = TextEditingController();
  String _role = 'Household';
  File? _image;
  bool _loading = false;
  final _svc = MembersService();

  final _roles = ['Household', 'Guest', 'Relative'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        showErrorToast('Camera permission denied.');
        return;
      }
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) setState(() => _image = File(picked.path));
    } catch (_) {
      showErrorToast('Failed to pick image.');
    }
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () { Navigator.of(ctx).pop(); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () { Navigator.of(ctx).pop(); _pickImage(ImageSource.camera); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { showErrorToast('Please enter a name.'); return; }
    if (_image == null) { showErrorToast('Please capture or select an image.'); return; }

    setState(() => _loading = true);

    try {
      final ok = await _svc.enrollMember(name, _image!);
      if (ok) {
        showSuccessToast('$name enrolled successfully.');
        if (mounted) Navigator.pop(context, true);
      } else {
        showErrorToast('Failed to enroll member.');
      }
    } catch (_) {
      showErrorToast('An error occurred during enrollment.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _showSourcePicker(context),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.28),
                    width: 2,
                  ),
                ),
                child: _image != null
                    ? ClipOval(
                        child: Image.file(_image!, width: 120, height: 120, fit: BoxFit.cover),
                      )
                    : Icon(Icons.add_a_photo_rounded, size: 40, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge),
              ),
              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) { if (v != null) setState(() => _role = v); },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.surface),
                )
              : const Text('Save Member'),
        ),
      ],
    );
  }
}
