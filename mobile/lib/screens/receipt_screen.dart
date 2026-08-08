import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';
import '../providers/connectivity.dart';
import '../services/receipt_pdf.dart';
import '../theme/ros_theme.dart';
import '../widgets/ros_ui.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.billId});

  final String billId;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  Map<String, dynamic>? _bill;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _payments = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final bill = await Supabase.instance.client
          .from('bill')
          .select('id, total, discount, status, table_label')
          .eq('id', widget.billId)
          .single();
      final orders = await Supabase.instance.client
          .from('orders')
          .select('id, token_no, status, order_item(name, qty, line_total)')
          .eq('bill_id', widget.billId);
      final payments = await Supabase.instance.client
          .from('payment')
          .select('method, amount')
          .eq('bill_id', widget.billId);
      if (!mounted) return;
      setState(() {
        _bill = Map<String, dynamic>.from(bill);
        _orders = List<Map<String, dynamic>>.from(orders as List);
        _payments = List<Map<String, dynamic>>.from(payments as List);
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

  Future<void> _share() async {
    final bill = _bill;
    if (bill == null) return;
    try {
      final file = await buildReceiptPdf(
        billId: widget.billId,
        total: (bill['total'] as num).toDouble(),
        orders: _orders,
        payments: _payments,
      );
      await shareReceiptPdf(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapError(e))));
    }
  }

  Future<void> _preview() async {
    final bill = _bill;
    if (bill == null) return;
    final file = await buildReceiptPdf(
      billId: widget.billId,
      total: (bill['total'] as num).toDouble(),
      orders: _orders,
      payments: _payments,
    );
    if (!mounted) return;
    await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
  }

  Future<void> _refund() async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offline — cannot refund')));
      return;
    }
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund bill'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refund'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reason required')));
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'refund_bill',
        params: {'p_bill_id': widget.billId, 'p_reason': reason},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = _bill;
    final total = (bill?['total'] as num?)?.toDouble() ?? 0;
    final status = bill?['status'] as String? ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _loading
          ? const RosLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  RosErrorText(_error!),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: RosColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RosColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ROS',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: RosColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatusChip(
                            label: status,
                            kind: status == 'paid'
                                ? StatusKind.paid
                                : status == 'refunded'
                                ? StatusKind.cancelled
                                : StatusKind.pending,
                          ),
                          const Spacer(),
                          MoneyText(
                            total,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (bill?['table_label'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Table ${bill!['table_label']}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const Divider(height: 24),
                      for (final o in _orders) ...[
                        Text(
                          'Token #${o['token_no'] ?? '—'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final item
                            in (o['order_item'] as List? ?? const []))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['name']} × ${item['qty']}',
                                  ),
                                ),
                                MoneyText((item['line_total'] as num?) ?? 0),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                      const Divider(),
                      for (final p in _payments)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(child: Text('${p['method']}')),
                              MoneyText((p['amount'] as num?) ?? 0),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share),
                  label: const Text('Share PDF'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _preview,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Preview PDF'),
                ),
                if (status == 'paid') ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _refund,
                    child: const Text(
                      'Refund',
                      style: TextStyle(color: RosColors.error),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
