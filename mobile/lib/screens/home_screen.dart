import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/stall.dart';
import '../services/push_registration.dart';
import '../theme/ros_theme.dart';
import '../widgets/ros_ui.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(membershipsProvider);
    final activeId = ref.watch(activeStallIdProvider);

    ref.listen(membershipsProvider, (prev, next) {
      final list = next.asData?.value;
      if (list == null || list.isEmpty) return;
      final id = activeId ?? list.first.stallId;
      PushRegistration.registerForStall(id);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ROS'),
        actions: [
          IconButton(
            tooltip: 'Join with invite',
            onPressed: () => context.push('/join'),
            icon: const Icon(Icons.qr_code),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: memberships.when(
        loading: () => const RosLoading(),
        error: (e, _) => RosEmpty(message: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return RosEmpty(
              message: 'No stall membership yet.',
              action: FilledButton(
                onPressed: () => context.push('/join'),
                child: const Text('Enter invite code'),
              ),
            );
          }

          final active = list.firstWhere(
            (m) => m.stallId == activeId,
            orElse: () => list.first,
          );
          final canSettle =
              active.role == 'owner' || active.role == 'manager';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (list.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: active.stallId,
                  decoration: const InputDecoration(
                    labelText: 'Active stall',
                  ),
                  items: [
                    for (final m in list)
                      DropdownMenuItem(
                        value: m.stallId,
                        child: Text(m.stallName),
                      ),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    ref.read(activeStallOverrideProvider.notifier).set(id);
                    PushRegistration.registerForStall(id);
                  },
                ),
                const SizedBox(height: 16),
              ],
              Text(
                active.stallName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 40 / 32,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: RosColors.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      active.role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: RosColors.onPrimaryContainer,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stall ID: ${active.stallId.substring(0, 8)}…',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              RosSurfaceCard(
                padding: const EdgeInsets.all(16),
                onTap: () => context.push('/pos'),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: RosColors.primary,
                      child: Icon(Icons.add_circle,
                          color: RosColors.onPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New order',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            'Start a fresh transaction',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: RosColors.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              RosSurfaceCard(
                padding: EdgeInsets.zero,
                child: RosNavTile(
                  icon: Icons.pause_circle,
                  label: 'Held orders',
                  subtitle: 'Resume paused carts',
                  leadingBg: RosColors.pendingContainer,
                  leadingFg: RosColors.pending,
                  accentRail: RosColors.pending,
                  onTap: () => context.go('/held'),
                ),
              ),
              const SizedBox(height: 16),
              RosSurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    RosNavTile(
                      icon: Icons.kitchen,
                      label: 'Stall order screen',
                      showDivider: true,
                      onTap: () => context.push('/stall'),
                    ),
                    RosNavTile(
                      icon: Icons.inventory_2,
                      label: 'Item availability',
                      showDivider: true,
                      onTap: () => context.push('/stock'),
                    ),
                    RosNavTile(
                      icon: Icons.table_restaurant,
                      label: 'Open tables',
                      onTap: () => context.push('/tables'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RosSurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    RosNavTile(
                      icon: Icons.receipt_long,
                      label: "Today's orders",
                      showDivider: canSettle,
                      onTap: () => context.go('/today'),
                    ),
                    if (canSettle)
                      RosNavTile(
                        icon: Icons.account_balance_wallet,
                        label: "Today's settlement",
                        onTap: () => context.go('/settlement'),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
