import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import '../themes/app_theme.dart';
import '../utils/toast.dart';

class AppLogoTitle extends StatelessWidget {
  const AppLogoTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/logo_main.png', height: 34);
  }
}

class AppBottomNav extends StatelessWidget {
  final String currentRoute;

  const AppBottomNav({super.key, required this.currentRoute});

  static const _routes = [
    '/dashboard',
    '/vital32',
    '/control',
    '/reminders',
    '/members',
    '/profile',
  ];

  static const _icons = [
    Icons.memory_rounded,
    Icons.monitor_heart_rounded,
    Icons.tune_rounded,
    Icons.alarm_rounded,
    Icons.group_rounded,
    Icons.person_rounded,
  ];

  static const _labels = [
    'Dashboard',
    'Vital32',
    'Control',
    'Reminders',
    'Members',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final routeIndex = _routes.indexOf(currentRoute);
    final index = routeIndex < 0 ? 0 : routeIndex;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [AppTheme.softShadow],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: index,
          type: BottomNavigationBarType.fixed,
          items: [
            for (var i = 0; i < _icons.length; i++)
              BottomNavigationBarItem(icon: Icon(_icons[i]), label: _labels[i]),
          ],
          onTap: (nextIndex) {
            final route = _routes[nextIndex];
            if (route != currentRoute) {
              Navigator.pushReplacementNamed(context, route);
            }
          },
        ),
      ),
    );
  }
}

class AppLogoutButton extends StatelessWidget {
  const AppLogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Logout',
      icon: const Icon(Icons.logout_rounded),
      onPressed: () async {
        await AuthService.logout();
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        showSuccessToast('Logged out successfully.');
      },
    );
  }
}

class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    return Tooltip(
      message: email ?? 'Profile',
      child: IconButton(
        icon: const Icon(Icons.account_circle_rounded),
        onPressed: () => Navigator.pushReplacementNamed(context, '/profile'),
      ),
    );
  }
}

class PremiumPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PremiumPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: [AppTheme.softShadow],
      ),
      child: child,
    );
  }
}
