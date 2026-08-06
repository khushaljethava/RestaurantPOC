import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Listenable that bumps when Supabase auth changes (for GoRouter refresh).
final authRefreshProvider = Provider<Listenable>((ref) {
  final notifier = ValueNotifier<int>(0);
  final sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
    notifier.value++;
  });
  ref.onDispose(() {
    sub.cancel();
    notifier.dispose();
  });
  return notifier;
});

final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authRefreshProvider);
  return Supabase.instance.client.auth.currentSession;
});
