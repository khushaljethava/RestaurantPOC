import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import '../providers/connectivity.dart';
import '../providers/shift.dart';
import '../providers/stall.dart';
import '../services/errors.dart';
import '../widgets/ros_ui.dart';

class HeldScreen extends ConsumerStatefulWidget {
  const HeldScreen({super.key});

  @override
  ConsumerState<HeldScreen> createState() => _HeldScreenState();
}

class _HeldScreenState extends ConsumerState<HeldScreen> {
  List<Map<String, dynamic>> _orders = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await Supabase.instance.client
          .from('orders')
          .select(
            'id, token_no, table_label, hold_tag, created_at, recorded_by_user_id, '
            'order_item(name, qty, line_total)',
          )
          .eq('recorded_by_stall_id', stallId)
          .eq('status', 'held')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
      final shift = ref.read(openShiftProvider).asData?.value;
      if (shift != null && mounted) {
        final opened = shift.openedAt;
        final stale = _orders.where((o) {
          final t = DateTime.tryParse(o['created_at'] as String? ?? '');
          return t != null && t.isBefore(opened);
        }).length;
        if (stale > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$stale held order(s) older than this shift')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = mapError(e); _loading = false; });
    }
  }

  Future<void> _resume(String id) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot resume')),
      );
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'resume_held_order',
        params: {'p_order_id': id},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resumed → pending')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mapError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Held orders'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const RosLoading()
          : _error != null
              ? RosEmpty(message: _error!)
              : _orders.isEmpty
                  ? const RosEmpty(message: 'No held orders')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final o = _orders[i];
                        final items = (o['order_item'] as List?) ?? [];
                        final total = items.fold<double>(
                          0,
                          (s, e) => s + ((e['line_total'] as num?)?.toDouble() ?? 0),
                        );
                        final when = o['created_at'] as String? ?? '';
                        final who = (o['recorded_by_user_id'] as String?)?.substring(0, 8) ?? '—';
                        final tag = o['hold_tag'] as String?;
                        return RosSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Token #${o['token_no'] ?? '—'}'
                                '${o['table_label'] != null ? ' · ${o['table_label']}' : ''}'
                                '${tag != null && tag.isNotEmpty ? ' · $tag' : ''}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('By $who · $when'),
                              Text(Money.fromRupees(total).format()),
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: () => _resume(o['id'] as String),
                                child: const Text('Resume'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
