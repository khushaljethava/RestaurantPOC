import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StallMembership {
  StallMembership({
    required this.stallId,
    required this.stallName,
    required this.role,
  });

  final String stallId;
  final String stallName;
  final String role;
}

class PeerStall {
  PeerStall({required this.id, required this.name});

  final String id;
  final String name;
}

final membershipsProvider = FutureProvider<List<StallMembership>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return [];

  final rows = await Supabase.instance.client
      .from('staff_membership')
      .select('stall_id, role, stall:stall_id(name)')
      .eq('user_id', uid);

  return (rows as List).map((r) {
    final stall = r['stall'] as Map<String, dynamic>?;
    return StallMembership(
      stallId: r['stall_id'] as String,
      stallName: (stall?['name'] as String?) ?? 'Stall',
      role: r['role'] as String,
    );
  }).toList();
});

class ActiveStallOverride extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

/// Selected stall id; null means "use first membership".
final activeStallOverrideProvider =
    NotifierProvider<ActiveStallOverride, String?>(ActiveStallOverride.new);

final activeStallIdProvider = Provider<String?>((ref) {
  final memberships = ref.watch(membershipsProvider).asData?.value;
  if (memberships == null || memberships.isEmpty) return null;
  final override = ref.watch(activeStallOverrideProvider);
  if (override != null && memberships.any((m) => m.stallId == override)) {
    return override;
  }
  return memberships.first.stallId;
});

/// Role on the active stall; null until memberships load.
final activeRoleProvider = Provider<String?>((ref) {
  final memberships = ref.watch(membershipsProvider).asData?.value;
  final id = ref.watch(activeStallIdProvider);
  if (memberships == null || id == null) return null;
  for (final m in memberships) {
    if (m.stallId == id) return m.role;
  }
  return null;
});

/// Owner/manager can edit menu and tables — mirrors the RLS write policies.
final canManageProvider = Provider<bool>((ref) {
  final role = ref.watch(activeRoleProvider);
  return role == 'owner' || role == 'manager';
});

final menuStallsProvider = FutureProvider<List<PeerStall>>((ref) async {
  final activeId = ref.watch(activeStallIdProvider);
  if (activeId == null) return [];

  final me = await Supabase.instance.client
      .from('stall')
      .select('id, name, group_id')
      .eq('id', activeId)
      .maybeSingle();
  if (me == null) return [];

  final groupId = me['group_id'] as String?;
  if (groupId == null) {
    return [PeerStall(id: me['id'] as String, name: me['name'] as String)];
  }

  final rows = await Supabase.instance.client
      .from('stall')
      .select('id, name')
      .eq('group_id', groupId)
      .order('name');

  return (rows as List)
      .map((r) => PeerStall(id: r['id'] as String, name: r['name'] as String))
      .toList();
});
