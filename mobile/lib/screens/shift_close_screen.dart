import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/money.dart';
import '../providers/shift.dart';

class ShiftCloseScreen extends ConsumerStatefulWidget {
  const ShiftCloseScreen({super.key});

  @override
  ConsumerState<ShiftCloseScreen> createState() => _ShiftCloseScreenState();
}

class _ShiftCloseScreenState extends ConsumerState<ShiftCloseScreen> {
  final _declared = TextEditingController();
  final _reason = TextEditingController();
  Money? _expected;
  var _busy = false;
  String? _error;
  var _step = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExpected());
  }

  @override
  void dispose() {
    _declared.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadExpected() async {
    final shift = ref.read(openShiftProvider).asData?.value;
    if (shift == null) return;
    final r = await ref.read(shiftRepositoryProvider).expectedCash(shift.id);
    if (!mounted) return;
    if (r.isOk) setState(() => _expected = r.valueOrNull);
    else setState(() => _error = r.errorOrNull);
  }

  Future<void> _confirm() async {
    final shift = ref.read(openShiftProvider).asData?.value;
    if (shift == null) return;
    final declared = Money.parse(_declared.text);
    final expected = _expected ?? Money(0);
    final variance = declared - expected;
    if (variance.paise.abs() > 5000 && _reason.text.trim().isEmpty) {
      setState(() => _error = 'Variance reason required (threshold ₹50)');
      return;
    }
    setState(() { _busy = true; _error = null; });
    final r = await ref.read(shiftRepositoryProvider).close(
          shiftId: shift.id,
          declaredCash: declared,
          varianceReason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.isOk) {
      ref.invalidate(openShiftProvider);
      context.go('/');
    } else {
      setState(() => _error = r.errorOrNull);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expected = _expected;
    final declared = Money.parse(_declared.text);
    final variance = expected == null ? null : declared - expected;

    return Scaffold(
      appBar: AppBar(title: const Text('Close shift')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= _step
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            if (_step == 0) ...[
              Text('Expected cash', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                expected?.format() ?? '…',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const Spacer(),
              FilledButton(
                onPressed: expected == null ? null : () => setState(() => _step = 1),
                child: const Text('Next — count drawer'),
              ),
            ] else if (_step == 1) ...[
              Text('Declared cash', style: Theme.of(context).textTheme.titleMedium),
              TextField(
                controller: _declared,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(prefixText: '₹ '),
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => setState(() => _step = 2),
                child: const Text('Next — variance'),
              ),
            ] else ...[
              Text('Variance', style: Theme.of(context).textTheme.titleMedium),
              Text(
                variance?.format() ?? '—',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: (variance?.paise ?? 0) == 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Reason (required if |variance| > ₹50)',
                ),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _confirm,
                child: const Text('Confirm & lock'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
