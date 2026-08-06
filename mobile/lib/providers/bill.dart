import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'stall.dart';

/// Unbilled table labels (orders with table_label and null bill_id).
final openTableLabelsProvider = FutureProvider<List<String>>((ref) async {
  final stallId = ref.watch(activeStallIdProvider);
  if (stallId == null) return [];
  final rows = await Supabase.instance.client
      .from('orders')
      .select('table_label')
      // RLS is group-wide, so without this a food-court counter sees peers'
      // tables mixed into its own list.
      .eq('recorded_by_stall_id', stallId)
      .isFilter('bill_id', null)
      .not('table_label', 'is', null)
      .neq('status', 'held')
      .neq('status', 'cancelled');

  final labels = <String>{};
  for (final r in rows as List) {
    final t = r['table_label'] as String?;
    if (t != null && t.trim().isNotEmpty) labels.add(t.trim());
  }
  final list = labels.toList()..sort();
  return list;
});

final openBillsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final stallId = ref.watch(activeStallIdProvider);
  if (stallId == null) return [];
  final rows = await Supabase.instance.client
      .from('bill')
      .select('id, total, table_label, status, created_at, collected_by_stall_id')
      .eq('status', 'open')
      .eq('collected_by_stall_id', stallId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});
