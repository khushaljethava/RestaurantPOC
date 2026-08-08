import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bill.dart';
import 'stall.dart';

/// Registered tables for the active stall. Distinct from
/// `openTableLabelsProvider` in bill.dart, which lists tables that currently
/// have unbilled orders on them.
final stallTablesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final stallId = ref.watch(activeStallIdProvider);
  if (stallId == null) return [];
  final rows = await Supabase.instance.client
      .from('restaurant_table')
      .select('id, label, seats, is_active, sort_order')
      .eq('stall_id', stallId)
      .order('sort_order')
      .order('label');
  return List<Map<String, dynamic>>.from(rows as List);
});

/// Labels offered in the POS table picker — active tables only.
final activeTableLabelsProvider = Provider<List<String>>((ref) {
  final rows = ref.watch(stallTablesProvider).asData?.value ?? const [];
  return [
    for (final r in rows)
      if (r['is_active'] == true) r['label'] as String,
  ];
});

/// One card on the Open tables screen.
class TableCard {
  const TableCard({required this.label, required this.occupied});

  final String label;

  /// True when unbilled orders sit on this label. Unoccupied cards are
  /// registered-but-empty tables — tapping one starts an order there.
  final bool occupied;
}

/// Registered tables merged with tables that currently hold unbilled orders.
/// Both halves matter: a registered table with no orders must be seatable, and
/// a label typed ad-hoc at the POS (never registered) must not vanish.
final tableCardsProvider = Provider<AsyncValue<List<TableCard>>>((ref) {
  final registered = ref.watch(stallTablesProvider);
  final open = ref.watch(openTableLabelsProvider);

  return registered.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (rows) => open.when(
      loading: () => const AsyncValue.loading(),
      error: AsyncValue.error,
      data: (openLabels) {
        final occupied = openLabels.toSet();
        final cards = <String, TableCard>{};
        for (final r in rows) {
          if (r['is_active'] != true) continue;
          final label = r['label'] as String;
          cards[label] = TableCard(
            label: label,
            occupied: occupied.contains(label),
          );
        }
        for (final label in openLabels) {
          cards[label] ??= TableCard(label: label, occupied: true);
        }
        final list = cards.values.toList()
          ..sort((a, b) => a.label.compareTo(b.label));
        return AsyncValue.data(list);
      },
    ),
  );
});
