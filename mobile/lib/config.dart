import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Override with --dart-define=SUPABASE_URL=... / SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54321',
);

const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// User-facing hint when dart-defines are wrong. Null if config looks ok.
String? get supabaseConfigHint {
  if (supabaseAnonKey.isEmpty) {
    return 'Missing SUPABASE_ANON_KEY. Pass --dart-define=SUPABASE_ANON_KEY=...';
  }
  if (!supabaseAnonKey.startsWith('eyJ')) {
    return 'Anon key looks truncated (should start with eyJ). '
        'Check --dart-define=SUPABASE_ANON_KEY=...';
  }
  return null;
}

/// Safe diagnostics — never logs the full anon key.
void logSupabaseConfig(String where) {
  final key = supabaseAnonKey;
  final prefix = key.length >= 8 ? key.substring(0, 8) : key;
  final suffix = key.length >= 6 ? key.substring(key.length - 6) : key;
  final jwtIss = _jwtIss(key);

  debugPrint(
    '[supabase/$where] url=$supabaseUrl keyLen=${key.length} '
    'key=$prefix…$suffix jwtIss=$jwtIss',
  );
  final hint = supabaseConfigHint;
  if (hint != null) {
    debugPrint('[supabase/$where] MISMATCH: $hint');
  }
}

String? _jwtIss(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length < 2) return null;
    var payload = parts[1];
    final pad = (4 - payload.length % 4) % 4;
    payload = '$payload${'=' * pad}';
    final map = jsonDecode(utf8.decode(base64Url.decode(payload)));
    if (map is Map && map['iss'] != null) return '${map['iss']}';
  } catch (_) {}
  return null;
}
