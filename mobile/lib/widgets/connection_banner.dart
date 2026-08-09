import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/connectivity.dart';
import '../theme/ros_theme.dart';

class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    if (online) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: RosColors.error,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.offlineWritesPaused,
                  style: const TextStyle(color: RosColors.onError, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(connectivityProvider),
                style: TextButton.styleFrom(foregroundColor: RosColors.onError),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
