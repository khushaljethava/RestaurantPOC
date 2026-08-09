import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'glass.dart';

class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.child});

  final Widget child;

  static const _paths = ['/', '/pos', '/today', '/more'];

  int _indexFor(String location) {
    if (location.startsWith('/pos')) return 1;
    if (location.startsWith('/today')) {
      return 2;
    }
    if (location.startsWith('/more') ||
        location.startsWith('/settlement') ||
        location.startsWith('/settings') ||
        location.startsWith('/day') ||
        location.startsWith('/mysales')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale),
        label: 'Sell',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Orders',
      ),
      NavigationDestination(
        icon: Icon(Icons.more_horiz),
        selectedIcon: Icon(Icons.more_horiz),
        label: 'More',
      ),
    ];

    final index = _indexFor(location).clamp(0, destinations.length - 1);

    return Scaffold(
      extendBody: false,
      body: child,
      bottomNavigationBar: GlassBar(
        child: NavigationBar(
          selectedIndex: index,
          destinations: destinations,
          onDestinationSelected: (i) => context.go(_paths[i]),
        ),
      ),
    );
  }
}
