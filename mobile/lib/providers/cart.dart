import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../services/cart_draft.dart';

class CartLine {
  CartLine({
    required this.stallId,
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    required this.qty,
    this.notes,
  });

  final String stallId;
  final String menuItemId;
  final String name;
  final Money unitPrice;
  int qty;
  String? notes;

  Money get lineTotal => unitPrice * qty;

  CartLine copyWith({int? qty, String? notes}) => CartLine(
        stallId: stallId,
        menuItemId: menuItemId,
        name: name,
        unitPrice: unitPrice,
        qty: qty ?? this.qty,
        notes: notes ?? this.notes,
      );
}

class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  void add(CartLine line) {
    final i = state.indexWhere(
      (e) => e.menuItemId == line.menuItemId && e.stallId == line.stallId,
    );
    if (i >= 0) {
      final next = [...state];
      next[i] = next[i].copyWith(qty: next[i].qty + line.qty);
      state = next;
    } else {
      state = [...state, line];
    }
    saveCartDraft(state);
  }

  void setQty(String stallId, String menuItemId, int qty) {
    if (qty <= 0) {
      state = [
        for (final e in state)
          if (!(e.menuItemId == menuItemId && e.stallId == stallId)) e,
      ];
    } else {
      state = [
        for (final e in state)
          if (e.menuItemId == menuItemId && e.stallId == stallId)
            e.copyWith(qty: qty)
          else
            e,
      ];
    }
    saveCartDraft(state);
  }

  void setNotes(String stallId, String menuItemId, String notes) {
    state = [
      for (final e in state)
        if (e.menuItemId == menuItemId && e.stallId == stallId)
          CartLine(
            stallId: e.stallId,
            menuItemId: e.menuItemId,
            name: e.name,
            unitPrice: e.unitPrice,
            qty: e.qty,
            notes: notes.isEmpty ? null : notes,
          )
        else
          e,
    ];
    saveCartDraft(state);
  }

  void clear() {
    state = const [];
    clearCartDraft();
  }

  Future<void> restoreDraft() async {
    final lines = await loadCartDraft();
    if (lines.isNotEmpty) state = lines;
  }

  Money get total =>
      state.fold(const Money(0), (sum, e) => sum + e.lineTotal);

  Map<String, List<Map<String, dynamic>>> toRpcItemsByStall() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in state) {
      map.putIfAbsent(e.stallId, () => []).add({
        'menu_item_id': e.menuItemId,
        'qty': e.qty,
        if (e.notes != null && e.notes!.isNotEmpty) 'notes': e.notes,
      });
    }
    return map;
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);

double billDue(double total, double discount) => total - discount;

bool paymentsMatchDue(Iterable<double> amounts, double due) {
  final sum = amounts.fold<double>(0, (a, b) => a + b);
  return (sum - due).abs() < 0.005;
}
