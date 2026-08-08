import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../providers/cart.dart';
import '../services/upi.dart';
import '../theme/ros_theme.dart';
import 'glass.dart';
import 'ros_ui.dart';

class UpiConfig {
  const UpiConfig({required this.vpa, required this.payeeName});
  final String vpa;
  final String payeeName;
}

class PaymentSheetResult {
  PaymentSheetResult(this.payments);
  final List<Map<String, dynamic>> payments;
}

Future<PaymentSheetResult?> showPaymentSheet(
  BuildContext context, {
  required double due,
  UpiConfig? upi,
  String? billNote,
}) {
  return showModalBottomSheet<PaymentSheetResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PaymentSheetBody(due: due, upi: upi, billNote: billNote),
  );
}

class _PaymentSheetBody extends StatefulWidget {
  const _PaymentSheetBody({required this.due, this.upi, this.billNote});
  final double due;
  final UpiConfig? upi;
  final String? billNote;

  @override
  State<_PaymentSheetBody> createState() => _PaymentSheetBodyState();
}

class _PaymentSheetBodyState extends State<_PaymentSheetBody> {
  final _cash = TextEditingController();
  final _upi = TextEditingController();
  final _card = TextEditingController();
  final _upiRef = TextEditingController();
  final _tender = TextEditingController();
  String? _error;
  var _mode = 'cash';

  @override
  void initState() {
    super.initState();
    _cash.text = widget.due.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _cash.dispose();
    _upi.dispose();
    _card.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  void _payFullCash() {
    setState(() {
      _mode = 'cash';
      _cash.text = widget.due.toStringAsFixed(2);
      _upi.clear();
      _card.clear();
      _error = null;
    });
  }

  void _payFullUpi() {
    setState(() {
      _mode = 'upi';
      _upi.text = widget.due.toStringAsFixed(2);
      _cash.clear();
      _card.clear();
      _error = null;
    });
  }

  void _submit() {
    final cash = _parse(_cash);
    final upi = _parse(_upi);
    final card = _parse(_card);
    if (!paymentsMatchDue([cash, upi, card], widget.due)) {
      setState(() {
        _error =
            'Amounts must sum to ${formatInr(widget.due)} (got ${formatInr(cash + upi + card)})';
      });
      return;
    }
    final payments = <Map<String, dynamic>>[];
        if (cash > 0) {
      payments.add({
        'method': 'cash',
        'amount': cash,
        'idempotency_key': const Uuid().v4(),
      });
    }
    if (upi > 0) {
      payments.add({
        'method': 'upi',
        'amount': upi,
        'idempotency_key': const Uuid().v4(),
        if (_upiRef.text.trim().isNotEmpty) 'upi_ref': _upiRef.text.trim(),
      });
    }
    if (card > 0) {
      payments.add({
        'method': 'card',
        'amount': card,
        'idempotency_key': const Uuid().v4(),
      });
    }
    // legacy add helpers removed
    if (payments.isEmpty) {
      setState(() => _error = 'Enter at least one payment');
      return;
    }
    Navigator.of(context).pop(PaymentSheetResult(payments));
  }

  Widget _modeChip(String id, String label, VoidCallback? onTap) {
    final selected = _mode == id;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: RosColors.secondaryContainer,
      labelStyle: TextStyle(
        color: selected ? RosColors.onSecondaryContainer : RosColors.onSurface,
        fontWeight: FontWeight.w500,
      ),
      onSelected: onTap == null ? null : (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final upiCfg = widget.upi;
    final upiReady = upiCfg != null && upiCfg.vpa.trim().isNotEmpty;
    final showQr = _mode == 'upi' && upiReady && _parse(_upi) > 0;
    final qrData = showQr
        ? buildUpiPayUri(
            vpa: upiCfg.vpa,
            payeeName: upiCfg.payeeName,
            amount: _parse(_upi),
            note: widget.billNote,
          )
        : null;
    final payeeLabel = upiReady
        ? (upiCfg.payeeName.isEmpty ? upiCfg.vpa : upiCfg.payeeName)
        : '';
    final vpaLabel = upiReady ? upiCfg.vpa : '';

    // Sheets are transparent in the glass theme — the body brings its own
    // frosted surface.
    return GlassPanel(
      color: RosColors.glassStrong,
      radius: 28,
      blur: 28,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pay', style: Theme.of(context).textTheme.titleMedium),
            MoneyText(
              widget.due,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _modeChip('cash', 'Cash', _payFullCash),
                _modeChip('upi', 'UPI', upiReady ? _payFullUpi : null),
                _modeChip(
                  'split',
                  'Split',
                  () => setState(() => _mode = 'split'),
                ),
              ],
            ),
            if (!upiReady)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Set UPI VPA in stall settings (Paytm Business) to show QR.',
                  style: TextStyle(fontSize: 12, color: RosColors.pending),
                ),
              ),
            if (qrData != null) ...[
              const SizedBox(height: 12),
              Center(
                child: QrImageView(
                  data: qrData,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$payeeLabel\n$vpaLabel',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Ask customer to scan, then confirm UPI received.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (_mode != 'upi' || !showQr) ...[
              TextField(
                controller: _cash,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Cash'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _upi,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'UPI'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _card,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Card'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RosColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RosErrorText(_error!),
              ),
            ],
            const SizedBox(height: 12),

            if (_mode == 'cash') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final preset in [widget.due, 100.0, 200.0, 500.0])
                    ActionChip(
                      label: Text(preset == widget.due ? 'Exact' : '₹${preset.toStringAsFixed(0)}'),
                      onPressed: () {
                        setState(() {
                          _tender.text = preset.toStringAsFixed(2);
                          _cash.text = widget.due.toStringAsFixed(2);
                        });
                      },
                    ),
                ],
              ),
              TextField(
                controller: _tender,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tendered'),
                onChanged: (_) => setState(() {}),
              ),
              Builder(builder: (context) {
                final tender = double.tryParse(_tender.text) ?? 0;
                final change = tender - widget.due;
                if (tender <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'CHANGE DUE ${formatInr(change < 0 ? 0 : change)}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                );
              }),
            ],
            if (_mode == 'upi') ...[
              TextField(
                controller: _upiRef,
                decoration: const InputDecoration(
                  labelText: 'UPI ref (last 6 digits)',
                ),
              ),
            ],

            FilledButton(
              onPressed: _submit,
              child: Text(
                _mode == 'upi' ? 'Confirm UPI received' : 'Confirm payment',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
