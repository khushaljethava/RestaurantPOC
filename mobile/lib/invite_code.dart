/// Normalize a stall invite for `redeem_stall_invite`.
/// Accepts `ABCD-1234` or `ABCD1234` (hyphen optional).
String normalizeInviteCode(String raw) {
  var c = raw.trim().toUpperCase();
  c = c.replaceAll(RegExp(r'\s+'), '');
  c = c.replaceAll(RegExp(r'[–—−]'), '-'); // unicode dashes → ASCII
  if (c.contains('-') || c.length < 5) return c;
  return '${c.substring(0, 4)}-${c.substring(4)}';
}

/// Where to send the user after a successful login/signup.
String pathAfterAuth(String? invite) {
  if (invite == null || invite.isEmpty) return '/';
  return '/join?code=${Uri.encodeComponent(invite)}';
}
