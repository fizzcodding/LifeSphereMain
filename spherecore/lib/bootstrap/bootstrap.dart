import 'package:firebase_auth/firebase_auth.dart';
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
  late final Future<dynamic> _init;

  @override
  void initState() {
    super.initState();
    _init = _initializeSystem();
  }

  Future<dynamic> _initializeSystem() async {
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Firebase initialization failed:\n${snapshot.error}',
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
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return MaterialApp(
                  home: const SplashScreen(),
                  routes: {
                    '/login': (context) => const LoginScreen(),
                    '/dashboard': (context) => const DashboardScreen(),
                  },
                );
              }

              final user = snapshot.data;
              if (user != null) {
                ReminderScheduler().start();
              } else {
                ReminderScheduler().stop();
              }

              return Consumer(
                builder: (context, ref, child) {
                  final themeMode = ref.watch(themeProvider);
                  return MaterialApp(
                    debugShowCheckedModeBanner: false,
                    title: 'SphereCore',
                    themeMode: themeMode,
                    theme: AppTheme.lightTheme,
                    home: user == null
                        ? const LoginScreen()
                        : const DashboardScreen(),
                    routes: {
                      '/login': (context) => const LoginScreen(),
                      '/reminders': (_) => const ReminderScreen(),
                      '/dashboard': (context) => const DashboardScreen(),
                      '/profile': (context) => const ProfileScreen(),
                      '/vital32': (context) => const Vital32Screen(),
                      '/members': (context) => const MembersScreen(),
                      '/control': (context) => const ControlScreen(),
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
