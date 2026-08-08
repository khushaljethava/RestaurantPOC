/// Build a standard UPI intent URI for QR / deep-link collect.
/// Works with Paytm Business VPA (e.g. merchant@paytm) and any UPI handle.
String buildUpiPayUri({
  required String vpa,
  required String payeeName,
  required double amount,
  String? note,
  String currency = 'INR',
}) {
  final pa = Uri.encodeComponent(vpa.trim());
  final pn = Uri.encodeComponent(
    payeeName.trim().isEmpty ? 'Merchant' : payeeName.trim(),
  );
  final am = amount.toStringAsFixed(2);
  final tn = Uri.encodeComponent((note ?? 'ROS bill').trim());
  return 'upi://pay?pa=$pa&pn=$pn&am=$am&cu=$currency&tn=$tn';
}

/// Cheap shape check for a VPA (`name@bank`). Deliberately permissive: handles
/// vary widely by PSP and the bank is the real validator — this only catches
/// the typo that would otherwise ship a dead QR to the counter.
bool isValidVpa(String vpa) => RegExp(
  r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z][a-zA-Z0-9.]{1,}$',
).hasMatch(vpa.trim());
