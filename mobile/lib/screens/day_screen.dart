import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import '../providers/stall.dart';
import '../services/errors.dart';

class DayScreen extends ConsumerStatefulWidget {
  const DayScreen({super.key});

  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen> {
  Map<String, dynamic>? _summary;
  var _loading = true;
  String? _error;
  DateTime _day = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => _day = d);
      await _load();
    }
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final day = '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';
      final data = await Supabase.instance.client.rpc(
        'day_summary',
        params: {'p_stall_id': stallId, 'p_day': day},
      );
      if (!mounted) return;
      setState(() {
        _summary = Map<String, dynamic>.from(data as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = mapError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final modes = Map<String, dynamic>.from((s?['payment_modes'] as Map?) ?? {});
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day summary'),
        actions: [
          IconButton(onPressed: _pickDay, icon: const Icon(Icons.calendar_today)),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    _tile('Sales', Money.fromRupees(s?['sales_total'] as num? ?? 0).format()),
                    _tile('Discounts', Money.fromRupees(s?['discounts_total'] as num? ?? 0).format()),
                    _tile('Refunds', Money.fromRupees(s?['refunds_total'] as num? ?? 0).format()),
                    _tile('Open bills', '${s?['open_bills'] ?? 0}'),
                    ListTile(
                      title: const Text('Unverified UPI'),
                      trailing: Text('${s?['unverified_upi'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => context.push('/upi-verify'),
                    ),
                    _tile('Ready not handed over', '${s?['unhanded_tokens'] ?? 0}'),
                    const SizedBox(height: 16),
                    Text('Payment modes', style: Theme.of(context).textTheme.titleMedium),
                    if (modes.isEmpty)
                      const ListTile(title: Text('No payments'))
                    else
                      ...modes.entries.map((e) => _tile(
                            e.key,
                            Money.fromRupees(e.value as num? ?? 0).format(),
                          )),
                    const SizedBox(height: 16),
                    Text('Shift variances', style: Theme.of(context).textTheme.titleMedium),
                    ...(((s?['shift_variances'] as List?) ?? []).map((v) {
                      final m = Map<String, dynamic>.from(v as Map);
                      return ListTile(
                        title: Text(Money.fromRupees(m['variance'] as num? ?? 0).format()),
                        subtitle: Text(m['reason'] as String? ?? 'No reason'),
                      );
                    })),
                  ],
                ),
    );
  }

  Widget _tile(String label, String value) => ListTile(
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
