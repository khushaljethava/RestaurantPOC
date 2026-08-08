import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/invite_code.dart';
import 'package:mobile/providers/cart.dart';
import 'package:mobile/providers/bill.dart';
import 'package:mobile/providers/tables.dart';
import 'package:mobile/services/upi.dart';

void main() {
  test('normalizeInviteCode inserts hyphen when omitted', () {
    expect(normalizeInviteCode('ubqt4371'), 'UBQT-4371');
    expect(normalizeInviteCode(' UBQT-4371 '), 'UBQT-4371');
    expect(normalizeInviteCode('abcd'), 'ABCD');
    expect(normalizeInviteCode('ubqt–4371'), 'UBQT-4371'); // en-dash
  });

  test('cart groups lines by stall via notifier', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(cartProvider.notifier);
    n.add(
      CartLine(
        stallId: 'a',
        menuItemId: '1',
        name: 'Dosa',
        unitPrice: 80,
        qty: 2,
      ),
    );
    n.add(
      CartLine(
        stallId: 'b',
        menuItemId: '2',
        name: 'Tea',
        unitPrice: 20,
        qty: 1,
      ),
    );
    n.add(
      CartLine(
        stallId: 'a',
        menuItemId: '1',
        name: 'Dosa',
        unitPrice: 80,
        qty: 1,
      ),
    );
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
    n.add(
      CartLine(
        stallId: 'a',
        menuItemId: '1',
        name: 'Dosa',
        unitPrice: 80,
        qty: 1,
        notes: 'less spicy',
      ),
    );
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

  test('isValidVpa accepts real handles and rejects typos', () {
    expect(isValidVpa('shop@paytm'), isTrue);
    expect(isValidVpa('anna.stall-2@okhdfcbank'), isTrue);
    expect(isValidVpa(' shop@paytm '), isTrue);
    expect(isValidVpa('shop'), isFalse); // no handle
    expect(isValidVpa('shop@'), isFalse);
    expect(isValidVpa('@paytm'), isFalse);
    expect(isValidVpa('shop@9'), isFalse); // handle must start with a letter
  });

  test('tableCards merges registered tables with occupied labels', () {
    final container = ProviderContainer(
      overrides: [
        stallTablesProvider.overrideWith(
          (ref) async => [
            {'id': '1', 'label': 'T1', 'is_active': true},
            {'id': '2', 'label': 'T2', 'is_active': true},
            {'id': '3', 'label': 'T9', 'is_active': false},
          ],
        ),
        // T2 has a live tab; T7 was typed ad-hoc at the POS, never registered.
        openTableLabelsProvider.overrideWith((ref) async => ['T2', 'T7']),
      ],
    );
    addTearDown(container.dispose);

    return container.read(stallTablesProvider.future).then((_) async {
      await container.read(openTableLabelsProvider.future);
      final cards = container.read(tableCardsProvider).requireValue;
      expect(cards.map((c) => c.label), ['T1', 'T2', 'T7']); // T9 inactive
      expect(cards.firstWhere((c) => c.label == 'T1').occupied, isFalse);
      expect(cards.firstWhere((c) => c.label == 'T2').occupied, isTrue);
      expect(cards.firstWhere((c) => c.label == 'T7').occupied, isTrue);
    });
  });
}
