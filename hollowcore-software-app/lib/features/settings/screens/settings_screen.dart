import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/hollow_core_brand.dart';

/// Placeholder settings screen for the HollowCore app.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -- About Section --
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const HollowCoreBrand(size: BrandSize.medium),
                  const SizedBox(height: 16),
                  Text(
                    'Version ${AppConstants.version}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // -- Placeholder Settings --
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  subtitle: const Text('Appearance settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implement theme picker
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: const Text('Manage alerts and updates'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implement notification settings
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('App info and licenses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implement about page
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
