import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/cart.dart';
import 'package:mobile/services/upi.dart';

void main() {
  test('cart groups lines by stall via notifier', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(cartProvider.notifier);
    n.add(CartLine(
        stallId: 'a',
        menuItemId: '1',
        name: 'Dosa',
        unitPrice: 80,
        qty: 2));
    n.add(CartLine(
        stallId: 'b',
        menuItemId: '2',
        name: 'Tea',
        unitPrice: 20,
        qty: 1));
    n.add(CartLine(
        stallId: 'a',
        menuItemId: '1',
        name: 'Dosa',
        unitPrice: 80,
        qty: 1));
    final state = container.read(cartProvider);
    expect(state.length, 2);
    expect(state.firstWhere((e) => e.stallId == 'a').qty, 3);
    final byStall = n.toRpcItemsByStall();
    expect(byStall.keys.toSet(), {'a', 'b'});
    expect(byStall['a']!.single['qty'], 3);
    final total = state.fold<double>(0, (s, e) => s + e.lineTotal);
    expect(total, 260);
  });

  test('split payment arithmetic', () {
    expect(billDue(260, 0), 260);
    expect(paymentsMatchDue([100, 160], 260), isTrue);
    expect(paymentsMatchDue([100], 260), isFalse);
    expect(paymentsMatchDue([100.00, 50.00, 110.00], 260), isTrue);
  });

  test('discount reduces due', () {
    expect(billDue(260, 10), 250);
    expect(paymentsMatchDue([100, 150], billDue(260, 10)), isTrue);
  });

  test('notes appear in RPC payload', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(cartProvider.notifier);
    n.add(CartLine(
        stallId: 'a',
        menuItemId: '1',
        name: 'Dosa',
        unitPrice: 80,
        qty: 1,
        notes: 'less spicy'));
    final byStall = n.toRpcItemsByStall();
    expect(byStall['a']!.single['notes'], 'less spicy');
    n.setNotes('a', '1', 'extra crisp');
    expect(n.toRpcItemsByStall()['a']!.single['notes'], 'extra crisp');
    n.setNotes('a', '1', '');
    expect(n.toRpcItemsByStall()['a']!.single.containsKey('notes'), isFalse);
  });

  test('upi pay uri encodes vpa and amount', () {
    final uri = buildUpiPayUri(
      vpa: 'shop@paytm',
      payeeName: 'Test Stall',
      amount: 90.5,
      note: 'Bill 1',
    );
    expect(uri.startsWith('upi://pay?'), isTrue);
    expect(uri.contains('pa=shop%40paytm'), isTrue);
    expect(uri.contains('am=90.50'), isTrue);
    expect(uri.contains('cu=INR'), isTrue);
  });
}
