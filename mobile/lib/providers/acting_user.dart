import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Acting staff on a shared device (PIN unlock). Falls back to session user.
class ActingUser {
  const ActingUser({required this.userId, this.unlockedAt});

  final String userId;
  final DateTime? unlockedAt;
}

class ActingUserNotifier extends Notifier<ActingUser?> {
  static const idleMinutes = 3;

  @override
  ActingUser? build() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    return ActingUser(userId: uid, unlockedAt: DateTime.now());
  }

  void unlock(String userId) {
    state = ActingUser(userId: userId, unlockedAt: DateTime.now());
  }

  void lock() => state = null;

  void touch() {
    final s = state;
    if (s != null) {
      state = ActingUser(userId: s.userId, unlockedAt: DateTime.now());
    }
  }

  bool get isLocked {
    final s = state;
    if (s == null || s.unlockedAt == null) return true;
    return DateTime.now().difference(s.unlockedAt!) >
        const Duration(minutes: idleMinutes);
  }

  String? get actingStaffId => state?.userId;
}

final actingUserProvider =
    NotifierProvider<ActingUserNotifier, ActingUser?>(ActingUserNotifier.new);
