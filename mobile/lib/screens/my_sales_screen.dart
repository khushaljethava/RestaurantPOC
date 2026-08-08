import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import '../providers/shift.dart';
import '../providers/stall.dart';
import '../services/errors.dart';

class MySalesScreen extends ConsumerStatefulWidget {
  const MySalesScreen({super.key});

  @override
  ConsumerState<MySalesScreen> createState() => _MySalesScreenState();
}

class _MySalesScreenState extends ConsumerState<MySalesScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    final shift = ref.read(openShiftProvider).asData?.value;
    if (stallId == null) return;
    try {
      final data = await Supabase.instance.client.rpc(
        'my_sales_summary',
        params: {
          'p_stall_id': stallId,
          'p_shift_id': shift?.id,
        },
      );
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(data as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = mapError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My sales')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Orders', style: Theme.of(context).textTheme.titleMedium),
                    Text('${_data?['orders'] ?? 0}',
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 24),
                    Text('Collected', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      Money.fromRupees(_data?['collected'] as num? ?? 0).format(),
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ],
                ),
    );
  }
}
