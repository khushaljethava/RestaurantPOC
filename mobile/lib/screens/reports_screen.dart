import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';
import '../widgets/ros_ui.dart';

/// "What sold today" — the four `sales_by_*` RPCs on one scrollable page.
/// Deliberately read-only and summary-level; CSV and long ranges stay on the
/// web admin. Each RPC is already scoped by RLS to the caller's own stalls.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

enum _Range {
  today('Today', 0),
  week('7 days', 6),
  month('30 days', 29);

  const _Range(this.label, this.daysBack);
  final String label;
  final int daysBack;
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  var _range = _Range.today;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _modes = [];
  List<Map<String, dynamic>> _collectors = [];
  List<Map<String, dynamic>> _stalls = [];
  Map<String, String> _names = {};
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    // Local midnight converted to UTC — the RPCs compare against timestamptz,
    // and a naive UTC midnight would cut the day at 05:30 IST.
    final from = midnight.subtract(Duration(days: _range.daysBack)).toUtc();
    final to = midnight.add(const Duration(days: 1)).toUtc();
    final params = {
      'p_from': from.toIso8601String(),
      'p_to': to.toIso8601String(),
    };
    try {
      final db = Supabase.instance.client;
      final results = await Future.wait([
        db.rpc('sales_by_item', params: params),
        db.rpc('sales_by_payment_mode', params: params),
        db.rpc('sales_by_collector', params: params),
        db.rpc('sales_by_stall', params: params),
        db.from('stall').select('id, name'),
      ]);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(results[0] as List);
        _modes = List<Map<String, dynamic>>.from(results[1] as List);
        _collectors = List<Map<String, dynamic>>.from(results[2] as List);
        _stalls = List<Map<String, dynamic>>.from(results[3] as List);
        _names = {
          for (final s in results[4] as List)
            s['id'] as String: s['name'] as String,
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
        _loading = false;
      });
    }
  }

  String _name(String? id) =>
      id == null ? 'Unknown' : (_names[id] ?? id.substring(0, 8));

  double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final revenue = _stalls.fold<double>(0, (s, r) => s + _num(r['revenue']));
    final orders = _stalls.fold<int>(
      0,
      (s, r) => s + ((r['order_count'] as num?)?.toInt() ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_Range>(
              segments: [
                for (final r in _Range.values)
                  ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {_range},
              onSelectionChanged: (s) {
                setState(() => _range = s.first);
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const RosLoading()
                : _error != null
                ? RosEmpty(message: _error!)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      RosSurfaceCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Revenue',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  MoneyText(
                                    revenue,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Orders',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$orders',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _Section(
                        title: 'Top items',
                        empty: 'Nothing sold in this period',
                        rows: [
                          // Server sorts by revenue already; cap the list so a
                          // 200-item menu doesn't become an endless scroll.
                          for (final r in _items.take(15))
                            _Row(
                              label: r['item_name'] as String? ?? 'Item',
                              trailing: MoneyText(_num(r['revenue'])),
                              caption: '${_num(r['qty']).toStringAsFixed(0)} ×',
                            ),
                        ],
                      ),

                      _Section(
                        title: 'Payment methods',
                        empty: 'No payments yet',
                        rows: [
                          for (final r in _modes)
                            _Row(
                              label: (r['method'] as String? ?? '')
                                  .toUpperCase(),
                              trailing: MoneyText(_num(r['amount'])),
                              caption: '${r['payment_count'] ?? 0} payments',
                            ),
                        ],
                      ),

                      _Section(
                        title: 'Collected by',
                        empty: 'Nothing collected yet',
                        rows: [
                          for (final r in _collectors)
                            _Row(
                              label: _name(
                                r['collected_by_stall_id'] as String?,
                              ),
                              trailing: MoneyText(_num(r['amount'])),
                              caption: '${r['bill_count'] ?? 0} bills',
                            ),
                        ],
                      ),

                      // Only interesting in a food court; a single stall would
                      // just see the headline number repeated.
                      if (_stalls.length > 1)
                        _Section(
                          title: 'By stall',
                          empty: '',
                          rows: [
                            for (final r in _stalls)
                              _Row(
                                label: _name(r['stall_id'] as String?),
                                trailing: MoneyText(_num(r['revenue'])),
                                caption: '${r['order_count'] ?? 0} orders',
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row {
  const _Row({required this.label, required this.trailing, this.caption});

  final String label;
  final Widget trailing;
  final String? caption;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    required this.empty,
  });

  final String title;
  final List<_Row> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            RosSurfaceCard(child: Text(empty))
          else
            RosSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.label,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (r.caption != null)
                                  Text(
                                    r.caption!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          r.trailing,
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
