import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Local Supabase defaults (override with --dart-define=SUPABASE_URL=...).
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54321',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
);

const _demoAnonPrefix =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1v';

bool get isDemoAnonKey => supabaseAnonKey.startsWith(_demoAnonPrefix);

bool get isCloudSupabaseUrl => supabaseUrl.contains('supabase.co');

/// User-facing hint when dart-defines are wrong. Null if config looks ok.
String? get supabaseConfigHint {
  if (isCloudSupabaseUrl && isDemoAnonKey) {
    return 'Config mismatch: cloud URL with local demo anon key. '
        'Re-run with the anon key from '
        'Dashboard → $supabaseUrl → Settings → API.';
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
    'key=$prefix…$suffix jwtIss=$jwtIss demoKey=$isDemoAnonKey',
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
