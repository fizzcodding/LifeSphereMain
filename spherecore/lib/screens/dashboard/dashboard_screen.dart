import 'dart:ui';
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
  void _showEditSheet(VirtualPin pin) {
    final labelCtrl = TextEditingController(text: pin.label);
    final pinCtrl   = TextEditingController(text: pin.pin.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GlassSheet(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppTheme.sp20,
            right: AppTheme.sp20,
            top: AppTheme.sp8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.sp32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppTheme.sp20),
                  decoration: BoxDecoration(
                    color: AppTheme.opaqueSeparator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Edit Device',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: AppTheme.sp20),
              TextField(
                controller: labelCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: AppTheme.sp12),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pin Number'),
              ),
              const SizedBox(height: AppTheme.sp24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sp12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final label = labelCtrl.text.trim();
                        final num   = int.tryParse(pinCtrl.text.trim());
                        if (label.isEmpty || num == null) {
                          showErrorToast('Invalid inputs.');
                          return;
                        }
                        try {
                          await DatabaseService.updatePinD(pin.id, label, num);
                          if (ctx.mounted) Navigator.pop(ctx);
                          showSuccessToast('Saved.');
                        } catch (_) {
                          showErrorToast('Could not save.');
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionsSheet(VirtualPin pin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => _GlassSheet(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp16,
                  vertical: AppTheme.sp8,
                ),
                child: Text(
                  pin.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.labelSecondary,
                    letterSpacing: 0.07,
                  ),
                ),
              ),
              const Divider(height: 0.5),
              _SheetAction(
                icon: Icons.edit_rounded,
                label: 'Edit',
                onTap: () {
                  Navigator.pop(sheet);
                  _showEditSheet(pin);
                },
              ),
              const Divider(height: 0.5, indent: _sp56),
              _SheetAction(
                icon: Icons.delete_rounded,
                label: 'Delete',
                destructive: true,
                onTap: () async {
                  Navigator.pop(sheet);
                  await DatabaseService.deletePin(pin.id);
                  showSuccessToast('Deleted.');
                },
              ),
              const SizedBox(height: AppTheme.sp8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleGps() async {
    if (LocationService.isTracking) {
      LocationService.stopTracking();
      showSuccessToast('GPS stopped.');
    } else {
      final ok = await LocationService.startTracking();
      ok ? showSuccessToast('GPS tracking on.') : showErrorToast('GPS failed to start.');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pinAsync = ref.watch(pinProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: _GlassAppBar(
        title: const AppLogoTitle(),
        actions: [
          IconButton(
            tooltip: 'GPS',
            icon: Icon(
              LocationService.isTracking
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              size: 22,
            ),
            color: LocationService.isTracking
                ? AppTheme.systemGreen
                : AppTheme.labelTertiary,
            onPressed: _toggleGps,
          ),
          const AppLogoutButton(),
        ],
      ),
      floatingActionButton: _AppleFAB(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const AddPinDialog(),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/dashboard'),
      body: pinAsync.when(
        data: (pins) => pins.isEmpty
            ? const _EmptyState()
            : _PinList(pins: pins, onLongPress: _showActionsSheet),
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (err, _) => Center(
          child: Text(
            'Could not load devices.',
            style: const TextStyle(color: AppTheme.labelSecondary),
          ),
        ),
      ),
    );
  }
}

// -------- sub-widgets --------

class _GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget> actions;

  const _GlassAppBar({required this.title, required this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: kToolbarHeight + topPad,
          padding: EdgeInsets.only(top: topPad),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.opaqueSeparator.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppTheme.sp16),
              title,
              const Spacer(),
              ...actions,
              const SizedBox(width: AppTheme.sp8),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;

  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusXl),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.danger : AppTheme.label;
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 17,
          color: color,
          letterSpacing: -0.41,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp20,
        vertical: AppTheme.sp4,
      ),
    );
  }
}

class _PinList extends StatelessWidget {
  final List<VirtualPin> pins;
  final void Function(VirtualPin) onLongPress;

  const _PinList({required this.pins, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppTheme.sp16,
        topPad + AppTheme.sp16,
        AppTheme.sp16,
        120,
      ),
      itemCount: pins.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const SectionHeader('Devices');
        }
        final pin = pins[index - 1];
        final isLast = index == pins.length;
        final isFirst = index == 1;
        return _PinCell(
          pin: pin,
          isFirst: isFirst,
          isLast: isLast,
          onLongPress: () => onLongPress(pin),
        );
      },
    );
  }
}

class _PinCell extends StatelessWidget {
  final VirtualPin pin;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onLongPress;

  const _PinCell({
    required this.pin,
    required this.isFirst,
    required this.isLast,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(AppTheme.radiusMd) : Radius.zero,
      bottom: isLast ? const Radius.circular(AppTheme.radiusMd) : Radius.zero,
    );

    return Material(
      color: AppTheme.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onLongPress: onLongPress,
        splashColor: AppTheme.accent.withValues(alpha: 0.06),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VirtualPinTile(pin: pin),
            if (!isLast)
              const Divider(height: 0.5, indent: AppTheme.sp16),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.square_rounded,
                size: 36,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: AppTheme.sp20),
            const Text(
              'No Devices',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: AppTheme.sp8),
            const Text(
              'Tap the + button to add your first virtual pin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.labelSecondary,
                letterSpacing: -0.24,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleFAB extends StatelessWidget {
  final VoidCallback onPressed;

  const _AppleFAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppTheme.accent,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }
}

// Convenience spacing constant used in sheets
const double _sp56 = 56.0;
