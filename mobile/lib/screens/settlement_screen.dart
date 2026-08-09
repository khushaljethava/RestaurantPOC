import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/stall.dart';
import '../services/errors.dart';
import '../widgets/ros_ui.dart';

class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  List<Map<String, dynamic>> _pairs = [];
  List<Map<String, dynamic>> _records = [];
  Map<String, String> _names = {};
  var _loading = true;
  String? _error;
  DateTime _day = DateTime.now();

  String get _dayStr =>
      '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

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
    final from = DateTime(_day.year, _day.month, _day.day).toUtc();
    final to = from.add(const Duration(days: 1));
    final stallId = ref.read(activeStallIdProvider);
    try {
      final pairs = await Supabase.instance.client.rpc(
        'settlement_pairs',
        params: {
          'p_from': from.toIso8601String(),
          'p_to': to.toIso8601String(),
        },
      );
      final stalls = await Supabase.instance.client.from('stall').select('id, name');
      final names = <String, String>{
        for (final s in stalls as List) s['id'] as String: s['name'] as String,
      };
      var records = <Map<String, dynamic>>[];
      if (stallId != null) {
        final rows = await Supabase.instance.client
            .from('settlement_record')
            .select('id, from_stall_id, to_stall_id, amount, method, confirmed_at, marked_at')
            .eq('day', _dayStr)
            .or('from_stall_id.eq.$stallId,to_stall_id.eq.$stallId');
        records = List<Map<String, dynamic>>.from(rows as List);
      }
      if (!mounted) return;
      setState(() {
        _pairs = List<Map<String, dynamic>>.from(pairs as List);
        _records = records;
        _names = names;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e);
        _loading = false;
      });
    }
  }

  String _name(String id) => _names[id] ?? id.substring(0, 8);

  Future<void> _sharePdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Settlement $_dayStr', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            for (final p in _pairs)
              pw.Text(
                '${_name(p['stall_a'] as String)} ↔ ${_name(p['stall_b'] as String)}: ₹${(p['a_owes_b'] as num).abs()}',
              ),
            pw.SizedBox(height: 12),
            for (final r in _records)
              pw.Text(
                '${_name(r['from_stall_id'] as String)} → ${_name(r['to_stall_id'] as String)} '
                '₹${r['amount']} ${r['confirmed_at'] == null ? '(pending)' : '(confirmed)'}',
              ),
          ],
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/settlement_$_dayStr.pdf');
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Settlement $_dayStr'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final net = _pairs.fold<double>(0, (s, p) {
      return s + ((p['a_owes_b'] as num).toDouble().abs());
    });
    final pending = _records.where((r) => r['confirmed_at'] == null).toList();
    final myStall = ref.watch(activeStallIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement'),
        actions: [
          IconButton(onPressed: _pickDay, icon: const Icon(Icons.calendar_today)),
          IconButton(onPressed: _sharePdf, icon: const Icon(Icons.picture_as_pdf)),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const RosLoading()
          : _error != null
              ? RosEmpty(message: _error!)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(_dayStr, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    RosSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net settlement', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          MoneyText(
                            net,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    if (pending.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Pending confirmation', style: Theme.of(context).textTheme.titleMedium),
                      for (final r in pending)
                        ListTile(
                          title: Text('${_name(r['from_stall_id'] as String)} → ${_name(r['to_stall_id'] as String)}'),
                          subtitle: Text('₹${r['amount']} · ${r['method']}'),
                          trailing: myStall == r['to_stall_id']
                              ? FilledButton(
                                  onPressed: () async {
                                    try {
                                      await Supabase.instance.client.rpc(
                                        'confirm_settlement',
                                        params: {'p_id': r['id']},
                                      );
                                      await _load();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(mapError(e))),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Confirm'),
                                )
                              : const Text('Awaiting'),
                        ),
                    ],
                    const SizedBox(height: 16),
                    if (_pairs.isEmpty)
                      const RosEmpty(message: 'No cross-stall balances')
                    else
                      for (final p in _pairs)
                        Builder(builder: (context) {
                          final a = p['stall_a'] as String;
                          final b = p['stall_b'] as String;
                          final amt = (p['a_owes_b'] as num).toDouble();
                          final payer = amt > 0 ? a : b;
                          final payee = amt > 0 ? b : a;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: RosSurfaceCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_name(payer)} → ${_name(payee)}',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      MoneyText(amt.abs()),
                                      TextButton(
                                        onPressed: () async {
                                          try {
                                            await Supabase.instance.client.rpc(
                                              'mark_settlement',
                                              params: {
                                                'p_from_stall': payer,
                                                'p_to_stall': payee,
                                                'p_day': _dayStr,
                                                'p_amount': amt.abs(),
                                                'p_method': 'cash',
                                              },
                                            );
                                            await _load();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Marked — awaiting confirm')),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(mapError(e))),
                                              );
                                            }
                                          }
                                        },
                                        child: const Text('Mark settled'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                  ],
                ),
    );
  }
}
