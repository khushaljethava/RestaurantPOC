import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/supabase/realtime_channels.dart';
import 'providers/acting_user.dart';
import 'providers/auth.dart';
import 'providers/connectivity.dart';
import 'providers/locale.dart';
import 'services/push_registration.dart';
import 'services/telemetry.dart';
import 'screens/audit_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/day_screen.dart';
import 'screens/device_mode_screen.dart';
import 'screens/group_screen.dart';
import 'screens/help_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/join_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/login_screen.dart';
import 'screens/my_sales_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/open_tables_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/pos_search_screen.dart';
import 'screens/receipt_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/settlement_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/stall_screen.dart';
import 'screens/stall_settings_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/table_bill_screen.dart';
import 'screens/tables_screen.dart';
import 'screens/today_screen.dart';
import 'screens/upi_verify_screen.dart';
import 'theme/ros_theme.dart';
import 'widgets/connection_banner.dart';
import 'widgets/glass.dart';
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
      if (loggedIn && (loc == '/login' || loc == '/signup')) {
        final invite = state.uri.queryParameters['invite'];
        if (invite != null && invite.isNotEmpty) {
          return '/join?code=${Uri.encodeComponent(invite)}';
        }
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: '/join',
        builder: (_, state) =>
            JoinScreen(initialCode: state.uri.queryParameters['code']),
      ),
      GoRoute(path: '/lock', builder: (_, _) => const LockScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/pos',
            builder: (context, state) {
              final table = state.uri.queryParameters['table'];
              return PosScreen(initialTableLabel: table);
            },
          ),
          GoRoute(path: '/today', builder: (_, _) => const TodayScreen()),
          GoRoute(
            path: '/settlement',
            builder: (_, _) => const SettlementScreen(),
          ),
          GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
        ],
      ),
      GoRoute(path: '/pos/search', builder: (_, _) => const PosSearchScreen()),
      GoRoute(path: '/stall', builder: (_, _) => const StallScreen()),
      GoRoute(path: '/stock', builder: (_, _) => const StockScreen()),
      GoRoute(path: '/tables', builder: (_, _) => const OpenTablesScreen()),
      GoRoute(path: '/manage/tables', builder: (_, _) => const TablesScreen()),
      GoRoute(
        path: '/manage/stall',
        builder: (_, _) => const StallSettingsScreen(),
      ),
      GoRoute(path: '/manage/group', builder: (_, _) => const GroupScreen()),
      GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
      GoRoute(path: '/day', builder: (_, _) => const DayScreen()),
      GoRoute(path: '/upi-verify', builder: (_, _) => const UpiVerifyScreen()),
      GoRoute(path: '/mysales', builder: (_, _) => const MySalesScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/device',
        builder: (_, _) => const DeviceModeScreen(),
      ),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/audit/:billId',
        builder: (context, state) =>
            AuditScreen(billId: state.pathParameters['billId']!),
      ),
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

class RosApp extends ConsumerStatefulWidget {
  const RosApp({super.key});

  @override
  ConsumerState<RosApp> createState() => _RosAppState();
}

class _RosAppState extends ConsumerState<RosApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkOnboardingAndVersion();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      realtimeManager.resubscribeAll();
      Telemetry.event('app_resumed');
      final acting = ref.read(actingUserProvider.notifier);
      if (acting.isLocked &&
          Supabase.instance.client.auth.currentSession != null) {
        final router = ref.read(_routerProvider);
        if (router.state.uri.path != '/lock' &&
            router.state.uri.path != '/login') {
          router.go('/lock');
        }
      }
    }
  }

  Future<void> _checkOnboardingAndVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final router = ref.read(_routerProvider);
    await PushRegistration.bindRouter(router);
    if (!(prefs.getBool('onboarding_done') ?? false) &&
        Supabase.instance.client.auth.currentSession != null) {
      router.go('/onboarding');
      return;
    }
    if (Supabase.instance.client.auth.currentSession != null &&
        router.state.uri.path == '/') {
      final mode = prefs.getString('device_mode') ?? 'counter';
      if (mode == 'stall') {
        router.go('/stall');
      } else {
        router.go('/pos');
      }
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final row = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'min_supported_version')
          .maybeSingle();
      final minV = row?['value'] as String?;
      if (minV != null && _isOlder(info.version, minV) && mounted) {
        await showDialog<void>(
          context: router.routerDelegate.navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Update required'),
            content: Text('Please update to $minV or newer.'),
            actions: [
              TextButton(onPressed: () {}, child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (_) {
      // Config table may not exist yet on old backends.
    }
  }

  bool _isOlder(String current, String minimum) {
    List<int> parts(String v) =>
        v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final a = parts(current);
    final b = parts(minimum);
    for (var i = 0; i < 3; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av < bv) return true;
      if (av > bv) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(_routerProvider);
    ref.watch(connectivityProvider);

    return MaterialApp.router(
      title: 'Stall Manager',
      theme: buildRosTheme(),
      locale: ref.watch(localeProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        return Column(
          children: [
            const ConnectionBanner(),
            Expanded(child: GlassBackground(child: child ?? const SizedBox())),
          ],
        );
      },
    );
  }
}
