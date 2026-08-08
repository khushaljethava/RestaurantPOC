import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/money.dart';
import '../providers/cart.dart';

const _k = 'cart_draft_v1';

Future<void> saveCartDraft(List<CartLine> lines) async {
  final p = await SharedPreferences.getInstance();
  final raw = jsonEncode([
    for (final e in lines)
      {
        'stallId': e.stallId,
        'menuItemId': e.menuItemId,
        'name': e.name,
        'unitPricePaise': e.unitPrice.paise,
        'qty': e.qty,
        'notes': e.notes,
      },
  ]);
  await p.setString(_k, raw);
}

Future<List<CartLine>> loadCartDraft() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(_k);
  if (raw == null || raw.isEmpty) return [];
  final list = jsonDecode(raw) as List;
  return [
    for (final e in list)
      CartLine(
        stallId: e['stallId'] as String,
        menuItemId: e['menuItemId'] as String,
        name: e['name'] as String,
        unitPrice: Money(e['unitPricePaise'] as int),
        qty: e['qty'] as int,
        notes: e['notes'] as String?,
      ),
  ];
}

Future<void> clearCartDraft() async {
  final p = await SharedPreferences.getInstance();
  await p.remove(_k);
}
