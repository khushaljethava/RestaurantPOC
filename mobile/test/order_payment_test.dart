import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/order_payment.dart';

void main() {
  test('orderNeedsPayment: null bill → true', () {
    expect(orderNeedsPayment({'id': '1'}), isTrue);
    expect(orderNeedsPayment({'id': '1', 'bill': null}), isTrue);
  });

  test('orderNeedsPayment: open bill → true, paid → false', () {
    expect(
      orderNeedsPayment({
        'bill': {'status': 'open', 'total': 100, 'discount': 0},
      }),
      isTrue,
    );
    expect(
      orderNeedsPayment({
        'bill': {'status': 'paid', 'total': 100, 'discount': 0},
      }),
      isFalse,
    );
  });

  test('orderBillDue applies discount and rounding', () {
    expect(
      orderBillDue({
        'bill': {
          'total': 100,
          'discount': 10,
          'rounding_amount': 0.5,
        },
      }),
      90.5,
    );
    expect(orderBillDue({'id': '1'}), 0);
  });
}
