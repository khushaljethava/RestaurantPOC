import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      final data = await Supabase.instance.client.rpc(
        'day_summary',
        params: {'p_stall_id': stallId},
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day summary'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _tile('Sales', Money.fromRupees(s?['sales_total'] as num? ?? 0).format()),
                    _tile('Open bills', '${s?['open_bills'] ?? 0}'),
                    _tile('Unverified UPI', '${s?['unverified_upi'] ?? 0}'),
                    _tile('Ready not handed over', '${s?['unhanded_tokens'] ?? 0}'),
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
