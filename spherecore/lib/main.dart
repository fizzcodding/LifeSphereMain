import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap/bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SphereCoreApp());
}

class SphereCoreApp extends StatelessWidget {
  const SphereCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: AppBootstrap(),
    );
  }
}
