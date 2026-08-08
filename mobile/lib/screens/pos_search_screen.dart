import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import '../providers/cart.dart';
import '../services/errors.dart';

class PosSearchScreen extends ConsumerStatefulWidget {
  const PosSearchScreen({super.key});

  @override
  ConsumerState<PosSearchScreen> createState() => _PosSearchScreenState();
}

class _PosSearchScreenState extends ConsumerState<PosSearchScreen> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> _hits = [];
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _search(v));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _hits = []);
      return;
    }
    try {
      final rows = await Supabase.instance.client.rpc(
        'search_menu_items',
        params: {'p_query': q.trim()},
      );
      if (!mounted) return;
      setState(() {
        _hits = List<Map<String, dynamic>>.from(rows as List);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mapError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search menu…',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: (v) {
            if (_hits.isNotEmpty) _add(_hits.first);
          },
        ),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : ListView.builder(
              itemCount: _hits.length,
              itemBuilder: (context, i) {
                final m = _hits[i];
                final available = m['is_available'] as bool? ?? true;
                return ListTile(
                  enabled: available,
                  title: Text(m['name'] as String? ?? ''),
                  subtitle: Text(
                    '${m['stall_name'] ?? ''}'
                    '${m['quick_code'] != null ? ' · #${m['quick_code']}' : ''}'
                    '${available ? '' : ' · Unavailable'}',
                  ),
                  trailing: Text(Money.fromRupees(m['price'] as num? ?? 0).format()),
                  onTap: available ? () => _add(m) : null,
                );
              },
            ),
    );
  }

  void _add(Map<String, dynamic> m) {
    ref.read(cartProvider.notifier).add(
          CartLine(
            stallId: m['stall_id'] as String,
            menuItemId: m['id'] as String,
            name: m['name'] as String,
            unitPrice: Money.fromRupees(m['price'] as num),
            qty: 1,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${m['name']}')),
    );
  }
}
