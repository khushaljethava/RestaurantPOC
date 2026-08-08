import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/stall.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(membershipsProvider).asData?.value ?? [];
    final activeId = ref.watch(activeStallIdProvider);
    final active = memberships.isEmpty
        ? null
        : memberships.firstWhere(
            (m) => m.stallId == activeId,
            orElse: () => memberships.first,
          );
    final canReports =
        active != null && (active.role == 'owner' || active.role == 'manager');

    Widget tile(String title, IconData icon, String route) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          tile('Shift', Icons.schedule, '/shift'),
          tile('Pickup board', Icons.shopping_bag_outlined, '/pickup'),
          tile('Stock', Icons.inventory_2_outlined, '/stock'),
          tile('My sales', Icons.person_outline, '/mysales'),
          if (canReports) tile('Day summary', Icons.today, '/day'),
          if (canReports) tile('Settlement', Icons.handshake_outlined, '/settlement'),
          tile('Held orders', Icons.pause_circle_outline, '/held'),
          tile('Notifications', Icons.notifications_outlined, '/notifications'),
          tile('Settings', Icons.settings_outlined, '/settings'),
          tile('Help', Icons.help_outline, '/help'),
        ],
      ),
    );
  }
}
