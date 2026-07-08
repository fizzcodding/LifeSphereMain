import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/virtual_pin.dart';
import '../../providers/pin_provider.dart';
import '../../services/firestore_service.dart';
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
    final labelController = TextEditingController(text: pin.label);
    final pinController = TextEditingController(text: pin.pin.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Virtual Pin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pin Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final label = labelController.text.trim();
              final pinNumber = int.tryParse(pinController.text.trim());
              if (label.isEmpty || pinNumber == null) {
                showErrorToast('Invalid inputs.');
                return;
              }
              try {
                await FirestoreService.updatePinD(pin.id, label, pinNumber);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
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
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppTheme.secondary),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditDialog(pin);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppTheme.danger),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await FirestoreService.deletePin(pin.id);
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
      final success = await LocationService.startTracking();
      success
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
        onPressed: () {
          showDialog(context: context, builder: (_) => const AddPinDialog());
        },
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/dashboard'),
      body: pinAsync.when(
        data: (pins) {
          if (pins.isEmpty) {
            return const _EmptyPins();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            itemCount: pins.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
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
        error: (error, _) => Center(child: Text('Error loading pins: $error')),
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
