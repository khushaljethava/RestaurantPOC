import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/order_payment.dart';
import '../data/supabase/realtime_channels.dart';
import '../l10n/app_localizations.dart';
import '../providers/acting_user.dart';
import '../providers/connectivity.dart';
import '../providers/stall.dart';
import '../services/errors.dart';
import '../services/telemetry.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/ros_ui.dart';

class StallScreen extends ConsumerStatefulWidget {
  const StallScreen({super.key});

  @override
  ConsumerState<StallScreen> createState() => _StallScreenState();
}

class _StallScreenState extends ConsumerState<StallScreen> {
  List<Map<String, dynamic>> _orders = [];
  String? _error;
  Timer? _alarm;
  Timer? _tick;
  String _conn = 'Connecting…';
  DateTime _lastEvent = DateTime.now();
  final _busyOrderIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await SharedPreferences.getInstance();
      if (p.getBool('settings_keep_awake') ?? false) {
        await WakelockPlus.enable();
      }
      _load();
      _subscribe();
      _alarm = Timer.periodic(const Duration(seconds: 30), (_) {
        final unacked = _orders.any(
          (o) => o['status'] == 'pending' && o['acknowledged_at'] == null,
        );
        if (unacked) HapticFeedback.heavyImpact();
      });
      _tick = Timer.periodic(const Duration(seconds: 20), (_) => _heartbeat());
    });
  }

  Future<void> _load() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('orders')
          .select(
            'id, token_no, status, table_label, order_type, acknowledged_at, '
            'created_at, bill_id, '
            'bill:bill_id(id, status, total, discount, rounding_amount), '
            'order_item(name, qty, notes)',
          )
          .eq('stall_id', stallId)
          .inFilter('status', ['pending', 'ready'])
          .order('created_at');
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(rows as List);
          _error = null;
          _lastEvent = DateTime.now();
          _conn = 'Live';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = mapError(e));
    }
  }

  void _subscribe() {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    realtimeManager.watchStallOrders(
      stallId: stallId,
      onChange: () {
        _lastEvent = DateTime.now();
        if (mounted) {
          setState(() => _conn = 'Live');
          _load();
        }
      },
    );
  }

  String _age(dynamic createdAt) {
    if (createdAt == null) return '';
    final t = DateTime.tryParse(createdAt.toString());
    if (t == null) return '';
    final m = DateTime.now().difference(t.toLocal()).inMinutes;
    return '$m min';
  }

  Future<void> _acknowledge(String id) async {
    try {
      await Supabase.instance.client.rpc('acknowledge_order', params: {
        'p_order_id': id,
      });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = mapError(e));
    }
  }

  Future<void> _setStatus(String id, String status) async {
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offline — cannot update')));
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'set_order_status',
        params: {'p_order_id': id, 'p_status': status},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapError(e))));
      }
    }
  }

  Future<UpiConfig?> _stallUpi() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return null;
    try {
      final stall = await Supabase.instance.client
          .from('stall')
          .select('upi_vpa, upi_payee_name, name')
          .eq('id', stallId)
          .maybeSingle();
      final vpa = stall?['upi_vpa'] as String?;
      if (vpa == null || vpa.trim().isEmpty) return null;
      return UpiConfig(
        vpa: vpa,
        payeeName:
            (stall?['upi_payee_name'] as String?)?.trim().isNotEmpty == true
                ? stall!['upi_payee_name'] as String
                : (stall?['name'] as String? ?? 'Stall'),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchBill(String billId) async {
    final row = await Supabase.instance.client
        .from('bill')
        .select('id, status, total, discount, rounding_amount')
        .eq('id', billId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<void> _giveToCustomer(Map<String, dynamic> order) async {
    final orderId = order['id'] as String;
    if (_busyOrderIds.contains(orderId)) return;
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — cannot update')),
      );
      return;
    }

    setState(() => _busyOrderIds.add(orderId));
    try {
      if (orderNeedsPayment(order)) {
        var billId = order['bill_id'] as String?;
        var due = orderBillDue(order);

        if (billId == null) {
          final collector = ref.read(activeStallIdProvider);
          if (collector == null) {
            throw StateError('No active stall');
          }
          billId = await Supabase.instance.client.rpc(
            'open_bill',
            params: {
              'p_collected_by_stall_id': collector,
              'p_order_ids': [orderId],
              'p_idempotency_key': const Uuid().v4(),
              'p_table_label': order['table_label'],
            },
          ) as String;
          final bill = await _fetchBill(billId);
          if (bill == null) throw StateError('Bill not found');
          due = orderBillDue({'bill': bill});
        } else if (due <= 0) {
          final bill = await _fetchBill(billId);
          if (bill == null) throw StateError('Bill not found');
          if (bill['status'] == 'paid') {
            await Supabase.instance.client.rpc(
              'set_order_status',
              params: {'p_order_id': orderId, 'p_status': 'completed'},
            );
            await _load();
            return;
          }
          due = orderBillDue({'bill': bill});
        }

        if (!mounted) return;
        final upi = await _stallUpi();
        if (!mounted) return;
        final result = await showPaymentSheet(
          context,
          due: due,
          upi: upi,
          billNote: 'Bill ${billId.substring(0, 8)}',
        );
        if (result == null || !mounted) return;

        final acting = ref.read(actingUserProvider.notifier).actingStaffId;
        try {
          await Supabase.instance.client.rpc(
            'apply_bill_rounding',
            params: {'p_bill_id': billId},
          );
        } catch (_) {}
        await Supabase.instance.client.rpc(
          'pay_bill',
          params: {
            'p_bill_id': billId,
            'p_payments': result.payments,
            'p_acting_staff_id': acting,
          },
        );
      }

      await Supabase.instance.client.rpc(
        'set_order_status',
        params: {'p_order_id': orderId, 'p_status': 'completed'},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _busyOrderIds.remove(orderId));
      }
    }
  }

  Future<void> _heartbeat() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('stall_id', stallId)
          .eq('status', 'pending');
      final remote = (rows as List).length;
      final local = _orders.where((o) => o['status'] == 'pending').length;
      if (remote != local) {
        await _load();
      }
      final age = DateTime.now().difference(_lastEvent);
      if (mounted) {
        setState(() {
          _conn = age.inSeconds < 45
              ? 'Live'
              : age.inSeconds < 120
                  ? 'Reconnecting…'
                  : 'Stale — pull to refresh';
        });
        if (age.inSeconds >= 45) {
          Telemetry.event('realtime_drift', {'age_s': age.inSeconds});
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _alarm?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stallOrders),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Center(
              child: Text(
                _conn,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _error != null
          ? RosEmpty(message: _error!)
          : _orders.isEmpty
          ? const RosEmpty(message: 'No open orders')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final o = _orders[i];
                final status = o['status'] as String;
                final orderId = o['id'] as String;
                final busy = _busyOrderIds.contains(orderId);
                final items =
                    (o['order_item'] as List?)
                        ?.map((e) {
                          final n = e['notes'] as String?;
                          return '${e['name']} × ${e['qty']}'
                              '${n != null && n.isNotEmpty ? ' ($n)' : ''}';
                        })
                        .join('\n') ??
                    '';
                return RosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Token #${o['token_no'] ?? '—'}'
                              '${o['table_label'] != null ? ' · ${o['table_label']}' : ''}'
                              '${o['order_type'] != null ? ' · ${o['order_type']}' : ''}'
                              ' · ${_age(o['created_at'])}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          StatusChip(
                            label: status,
                            kind: status == 'ready'
                                ? StatusKind.ready
                                : StatusKind.pending,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(items),
                      const SizedBox(height: 12),
                      if (status == 'pending' && o['acknowledged_at'] == null)
                        FilledButton(
                          onPressed: () => _acknowledge(orderId),
                          child: Text(l10n.acknowledge),
                        ),
                      if (status == 'pending' && o['acknowledged_at'] != null)
                        FilledButton(
                          onPressed: () => _setStatus(orderId, 'ready'),
                          child: Text(l10n.ready),
                        ),
                      if (status == 'ready')
                        FilledButton(
                          onPressed: busy ? null : () => _giveToCustomer(o),
                          child: busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  orderNeedsPayment(o)
                                      ? 'Given to customer · Pay'
                                      : 'Given to customer',
                                ),
                        ),
                    ],
                  ),
                );              },
            ),
    );
  }
}
