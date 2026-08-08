import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a thrown object into something worth showing a cashier mid-rush.
/// Screens funnel every `catch (e)` through this before assigning to their
/// `_error` field, so nobody sees `PostgrestException(code: 42501)` again.
String mapError(Object e) {
  if (e is PostgrestException) {
    switch (e.code) {
      case '42501': // insufficient_privilege — an RLS policy said no.
        return "You don't have permission to do that.";
      case '23505': // unique_violation
        return 'That already exists.';
      case '23503': // foreign_key_violation
        return 'Something it depends on was removed. Refresh and try again.';
      case 'PGRST301': // JWT expired
        return 'Your session expired. Sign in again.';
    }
    // RPCs raise their own messages (`raise exception '...'`) and those are
    // written for humans — pass them through rather than flattening them.
    return e.message;
  }
  if (e is AuthException) return e.message;
  if (e is StorageException) {
    return e.statusCode == '413'
        ? 'That image is too large.'
        : 'Upload failed: ${e.message}';
  }
  if (e is SocketException || e is TimeoutException) {
    return 'No connection. Check your network and try again.';
  }
  return 'Something went wrong. Try again.';
}

/// Routes framework and uncaught-async errors somewhere visible.
/// Wire a reporter (Crashlytics/Sentry) into [onError] when one is configured;
/// firebase_core is already a dependency, so that is config, not code.
void installErrorHandlers({void Function(Object, StackTrace)? onError}) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    onError?.call(details.exception, details.stack ?? StackTrace.current);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[uncaught] $error\n$stack');
    onError?.call(error, stack);
    return true; // handled — do not kill the isolate mid-service.
  };
}
