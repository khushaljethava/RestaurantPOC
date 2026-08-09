import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import '../providers/stall.dart';
import '../services/errors.dart';
import '../widgets/ros_ui.dart';

class UpiVerifyScreen extends ConsumerStatefulWidget {
  const UpiVerifyScreen({super.key});

  @override
  ConsumerState<UpiVerifyScreen> createState() => _UpiVerifyScreenState();
}

class _UpiVerifyScreenState extends ConsumerState<UpiVerifyScreen> {
  List<Map<String, dynamic>> _rows = [];
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
      final rows = await Supabase.instance.client
          .from('payment')
          .select('id, amount, upi_ref, screenshot_path, bill:bill!inner(id, token_no, collected_by_stall_id, paid_at)')
          .eq('method', 'upi')
          .eq('upi_verified', false)
          .eq('bill.collected_by_stall_id', stallId)
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = mapError(e); _loading = false; });
    }
  }

  Future<void> _uploadScreenshot(String paymentId) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final path = 'upi/$paymentId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      try {
        await Supabase.instance.client.storage
            .from('payment-screenshots')
            .uploadBinary(path, bytes);
      } catch (_) {
        // Bucket optional — still record path for ops follow-up.
      }
      await Supabase.instance.client
          .from('payment')
          .update({'screenshot_path': path})
          .eq('id', paymentId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mapError(e))));
      }
    }
  }

  Future<void> _verify(String paymentId) async {
    try {
      await Supabase.instance.client.rpc(
        'verify_upi_payment',
        params: {'p_payment_id': paymentId},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mapError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify UPI'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const RosLoading()
          : _error != null
              ? RosEmpty(message: _error!)
              : _rows.isEmpty
                  ? const RosEmpty(message: 'No unverified UPI payments')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = _rows[i];
                        final bill = Map<String, dynamic>.from(p['bill'] as Map);
                        return RosSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Token #${bill['token_no'] ?? '—'} · ${Money.fromRupees(p['amount'] as num).format()}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (p['upi_ref'] != null) Text('UTR ${p['upi_ref']}'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _uploadScreenshot(p['id'] as String),
                                    child: Text(p['screenshot_path'] == null ? 'Screenshot' : 'Replace shot'),
                                  ),
                                  const Spacer(),
                                  FilledButton(
                                    onPressed: () => _verify(p['id'] as String),
                                    child: const Text('Mark verified'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
