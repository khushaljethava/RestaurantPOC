import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/bill.dart';
import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../widgets/ros_ui.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  List<Map<String, dynamic>> _orders = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    final start = DateTime.now().toUtc().subtract(const Duration(hours: 18));
    final rows = await Supabase.instance.client
        .from('orders')
        .select('id, token_no, status, table_label, created_at')
        .eq('stall_id', stallId)
        .gte('created_at', start.toIso8601String())
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        _orders = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    }
  }

  Future<void> _cancel(String orderId) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot cancel')),
      );
      return;
    }
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel order')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reason required')),
      );
      return;
    }
    try {
      await Supabase.instance.client.rpc('set_order_status', params: {
        'p_order_id': orderId,
        'p_status': 'cancelled',
        'p_reason': reason,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  StatusKind _kind(String status) {
    return switch (status) {
      'paid' || 'completed' => StatusKind.paid,
      'ready' => StatusKind.ready,
      'cancelled' => StatusKind.cancelled,
      'held' => StatusKind.held,
      _ => StatusKind.pending,
    };
  }

  @override
  Widget build(BuildContext context) {
    final openBills = ref.watch(openBillsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Today's orders")),
      body: _loading
          ? const RosLoading()
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(openBillsProvider);
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  openBills.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => RosErrorText('Open bills: $e'),
                    data: (bills) {
                      if (bills.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Open bills',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          for (final b in bills) ...[
                            RosSurfaceCard(
                              onTap: () =>
                                  context.push('/checkout/${b['id']}'),
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        MoneyText((b['total'] as num)),
                                        Text(
                                          b['table_label'] as String? ??
                                              'Counter',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                  Text('Orders',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_orders.isEmpty)
                    const RosEmpty(message: 'No orders yet today')
                  else
                    for (final o in _orders) ...[
                      RosSurfaceCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Token #${o['token_no'] ?? '—'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    o['table_label'] as String? ?? 'Counter',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(
                              label: '${o['status']}',
                              kind: _kind('${o['status']}'),
                            ),
                            if (['pending', 'ready', 'held']
                                .contains(o['status']))
                              TextButton(
                                onPressed: () =>
                                    _cancel(o['id'] as String),
                                child: const Text('Cancel'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
    );
  }
}
