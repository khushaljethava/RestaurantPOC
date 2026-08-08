import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';
import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../widgets/ros_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StallScreen extends ConsumerStatefulWidget {
  const StallScreen({super.key});

  @override
  ConsumerState<StallScreen> createState() => _StallScreenState();
}

class _StallScreenState extends ConsumerState<StallScreen> {
  List<Map<String, dynamic>> _orders = [];
  RealtimeChannel? _channel;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await SharedPreferences.getInstance();
      if (p.getBool('settings_keep_awake') ?? false) {
        await WakelockPlus.enable();
      }
      _load();
      _subscribe();
    });
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('orders')
          .select(
            'id, token_no, status, table_label, order_type, acknowledged_at, created_at, order_item(name, qty, notes)',
          )
          .eq('stall_id', stallId)
          .inFilter('status', ['pending', 'ready'])
          .order('created_at');
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(rows as List);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = mapError(e));
    }
  }

  void _subscribe() {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    _channel = Supabase.instance.client
        .channel('stall-orders-$stallId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stall_id',
            value: stallId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> _acknowledge(String id) async {
    try {
      await Supabase.instance.client.rpc('acknowledge_order', params: {
        'p_order_id': id,
      });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = mapError(e));
    }
  }

  Future<void> _setStatus(String id, String status) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offline — cannot update')));
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'set_order_status',
        params: {'p_order_id': id, 'p_status': status},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapError(e))));
      }
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stall orders'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _error != null
          ? RosEmpty(message: _error!)
          : _orders.isEmpty
          ? const RosEmpty(message: 'No open orders')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final o = _orders[i];
                final status = o['status'] as String;
                final items =
                    (o['order_item'] as List?)
                        ?.map((e) {
                          final n = e['notes'] as String?;
                          return '${e['name']} × ${e['qty']}'
                              '${n != null && n.isNotEmpty ? ' ($n)' : ''}';
                        })
                        .join('\n') ??
                    '';
                return RosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Token #${o['token_no'] ?? '—'}'
                              '${o['table_label'] != null ? ' · ${o['table_label']}' : ''}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          StatusChip(
                            label: status,
                            kind: status == 'ready'
                                ? StatusKind.ready
                                : StatusKind.pending,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(items),
                      const SizedBox(height: 12),
                      if (status == 'pending' && o['acknowledged_at'] == null)
                        FilledButton(
                          onPressed: () => _acknowledge(o['id'] as String),
                          child: const Text('Acknowledge'),
                        ),
                      if (status == 'pending' && o['acknowledged_at'] != null)
                        FilledButton(
                          onPressed: () =>
                              _setStatus(o['id'] as String, 'ready'),
                          child: const Text('Ready'),
                        ),
                      if (status == 'ready')
                        FilledButton(
                          onPressed: () =>
                              _setStatus(o['id'] as String, 'completed'),
                          child: const Text('Complete'),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
