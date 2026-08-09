import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import '../providers/bill.dart';
import '../providers/stall.dart';
import '../providers/tables.dart';
import '../services/errors.dart';
import '../theme/ros_theme.dart';
import '../widgets/ros_ui.dart';

class OpenTablesScreen extends ConsumerWidget {
  const OpenTablesScreen({super.key});

  String _dur(DateTime? since) {
    if (since == null) return '';
    final m = DateTime.now().difference(since).inMinutes;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  Future<void> _move(BuildContext context, WidgetRef ref, String from) async {
    final to = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('Move $from →'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'New label')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Move')),
          ],
        );
      },
    );
    if (to == null || to.isEmpty) return;
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      await Supabase.instance.client.rpc(
        'merge_bill_labels',
        params: {
          'p_from_label': from,
          'p_to_label': to,
          'p_collector_stall_id': stallId,
        },
      );
      ref.invalidate(tableCardsProvider);
      ref.invalidate(openTableLabelsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mapError(e))));
      }
    }
  }

  Future<void> _merge(BuildContext context, WidgetRef ref, List<TableCard> cards) async {
    final occupied = cards.where((c) => c.occupied).map((c) => c.label).toList();
    if (occupied.length < 2) return;
    String? from = occupied.first;
    String? to = occupied[1];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Merge tables'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: from,
                decoration: const InputDecoration(labelText: 'From'),
                items: [for (final l in occupied) DropdownMenuItem(value: l, child: Text(l))],
                onChanged: (v) => setLocal(() => from = v),
              ),
              DropdownButtonFormField<String>(
                value: to,
                decoration: const InputDecoration(labelText: 'Into'),
                items: [for (final l in occupied) DropdownMenuItem(value: l, child: Text(l))],
                onChanged: (v) => setLocal(() => to = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Merge')),
          ],
        ),
      ),
    );
    if (ok != true || from == null || to == null || from == to) return;
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      await Supabase.instance.client.rpc(
        'merge_bill_labels',
        params: {
          'p_from_label': from,
          'p_to_label': to,
          'p_collector_stall_id': stallId,
        },
      );
      ref.invalidate(tableCardsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mapError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tableCardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open tables'),
        actions: [
          IconButton(
            tooltip: 'Merge',
            icon: const Icon(Icons.merge_type),
            onPressed: () {
              final cards = tables.asData?.value;
              if (cards != null) _merge(context, ref, cards);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(tableCardsProvider);
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
              childAspectRatio: 1.05,
            ),
            itemCount: cards.length,
            itemBuilder: (context, i) {
              final card = cards[i];
              final label = card.label;
              final occupied = card.occupied;
              return RosSurfaceCard(
                onTap: () => context.push(
                  occupied
                      ? '/table/$label'
                      : '/pos?table=${Uri.encodeComponent(label)}',
                ),
                onLongPress: occupied ? () => _move(context, ref, label) : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.table_restaurant,
                      size: 32,
                      color: occupied ? RosColors.primary : RosColors.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                          ),
                    ),
                    Text(
                      occupied
                          ? [
                              if (card.amount != null) Money.fromRupees(card.amount!).format(),
                              if (card.since != null) _dur(card.since),
                            ].where((e) => e.isNotEmpty).join(' · ')
                          : 'Free',
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
