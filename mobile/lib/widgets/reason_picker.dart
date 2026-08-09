import 'package:flutter/material.dart';

const kVoidReasons = [
  'Wrong entry',
  'Customer changed mind',
  'Out of stock',
  'Quality',
  'Other',
];

const kDiscountReasons = [
  'Staff meal',
  'Complaint',
  'Promo',
  'Wastage',
  'Other',
];

const kRefundReasons = [
  'Wrong item',
  'Quality',
  'Customer request',
  'Other',
];

Future<String?> showReasonPicker(
  BuildContext context, {
  required String title,
  required List<String> presets,
}) async {
  final other = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in presets)
                  if (p != 'Other')
                    ActionChip(
                      label: Text(p),
                      onPressed: () => Navigator.pop(ctx, p),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: other,
              decoration: const InputDecoration(labelText: 'Other reason'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                final t = other.text.trim();
                if (t.isNotEmpty) Navigator.pop(ctx, t);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(other.dispose);
}
