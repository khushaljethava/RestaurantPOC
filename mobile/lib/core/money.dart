/// Money in integer paise. Convert at repository boundary to/from DB rupees.
class Money implements Comparable<Money> {
  const Money(this.paise);

  factory Money.fromRupees(num rupees) =>
      Money((rupees * 100).round());

  factory Money.parse(String raw) {
    final v = double.tryParse(raw.trim()) ?? 0;
    return Money.fromRupees(v);
  }

  final int paise;

  double get rupees => paise / 100.0;

  Money operator +(Money o) => Money(paise + o.paise);
  Money operator -(Money o) => Money(paise - o.paise);
  Money operator *(num n) => Money((paise * n).round());

  Money percent(num pct) => Money(((paise * pct) / 100).round());

  bool get isNegative => paise < 0;
  bool get isZero => paise == 0;

  String format({String symbol = '₹'}) {
    final sign = paise < 0 ? '-' : '';
    final abs = paise.abs();
    final whole = abs ~/ 100;
    final frac = abs % 100;
    final wholeStr = _indianGroup(whole);
    return '$sign$symbol$wholeStr.${frac.toString().padLeft(2, '0')}';
  }

  static String _indianGroup(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  /// Apply stall rounding rule to a due amount.
  Money applyRounding(String rule) {
    if (rule == 'none') return this;
    final r = rupees;
    if (rule == 'rupee_5') {
      return Money.fromRupees((r / 5).round() * 5);
    }
    return Money.fromRupees(r.round());
  }

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => format();
}
