import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/virtual_pin.dart';
import '../../providers/pin_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../themes/app_theme.dart';
import '../../utils/toast.dart';
import '../../utils/virtual_pin_tile.dart';
import '../../widgets/sidebar.dart';
import 'add_pin_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  void _showEditDialog(VirtualPin pin) {
    final labelCtrl = TextEditingController(text: pin.label);
    final pinCtrl = TextEditingController(text: pin.pin.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Virtual Pin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pin Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final label = labelCtrl.text.trim();
              final num = int.tryParse(pinCtrl.text.trim());
              if (label.isEmpty || num == null) {
                showErrorToast('Invalid inputs.');
                return;
              }
              try {
                await DatabaseService.updatePinD(pin.id, label, num);
                if (ctx.mounted) Navigator.pop(ctx);
                showSuccessToast('Pin updated.');
              } catch (_) {
                showErrorToast('Failed to update.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(VirtualPin pin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppTheme.secondary),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheet);
                  _showEditDialog(pin);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppTheme.danger),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(sheet);
                  await DatabaseService.deletePin(pin.id);
                  showSuccessToast('Pin deleted.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleGps() async {
    if (LocationService.isTracking) {
      LocationService.stopTracking();
      showSuccessToast('GPS tracking stopped.');
    } else {
      final ok = await LocationService.startTracking();
      ok
          ? showSuccessToast('GPS tracking started.')
          : showErrorToast('Failed to start GPS tracking.');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pinAsync = ref.watch(pinProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppLogoTitle(),
        actions: [
          IconButton(
            tooltip: 'GPS',
            icon: Icon(
              LocationService.isTracking
                  ? Icons.satellite_alt_rounded
                  : Icons.satellite_alt_outlined,
              color: LocationService.isTracking ? AppTheme.secondary : null,
            ),
            onPressed: _toggleGps,
          ),
          const AppLogoutButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (_) => const AddPinDialog()),
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/dashboard'),
      body: pinAsync.when(
        data: (pins) {
          if (pins.isEmpty) return const _EmptyPins();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            itemCount: pins.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pin = pins[index];
              return GestureDetector(
                onLongPress: () => _showMoreOptions(pin),
                child: VirtualPinTile(pin: pin),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading pins: $err')),
      ),
    );
  }
}

class _EmptyPins extends StatelessWidget {
  const _EmptyPins();

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
                Icons.memory_rounded,
                size: 48,
                color: AppTheme.secondary.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 16),
              Text('No devices yet', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Add a virtual pin to control your first device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
