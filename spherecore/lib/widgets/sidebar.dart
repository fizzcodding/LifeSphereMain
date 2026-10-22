import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import '../themes/app_theme.dart';
import '../utils/toast.dart';

class AppLogoTitle extends StatelessWidget {
  const AppLogoTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/logo_main.png', height: 30);
  }
}

// Translucent frosted-glass bottom navigation bar — Apple tab bar style
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
    Icons.square_rounded,
    Icons.favorite_rounded,
    Icons.tune_rounded,
    Icons.alarm_rounded,
    Icons.group_rounded,
    Icons.person_rounded,
  ];

  static const _labels = [
    'Devices',
    'Vitals',
    'Control',
    'Reminders',
    'Members',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final idx = _routes.indexOf(currentRoute).clamp(0, _routes.length - 1);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            border: Border(
              top: BorderSide(
                color: AppTheme.opaqueSeparator.withValues(alpha: 0.6),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 49 + bottomPad,
              child: Row(
                children: [
                  for (var i = 0; i < _routes.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: _icons[i],
                        label: _labels[i],
                        selected: i == idx,
                        onTap: () {
                          final route = _routes[i];
                          if (route != currentRoute) {
                            Navigator.pushReplacementNamed(context, route);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.accent : AppTheme.labelTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
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
      tooltip: 'Sign Out',
      icon: const Icon(Icons.logout_rounded, size: 20),
      color: AppTheme.accent,
      onPressed: () async {
        await AuthService.logout();
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        showSuccessToast('Signed out.');
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
        color: AppTheme.accent,
        onPressed: () => Navigator.pushReplacementNamed(context, '/profile'),
      ),
    );
  }
}

// Apple-style inset grouped card — white surface on grey background
class AppleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AppleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTheme.sp16,
      vertical: AppTheme.sp12,
    ),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        splashColor: AppTheme.accent.withValues(alpha: 0.06),
        highlightColor: AppTheme.accent.withValues(alpha: 0.04),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// Deprecated alias kept for backward compat with existing screens
class PremiumPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PremiumPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.sp16),
  });

  @override
  Widget build(BuildContext context) {
    return AppleCard(padding: padding, child: child);
  }
}

// Section header — iOS grouped table style ("DEVICES" above a group)
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.sp16, AppTheme.sp20, AppTheme.sp16, AppTheme.sp8,
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.07,
          color: AppTheme.labelSecondary,
        ),
      ),
    );
  }
}
