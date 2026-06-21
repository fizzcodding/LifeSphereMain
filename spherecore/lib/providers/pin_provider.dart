import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/virtual_pin.dart';

final authProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);
final pinProvider = StreamProvider<List<VirtualPin>>((ref) {
  final authAsync = ref.watch(authProvider);
  return authAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return FirestoreService.getPins();
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
}); 