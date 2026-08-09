import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../providers/acting_user.dart';
import '../providers/shift.dart';
import '../providers/stall.dart';
import '../widgets/pin_sheet.dart';
import '../widgets/reason_picker.dart';

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
          .select('id, total, discount, status, table_label, token_no')
          .eq('id', widget.billId)
          .single();
      final orders = await Supabase.instance.client
          .from('orders')
          .select('id, token_no, status, order_item(id, name, qty, unit_price, line_total, voided_at)')
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

  String? _shareToken;

  Future<void> _customerQr() async {
    try {
      final token = await Supabase.instance.client.rpc(
        'create_receipt_share_token',
        params: {'p_bill_id': widget.billId},
      );
      if (!mounted) return;
      setState(() => _shareToken = token as String);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapError(e))),
      );
    }
  }

  Future<void> _whatsapp() async {
    await _customerQr();
    final token = _shareToken;
    if (token == null) return;
    final base = receiptSiteUrl.replaceAll(RegExp(r'/$'), '');
    final url = '$base/r/$token';
    final share = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent('Your receipt: $url')}',
    );
    if (await canLaunchUrl(share)) {
      await launchUrl(share, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url)),
      );
    }
  }


  Future<void> _smsOrEmail(String channel) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$channel not configured')),
    );
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

  Future<String?> _approverIfNeeded() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return null;
    return showManagerPinSheet(
      context,
      stallId: stallId,
      title: 'Refund needs manager PIN',
    );
  }

  Future<void> _refund({bool partial = false}) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot refund')),
      );
      return;
    }
    final reason = await showReasonPicker(
          context,
          title: partial ? 'Partial refund reason' : 'Refund reason',
          presets: kRefundReasons,
        );
    if (reason == null || reason.isEmpty) return;

    final acting = ref.read(actingUserProvider.notifier).actingStaffId;
    final shift = ref.read(openShiftProvider).asData?.value;
    String? approver = await _approverIfNeeded();

    try {
      if (partial) {
        final lines = <Map<String, dynamic>>[];
        for (final o in _orders) {
          for (final it in (o['order_item'] as List? ?? [])) {
            final m = Map<String, dynamic>.from(it as Map);
            if (m['voided_at'] != null) continue;
            lines.add({
              'order_item_id': m['id'],
              'qty': m['qty'],
              'name': m['name'],
            });
          }
        }
        if (lines.isEmpty) return;
        final chosen = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Refund which line?'),
            children: [
              for (final l in lines)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, l),
                  child: Text('${l['name']} × ${l['qty']}'),
                ),
            ],
          ),
        );
        if (chosen == null) return;
        await Supabase.instance.client.rpc('partial_refund_bill', params: {
          'p_bill_id': widget.billId,
          'p_lines': [
            {
              'order_item_id': chosen['order_item_id'],
              'qty': chosen['qty'],
            }
          ],
          'p_reason': reason,
          'p_method': 'cash',
          'p_approver_id': approver,
          'p_acting_staff_id': acting,
          'p_shift_id': shift?.id,
        });
      } else {
        await Supabase.instance.client.rpc('refund_bill', params: {
          'p_bill_id': widget.billId,
          'p_reason': reason,
          'p_acting_staff_id': acting,
          'p_approver_id': approver,
        });
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapError(e))),
      );
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
                  onPressed: _whatsapp,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp link'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _customerQr,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Customer QR'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _smsOrEmail('SMS'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('SMS'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _smsOrEmail('Email'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Email'),
                ),
                if (_shareToken != null) ...[
                  const SizedBox(height: 12),
                  Text('Token: $_shareToken',
                      textAlign: TextAlign.center),
                ],
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
