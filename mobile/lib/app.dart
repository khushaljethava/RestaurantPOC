import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth.dart';
import 'providers/connectivity.dart';
import 'screens/checkout_screen.dart';
import 'screens/held_screen.dart';
import 'screens/home_screen.dart';
import 'screens/join_screen.dart';
import 'screens/login_screen.dart';
import 'screens/open_tables_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/receipt_screen.dart';
import 'screens/settlement_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/stall_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/table_bill_screen.dart';
import 'screens/today_screen.dart';
import 'theme/ros_theme.dart';
import 'widgets/connection_banner.dart';
import 'widgets/shell_scaffold.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRefreshProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuth = loc == '/login' || loc == '/join' || loc == '/signup';
      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && (loc == '/login' || loc == '/signup')) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/join', builder: (_, _) => const JoinScreen()),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/today', builder: (_, _) => const TodayScreen()),
          GoRoute(path: '/held', builder: (_, _) => const HeldScreen()),
          GoRoute(
              path: '/settlement',
              builder: (_, _) => const SettlementScreen()),
        ],
      ),
      GoRoute(
        path: '/pos',
        builder: (context, state) {
          final table = state.uri.queryParameters['table'];
          return PosScreen(initialTableLabel: table);
        },
      ),
      GoRoute(path: '/stall', builder: (_, _) => const StallScreen()),
      GoRoute(path: '/stock', builder: (_, _) => const StockScreen()),
      GoRoute(path: '/tables', builder: (_, _) => const OpenTablesScreen()),
      GoRoute(
        path: '/table/:label',
        builder: (context, state) => TableBillScreen(
          tableLabel: Uri.decodeComponent(state.pathParameters['label']!),
        ),
      ),
      GoRoute(
        path: '/checkout/:billId',
        builder: (context, state) =>
            CheckoutScreen(billId: state.pathParameters['billId']!),
      ),
      GoRoute(
        path: '/receipt/:billId',
        builder: (context, state) =>
            ReceiptScreen(billId: state.pathParameters['billId']!),
      ),
    ],
  );
});

class RosApp extends ConsumerWidget {
  const RosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    ref.watch(connectivityProvider);

    return MaterialApp.router(
      title: 'ROS',
      theme: buildRosTheme(),
      routerConfig: router,
      builder: (context, child) {
        return Column(
          children: [
            const ConnectionBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
