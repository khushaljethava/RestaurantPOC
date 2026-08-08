import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/bill.dart';
import '../providers/tables.dart';
import '../theme/ros_theme.dart';
import '../widgets/ros_ui.dart';
import '../services/errors.dart';

class OpenTablesScreen extends ConsumerWidget {
  const OpenTablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tableCardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open tables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(openTableLabelsProvider);
              ref.invalidate(stallTablesProvider);
            },
          ),
        ],
      ),
      body: tables.when(
        loading: () => const RosLoading(),
        error: (e, _) => RosEmpty(message: mapError(e)),
        data: (cards) {
          if (cards.isEmpty) {
            return const RosEmpty(
              message:
                  'No tables yet. Add tables in Manage tables, or type a '
                  'label when taking an order.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: cards.length,
            itemBuilder: (context, i) {
              final label = cards[i].label;
              final occupied = cards[i].occupied;
              return RosSurfaceCard(
                // An empty table has no bill to open yet, so seat it by
                // starting an order on that label instead.
                onTap: () => context.push(
                  occupied
                      ? '/table/$label'
                      : '/pos?table=${Uri.encodeComponent(label)}',
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.table_restaurant,
                      size: 32,
                      color: occupied
                          ? RosColors.primary
                          : RosColors.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 28),
                    ),
                    Text(
                      occupied ? 'Open tab' : 'Free',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
