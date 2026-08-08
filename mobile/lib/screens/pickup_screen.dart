import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/stall.dart';
import '../services/errors.dart';

class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({super.key});

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  List<Map<String, dynamic>> _bills = [];
  var _loading = true;
  String? _error;
  RealtimeChannel? _channel;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _subscribe();
      _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    final ch = _channel;
    if (ch != null) {
      Supabase.instance.client.removeChannel(ch);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('bill')
          .select(
            'id, token_no, pickup_status, status, paid_at, updated_at, '
            'orders(id, stall_id, status, stall:stall_id(name))',
          )
          .eq('collected_by_stall_id', stallId)
          .inFilter('pickup_status', ['preparing', 'ready'])
          .inFilter('status', ['open', 'paid'])
          .order('updated_at', ascending: false)
          .limit(80);
      if (!mounted) return;
      setState(() {
        _bills = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
        _loading = false;
      });
    }
  }

  void _subscribe() {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    _channel = Supabase.instance.client
        .channel('pickup:$stallId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bill',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> _handOver(String billId) async {
    try {
      await Supabase.instance.client.rpc('mark_bill_handed_over', params: {
        'p_bill_id': billId,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapError(e))),
      );
    }
  }

  List<Map<String, dynamic>> _seg(String status) =>
      _bills.where((b) => b['pickup_status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(tabs: [
                        Tab(text: 'Preparing'),
                        Tab(text: 'Ready'),
                      ]),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _grid(_seg('preparing'), ready: false),
                            _grid(_seg('ready'), ready: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _grid(List<Map<String, dynamic>> bills, {required bool ready}) {
    if (bills.isEmpty) {
      return const Center(child: Text('None'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: bills.length,
      itemBuilder: (context, i) {
        final b = bills[i];
        final token = b['token_no'];
        final orders = List<Map<String, dynamic>>.from((b['orders'] as List?) ?? []);
        final progress = orders.map((o) {
          final name = (o['stall'] as Map?)?['name'] ?? '?';
          final st = o['status'];
          final done = st == 'ready' || st == 'completed';
          return '$name ${done ? '✓' : '…'}';
        }).join(' · ');
        return Material(
          color: ready ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: ready ? () => _handOver(b['id'] as String) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('#$token',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(progress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall),
                  if (ready)
                    Text('Hand over',
                        style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
