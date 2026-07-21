thimport 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/control/control_screen.dart';
import '../screens/dashboard/reminder_screen.dart';
import '../screens/members/member_screen.dart';
import '../themes/app_theme.dart';
import '../firebase_options.dart';
import '../providers/theme_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/vital32/vital32_screen.dart';
import '../services/notification_service.dart';
import '../services/reminder_scheduler.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<FirebaseApp> _init;

  @override
  void initState() {
    super.initState();
    _init = _initSystem();
  }

  Future<FirebaseApp> _initSystem() async {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      await NotificationService().init();
      await NotificationService().requestPermissions();
    } catch (_) {}
    return app;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done) {
          if (snap.hasError) {
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Firebase initialization failed:\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.danger),
                    ),
                  ),
                ),
              ),
            );
          }
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return MaterialApp(
                  home: const SplashScreen(),
                  routes: {
                    '/login': (_) => const LoginScreen(),
                    '/dashboard': (_) => const DashboardScreen(),
                  },
                );
              }

              final user = snap.data;
              if (user != null) {
                ReminderScheduler().start();
              } else {
                ReminderScheduler().stop();
              }

              return Consumer(
                builder: (context, ref, _) {
                  final theme = ref.watch(themeProvider);
                  return MaterialApp(
                    debugShowCheckedModeBanner: false,
                    title: 'SphereCore',
                    themeMode: theme,
                    theme: AppTheme.lightTheme,
                    home: user == null ? const LoginScreen() : const DashboardScreen(),
                    routes: {
                      '/login': (_) => const LoginScreen(),
                      '/reminders': (_) => const ReminderScreen(),
                      '/dashboard': (_) => const DashboardScreen(),
                      '/profile': (_) => const ProfileScreen(),
                      '/vital32': (_) => const Vital32Screen(),
                      '/members': (_) => const MembersScreen(),
                      '/control': (_) => const ControlScreen(),
                    },
                  );
                },
              );
            },
          );
        }

        return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }
}
