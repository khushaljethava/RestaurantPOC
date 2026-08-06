import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../widgets/ros_ui.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  List<Map<String, dynamic>> _items = [];
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
    try {
      final rows = await Supabase.instance.client
          .from('menu_item')
          .select('id, name, is_available, price')
          .eq('stall_id', stallId)
          .order('name');
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String id, bool next) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot update stock')),
      );
      return;
    }
    try {
      await Supabase.instance.client
          .from('menu_item')
          .update({'is_available': next}).eq('id', id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item availability')),
      body: _loading
          ? const RosLoading()
          : _error != null
              ? RosEmpty(message: _error!)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final available = item['is_available'] as bool? ?? true;
                    return RosSurfaceCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: SwitchListTile(
                        title: Text(item['name'] as String),
                        subtitle: MoneyText((item['price'] as num)),
                        value: available,
                        onChanged: (v) => _toggle(item['id'] as String, v),
                      ),
                    );
                  },
                ),
    );
  }
}
