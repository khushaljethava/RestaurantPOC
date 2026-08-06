import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/bill.dart';
import '../theme/ros_theme.dart';
import '../widgets/ros_ui.dart';

class OpenTablesScreen extends ConsumerWidget {
  const OpenTablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(openTableLabelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open tables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(openTableLabelsProvider),
          ),
        ],
      ),
      body: tables.when(
        loading: () => const RosLoading(),
        error: (e, _) => RosEmpty(message: '$e'),
        data: (labels) {
          if (labels.isEmpty) {
            return const RosEmpty(message: 'No open table tabs');
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: labels.length,
            itemBuilder: (context, i) {
              final label = labels[i];
              return RosSurfaceCard(
                onTap: () => context.push('/table/$label'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.table_restaurant,
                        size: 32, color: RosColors.primary),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                          ),
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
