import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/money.dart';
import '../providers/shift.dart';
import '../providers/stall.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  final _floatCtrl = TextEditingController(text: '500');
  final _reasonCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _floatCtrl.dispose();
    _reasonCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final stallId = ref.read(activeStallIdProvider);
    if (stallId == null) return;
    setState(() { _busy = true; _error = null; });
    final r = await ref.read(shiftRepositoryProvider).open(
          stallId: stallId,
          openingFloat: Money.parse(_floatCtrl.text),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.isOk) {
      ref.invalidate(openShiftProvider);
    } else {
      setState(() => _error = r.errorOrNull);
    }
  }

  Future<void> _move(String kind) async {
    final shift = ref.read(openShiftProvider).asData?.value;
    if (shift == null) return;
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Reason required');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final r = await ref.read(shiftRepositoryProvider).addMovement(
          shiftId: shift.id,
          kind: kind,
          amount: Money.parse(_amountCtrl.text),
          reason: reason,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.isOk) setState(() => _error = r.errorOrNull);
    else {
      _amountCtrl.clear();
      _reasonCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kind == 'paid_in' ? 'Paid in recorded' : 'Paid out recorded')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(openShiftProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Shift')),
      body: shiftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (shift) {
          if (shift == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Open shift to start selling',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _floatCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Opening float (₹)',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy ? null : _open,
                    child: const Text('Open shift'),
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Shift open', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                KeyValueRow(label: 'Float', value: shift.openingFloat.format()),
                KeyValueRow(
                  label: 'Opened',
                  value: TimeOfDay.fromDateTime(shift.openedAt.toLocal()).format(context),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                ),
                TextField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _move('paid_in'),
                        child: const Text('Paid in'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _move('paid_out'),
                        child: const Text('Paid out'),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => context.push('/shift/close'),
                  child: const Text('Close shift'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
