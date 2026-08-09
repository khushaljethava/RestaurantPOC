import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/errors.dart';
import '../providers/cart.dart';
import '../providers/connectivity.dart';
import '../providers/acting_user.dart';
import '../providers/shift.dart';
import '../providers/stall.dart';
import '../widgets/pin_sheet.dart';
import '../widgets/reason_picker.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/ros_ui.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.billId});

  final String billId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Map<String, dynamic>? _bill;
  List<Map<String, dynamic>> _orders = [];
  var _loading = true;
  String? _error;
  var _paying = false;
  final _discountCtrl = TextEditingController();
  final _discountReason = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _discountReason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bill = await Supabase.instance.client
          .from('bill')
          .select('id, total, discount, status, table_label, rounding_amount, packaging_amount, token_no')
          .eq('id', widget.billId)
          .single();
      final orders = await Supabase.instance.client
          .from('orders')
          .select(
            'id, token_no, status, stall_id, order_item(name, qty, line_total)',
          )
          .eq('bill_id', widget.billId);
      if (!mounted) return;
      setState(() {
        _bill = Map<String, dynamic>.from(bill);
        _orders = List<Map<String, dynamic>>.from(orders as List);
        _loading = false;
        _discountCtrl.text = ((bill['discount'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(2);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
        _loading = false;
      });
    }
  }

  Future<void> _applyDiscount() async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot discount')),
      );
      return;
    }
    var reason = _discountReason.text.trim();
    if (reason.isEmpty) {
      reason = await showReasonPicker(
            context,
            title: 'Discount reason',
            presets: kDiscountReasons,
          ) ??
          '';
      if (reason.isEmpty) {
        setState(() => _error = 'Discount reason required');
        return;
      }
      _discountReason.text = reason;
    }
    final d = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final acting = ref.read(actingUserProvider.notifier).actingStaffId;
    Future<void> call({String? approver}) async {
      await Supabase.instance.client.rpc(
        'set_bill_discount',
        params: {
          'p_bill_id': widget.billId,
          'p_discount': d,
          'p_reason': reason,
          'p_approver_id': approver,
          'p_acting_staff_id': acting,
        },
      );
    }

    try {
      await call();
      await _load();
    } catch (e) {
      final msg = mapError(e);
      if (msg.toLowerCase().contains('approval') ||
          msg.toLowerCase().contains('cap')) {
        final stallId = ref.read(activeStallIdProvider);
        if (stallId == null || !mounted) {
          setState(() => _error = msg);
          return;
        }
        final approver = await showManagerPinSheet(
          context,
          stallId: stallId,
          title: 'Discount needs approval',
        );
        if (approver == null) {
          setState(() => _error = msg);
          return;
        }
        try {
          await call(approver: approver);
          await _load();
        } catch (e2) {
          setState(() => _error = mapError(e2));
        }
      } else {
        setState(() => _error = msg);
      }
    }
  }

  Future<void> _pay() async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot take payment')),
      );
      return;
    }
    final bill = _bill;
    if (bill == null || bill['status'] == 'paid') return;
    final total = (bill['total'] as num).toDouble();
    final discount = (bill['discount'] as num?)?.toDouble() ?? 0;
    final rounding = (bill['rounding_amount'] as num?)?.toDouble() ?? 0;
    final due = billDue(total, discount) + rounding;

    UpiConfig? upi;
    final stallId = ref.read(activeStallIdProvider);
    if (stallId != null) {
      try {
        final stall = await Supabase.instance.client
            .from('stall')
            .select('upi_vpa, upi_payee_name, name')
            .eq('id', stallId)
            .maybeSingle();
        final vpa = stall?['upi_vpa'] as String?;
        if (vpa != null && vpa.trim().isNotEmpty) {
          upi = UpiConfig(
            vpa: vpa,
            payeeName:
                (stall?['upi_payee_name'] as String?)?.trim().isNotEmpty == true
                ? stall!['upi_payee_name'] as String
                : (stall?['name'] as String? ?? 'Stall'),
          );
        }
      } catch (_) {}
    }

    if (!mounted) return;
    final result = await showPaymentSheet(
      context,
      due: due,
      upi: upi,
      billNote: 'Bill ${widget.billId.substring(0, 8)}',
    );
    if (result == null || !mounted) return;

    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final shift = ref.read(openShiftProvider).asData?.value;
      final acting = ref.read(actingUserProvider.notifier).actingStaffId;
      // Apply rounding before pay when stall rule exists.
      try {
        await Supabase.instance.client.rpc(
          'apply_bill_rounding',
          params: {'p_bill_id': widget.billId},
        );
      } catch (_) {}
      await Supabase.instance.client.rpc(
        'pay_bill',
        params: {
          'p_bill_id': widget.billId,
          'p_payments': result.payments,
          'p_shift_id': shift?.id,
          'p_acting_staff_id': acting,
        },
      );
      if (!mounted) return;
      context.go('/receipt/${widget.billId}');
    } catch (e) {
      setState(() {
        _error = mapError(e);
        _paying = false;
      });
    }
  }

  StatusKind _kind(String status) {
    return switch (status) {
      'paid' || 'completed' => StatusKind.paid,
      'ready' => StatusKind.ready,
      'cancelled' => StatusKind.cancelled,
      _ => StatusKind.pending,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bill = _bill;
    final total = (bill?['total'] as num?)?.toDouble() ?? 0;
    final discount = (bill?['discount'] as num?)?.toDouble() ?? 0;
    final rounding = (bill?['rounding_amount'] as num?)?.toDouble() ?? 0;
    final due = billDue(total, discount) + rounding;
    final status = bill?['status'] as String? ?? '—';

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _loading
          ? const RosLoading()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null) ...[
                        RosErrorText(_error!),
                        const SizedBox(height: 12),
                      ],
                      if (bill?['table_label'] != null)
                        Text(
                          'Table ${bill!['table_label']}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      const SizedBox(height: 8),
                      StatusChip(label: status, kind: _kind(status)),
                      const SizedBox(height: 16),
                      for (final o in _orders) ...[
                        RosSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Token #${o['token_no'] ?? '—'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const Spacer(),
                                  StatusChip(
                                    label: '${o['status']}',
                                    kind: _kind('${o['status']}'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (final item
                                  in (o['order_item'] as List? ?? const []))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item['name']} × ${item['qty']}',
                                        ),
                                      ),
                                      MoneyText(
                                        (item['line_total'] as num?) ?? 0,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (status == 'open') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _discountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Discount amount',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _discountReason,
                          decoration: const InputDecoration(
                            labelText: 'Discount reason',
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _applyDiscount,
                            child: const Text('Apply discount'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GlassBar(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Due',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              MoneyText(
                                due,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          Text(
                            'Total ${formatInr(total)} · Discount ${formatInr(discount)}',
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          if (status == 'open')
                            FilledButton(
                              onPressed: _paying ? null : _pay,
                              child: Text(
                                _paying ? 'Paying…' : 'Collect payment',
                              ),
                            )
                          else if (status == 'paid')
                            FilledButton(
                              onPressed: () =>
                                  context.go('/receipt/${widget.billId}'),
                              child: const Text('View receipt'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
