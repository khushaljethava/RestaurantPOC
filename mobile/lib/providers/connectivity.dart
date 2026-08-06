import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityProvider);
  return async.when(
    data: (results) =>
        results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none),
    loading: () => true,
    error: (_, _) => true,
  );
});
