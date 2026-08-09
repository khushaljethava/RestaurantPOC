import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import '../providers/acting_user.dart';
import '../services/errors.dart';
import '../widgets/pin_sheet.dart';
import '../widgets/reason_picker.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final order = await Supabase.instance.client
          .from('orders')
          .select(
            'id, status, token_no, stall_id, bill_id, order_type, notes, created_at, '
            'order_item(id, name, qty, unit_price, line_total, voided_at, notes)',
          )
          .eq('id', widget.orderId)
          .single();
      final items = List<Map<String, dynamic>>.from(
        (order['order_item'] as List?) ?? [],
      );
      if (!mounted) return;
      setState(() {
        _order = Map<String, dynamic>.from(order);
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
        _loading = false;
      });
    }
  }

  Future<bool> _managerOkIfReady() async {
    final status = _order?['status'] as String? ?? '';
    if (status != 'ready') return true;
    final stallId = _order?['stall_id'] as String?;
    if (stallId == null) return false;
    final uid = await showManagerPinSheet(
      context,
      stallId: stallId,
      title: 'Food already cooking — manager PIN',
    );
    return uid != null;
  }

  Future<void> _voidLine(String itemId) async {
    final reason = await showReasonPicker(
          context,
          title: 'Void reason',
          presets: kVoidReasons,
        ) ??
        await _askReason('Void reason');
    if (reason == null) return;
    final mgr = await _managerOkIfReady();
    if (!mgr) return;
    final acting = ref.read(actingUserProvider.notifier).actingStaffId;
    try {
      await Supabase.instance.client.rpc('void_order_item', params: {
        'p_order_item_id': itemId,
        'p_reason': reason,
        'p_acting_staff_id': acting,
        'p_manager_pin_ok': (_order?['status'] == 'ready'),
      });
      await _load();
    } catch (e) {
      setState(() => _error = mapError(e));
    }
  }

  Future<void> _amendQty(String itemId, num current) async {
    final ctrl = TextEditingController(text: current.toString());
    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit qty'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (qty == null || qty <= 0) return;
    final mgr = await _managerOkIfReady();
    if (!mgr) return;
    final acting = ref.read(actingUserProvider.notifier).actingStaffId;
    try {
      await Supabase.instance.client.rpc('amend_order_item_qty', params: {
        'p_order_item_id': itemId,
        'p_qty': qty,
        'p_acting_staff_id': acting,
        'p_manager_pin_ok': (_order?['status'] == 'ready'),
      });
      await _load();
    } catch (e) {
      setState(() => _error = mapError(e));
    }
  }

  Future<void> _cancel() async {
    final reason = await _askReason('Cancel reason');
    if (reason == null) return;
    try {
      await Supabase.instance.client.rpc('set_order_status', params: {
        'p_order_id': widget.orderId,
        'p_status': 'cancelled',
        'p_reason': reason,
      });
      await _load();
    } catch (e) {
      setState(() => _error = mapError(e));
    }
  }

  Future<String?> _askReason(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ).then((v) => (v == null || v.isEmpty) ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final o = _order;
    if (o == null) {
      return Scaffold(body: Center(child: Text(_error ?? 'Not found')));
    }
    final status = o['status'] as String? ?? '';
    final canEdit = status == 'pending' || status == 'held' || status == 'ready';

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${o['token_no'] ?? '—'}'),
        actions: [
          if (canEdit && status != 'cancelled')
            TextButton(onPressed: _cancel, child: const Text('Cancel')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('$status · ${o['order_type'] ?? 'dine_in'}',
              style: Theme.of(context).textTheme.titleMedium),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          for (final item in _items)
            ListTile(
              title: Text(item['name'] as String? ?? ''),
              subtitle: Text(
                item['voided_at'] != null
                    ? 'VOID'
                    : '${item['qty']} × ${Money.fromRupees(item['unit_price'] as num).format()}',
              ),
              trailing: item['voided_at'] != null
                  ? null
                  : canEdit
                      ? PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'qty') {
                              _amendQty(item['id'] as String, item['qty'] as num);
                            } else if (v == 'void') {
                              _voidLine(item['id'] as String);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'qty', child: Text('Edit qty')),
                            PopupMenuItem(value: 'void', child: Text('Void line')),
                          ],
                        )
                      : Text(Money.fromRupees(item['line_total'] as num? ?? 0).format()),
            ),
        ],
      ),
    );
  }
}
