import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity.dart';
import '../theme/ros_theme.dart';

class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    if (online) return const SizedBox.shrink();
    return Material(
      color: RosColors.error,
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Offline — writes are blocked',
            textAlign: TextAlign.center,
            style: TextStyle(color: RosColors.onError, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
