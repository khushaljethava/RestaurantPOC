import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';
import '../providers/connectivity.dart';
import '../providers/stall.dart';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('orders')
          .select(
            'id, token_no, table_label, created_at, order_item(name, qty)',
          )
          .eq('recorded_by_stall_id', stallId)
          .eq('status', 'held')
          .order('created_at', ascending: false);
      setState(() {
        _orders = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = mapError(e);
        _loading = false;
      });
    }
  }

  Future<void> _resume(String id) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offline — cannot resume')));
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'resume_held_order',
        params: {'p_order_id': id},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Resumed → pending')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Held orders'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
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
                final items =
                    (o['order_item'] as List?)
                        ?.map((e) => '${e['name']} × ${e['qty']}')
                        .join(', ') ??
                    '';
                return RosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              o['table_label'] as String? ?? 'Counter',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const StatusChip(
                            label: 'Held',
                            kind: StatusKind.held,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        items,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
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
