import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/stall.dart';
import 'glass.dart';

class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.child});

  final Widget child;

  static const _paths = ['/', '/today', '/held', '/settlement'];

  int _indexFor(String location, bool canReports) {
    if (location.startsWith('/today')) return 1;
    if (location.startsWith('/held')) return 2;
    if (location.startsWith('/settlement')) return canReports ? 3 : 0;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
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

    if (location.startsWith('/settlement') && !canReports) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
    }

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale),
        label: 'Register',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Orders',
      ),
      const NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'History',
      ),
      if (canReports)
        const NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: 'Reports',
        ),
    ];

    final index = _indexFor(
      location,
      canReports,
    ).clamp(0, destinations.length - 1);

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: GlassBar(
        child: NavigationBar(
          selectedIndex: index,
          destinations: destinations,
          onDestinationSelected: (i) {
            final path = canReports ? _paths[i] : _paths[i.clamp(0, 2)];
            context.go(path);
          },
        ),
      ),
    );
  }
}
