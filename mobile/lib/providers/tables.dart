import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bill.dart';
import 'stall.dart';

/// Registered tables for the active stall.
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

final activeTableLabelsProvider = Provider<List<String>>((ref) {
  final rows = ref.watch(stallTablesProvider).asData?.value ?? const [];
  return [
    for (final r in rows)
      if (r['is_active'] == true) r['label'] as String,
  ];
});

class TableCard {
  const TableCard({
    required this.label,
    required this.occupied,
    this.amount,
    this.since,
  });

  final String label;
  final bool occupied;
  final double? amount;
  final DateTime? since;
}

final tableCardsProvider = FutureProvider<List<TableCard>>((ref) async {
  final stallId = ref.watch(activeStallIdProvider);
  if (stallId == null) return [];
  final registered = await ref.watch(stallTablesProvider.future);
  final openLabels = await ref.watch(openTableLabelsProvider.future);

  // Open bills with labels for amount/duration.
  final bills = await Supabase.instance.client
      .from('bill')
      .select('table_label, total, discount, created_at')
      .eq('collected_by_stall_id', stallId)
      .eq('status', 'open')
      .not('table_label', 'is', null);

  // Unbilled order mins for labels without bills.
  final orders = await Supabase.instance.client
      .from('orders')
      .select('table_label, created_at')
      .eq('recorded_by_stall_id', stallId)
      .isFilter('bill_id', null)
      .not('table_label', 'is', null)
      .neq('status', 'held')
      .neq('status', 'cancelled');

  final amountBy = <String, double>{};
  final sinceBy = <String, DateTime>{};
  for (final b in bills as List) {
    final label = (b['table_label'] as String).trim();
    amountBy[label] = (amountBy[label] ?? 0) +
        ((b['total'] as num).toDouble() - (b['discount'] as num? ?? 0).toDouble());
    final t = DateTime.tryParse(b['created_at'] as String? ?? '');
    if (t != null && (sinceBy[label] == null || t.isBefore(sinceBy[label]!))) {
      sinceBy[label] = t;
    }
  }
  for (final o in orders as List) {
    final label = (o['table_label'] as String?)?.trim();
    if (label == null || label.isEmpty) continue;
    final t = DateTime.tryParse(o['created_at'] as String? ?? '');
    if (t != null && (sinceBy[label] == null || t.isBefore(sinceBy[label]!))) {
      sinceBy[label] = t;
    }
  }

  final occupied = openLabels.toSet()..addAll(amountBy.keys);
  final cards = <String, TableCard>{};
  for (final r in registered) {
    if (r['is_active'] != true) continue;
    final label = r['label'] as String;
    cards[label] = TableCard(
      label: label,
      occupied: occupied.contains(label),
      amount: amountBy[label],
      since: sinceBy[label],
    );
  }
  for (final label in occupied) {
    cards[label] ??= TableCard(
      label: label,
      occupied: true,
      amount: amountBy[label],
      since: sinceBy[label],
    );
  }
  final list = cards.values.toList()..sort((a, b) => a.label.compareTo(b.label));
  return list;
});
