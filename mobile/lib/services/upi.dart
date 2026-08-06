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
  final pn = Uri.encodeComponent(payeeName.trim().isEmpty ? 'Merchant' : payeeName.trim());
  final am = amount.toStringAsFixed(2);
  final tn = Uri.encodeComponent((note ?? 'ROS bill').trim());
  return 'upi://pay?pa=$pa&pn=$pn&am=$am&cu=$currency&tn=$tn';
}
