import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'services/errors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before anything that can throw, so a failed boot is reported, not silent.
  installErrorHandlers();
  logSupabaseConfig('boot');
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  debugPrint('[supabase/boot] initialize ok');
  runApp(const ProviderScope(child: RosApp()));
}
