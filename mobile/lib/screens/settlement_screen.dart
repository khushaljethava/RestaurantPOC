import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';
import '../widgets/ros_ui.dart';

class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  List<Map<String, dynamic>> _pairs = [];
  Map<String, String> _names = {};
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).toUtc();
    final to = from.add(const Duration(days: 1));
    try {
      final pairs = await Supabase.instance.client.rpc(
        'settlement_pairs',
        params: {
          'p_from': from.toIso8601String(),
          'p_to': to.toIso8601String(),
        },
      );
      final stalls = await Supabase.instance.client
          .from('stall')
          .select('id, name');
      final names = <String, String>{
        for (final s in stalls as List) s['id'] as String: s['name'] as String,
      };
      if (!mounted) return;
      setState(() {
        _pairs = List<Map<String, dynamic>>.from(pairs as List);
        _names = names;
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

  String _name(String id) => _names[id] ?? id.substring(0, 8);

  @override
  Widget build(BuildContext context) {
    final net = _pairs.fold<double>(0, (s, p) {
      return s + ((p['a_owes_b'] as num).toDouble().abs());
    });

    return Scaffold(
      appBar: AppBar(title: const Text("Today's settlement")),
      body: _loading
          ? const RosLoading()
          : _error != null
          ? RosEmpty(message: _error!)
          : _pairs.isEmpty
          ? const RosEmpty(message: 'No cross-stall balances today')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net settlement',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      MoneyText(
                        net,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final p in _pairs) ...[
                  Builder(
                    builder: (context) {
                      final a = p['stall_a'] as String;
                      final b = p['stall_b'] as String;
                      final amt = (p['a_owes_b'] as num).toDouble();
                      final payer = amt > 0 ? a : b;
                      final payee = amt > 0 ? b : a;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RosSurfaceCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_name(payer)} → ${_name(payee)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              MoneyText(amt.abs()),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}
