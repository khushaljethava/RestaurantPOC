import '../providers/cart.dart';

/// True when “Given to customer” must collect Cash/UPI first.
bool orderNeedsPayment(Map<String, dynamic> order) {
  final bill = order['bill'];
  if (bill == null) return true;
  if (bill is Map) {
    return bill['status'] != 'paid';
  }
  return true;
}

/// Due amount from nested bill on an order row (0 if no bill).
double orderBillDue(Map<String, dynamic> order) {
  final bill = order['bill'];
  if (bill is! Map) return 0;
  final total = (bill['total'] as num?)?.toDouble() ?? 0;
  final discount = (bill['discount'] as num?)?.toDouble() ?? 0;
  final rounding = (bill['rounding_amount'] as num?)?.toDouble() ?? 0;
  return billDue(total, discount) + rounding;
}
