import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/money.dart';

void main() {
  test('fromRupees and format', () {
    expect(Money.fromRupees(10.5).paise, 1050);
    expect(Money(1050).format(), '₹10.50');
    expect(Money.fromRupees(120500).format(), '₹1,20,500.00');
  });

  test('rounding', () {
    expect(Money.fromRupees(10.4).applyRounding('rupee_1').paise, 1000);
    expect(Money.fromRupees(10.6).applyRounding('rupee_1').paise, 1100);
    expect(Money.fromRupees(12).applyRounding('rupee_5').paise, 1000);
    expect(Money.fromRupees(13).applyRounding('rupee_5').paise, 1500);
  });

  test('percent and change', () {
    final due = Money.fromRupees(85);
    final tender = Money.fromRupees(100);
    expect((tender - due).format(), '₹15.00');
    expect(Money.fromRupees(200).percent(10).paise, 2000);
  });
}
