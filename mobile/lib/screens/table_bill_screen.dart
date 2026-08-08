import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/errors.dart';
import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../widgets/glass.dart';
import '../widgets/ros_ui.dart';

class TableBillScreen extends ConsumerStatefulWidget {
  const TableBillScreen({super.key, required this.tableLabel});

  final String tableLabel;

  @override
  ConsumerState<TableBillScreen> createState() => _TableBillScreenState();
}

class _TableBillScreenState extends ConsumerState<TableBillScreen> {
  List<Map<String, dynamic>> _orders = [];
  var _loading = true;
  String? _error;
  var _settling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('orders')
          .select(
            'id, token_no, status, bill_id, order_item(name, qty, line_total)',
          )
          .eq('table_label', widget.tableLabel)
          .isFilter('bill_id', null)
          .neq('status', 'held')
          .neq('status', 'cancelled')
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(rows as List);
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

  Future<void> _settle() async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offline — cannot settle')));
      return;
    }
    final recordedBy = ref.read(activeStallIdProvider);
    if (recordedBy == null || _orders.isEmpty) return;

    setState(() {
      _settling = true;
      _error = null;
    });
    try {
      final orderIds = _orders.map((o) => o['id'] as String).toList();
      final billId = await Supabase.instance.client.rpc(
        'open_bill',
        params: {
          'p_collected_by_stall_id': recordedBy,
          'p_order_ids': orderIds,
          'p_idempotency_key': const Uuid().v4(),
          'p_table_label': widget.tableLabel,
        },
      );
      if (!mounted) return;
      context.push('/checkout/$billId');
    } catch (e) {
      setState(() {
        _error = mapError(e);
        _settling = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _orders.fold<double>(0, (sum, o) {
      final items = o['order_item'] as List? ?? const [];
      return sum +
          items.fold<double>(
            0,
            (s, i) => s + ((i['line_total'] as num?)?.toDouble() ?? 0),
          );
    });

    return Scaffold(
      appBar: AppBar(title: Text('Table ${widget.tableLabel}')),
      body: _loading
          ? const RosLoading()
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: RosErrorText(_error!),
                  ),
                Expanded(
                  child: _orders.isEmpty
                      ? const RosEmpty(message: 'No unbilled orders')
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final o = _orders[i];
                            return RosSurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Token #${o['token_no'] ?? '—'} · ${o['status']}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ((o['order_item'] as List?) ?? const [])
                                        .map(
                                          (it) =>
                                              '${it['name']} × ${it['qty']}',
                                        )
                                        .join(', '),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                GlassBar(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Unbilled',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              MoneyText(total),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => context.push(
                              '/pos?table=${Uri.encodeComponent(widget.tableLabel)}',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Add items'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: (_orders.isEmpty || _settling)
                                ? null
                                : _settle,
                            child: Text(_settling ? 'Opening…' : 'Settle'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
