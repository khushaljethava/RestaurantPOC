import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'errors.dart';

/// Thrown when the user dismisses the Google account picker.
class GoogleSignInCanceled implements Exception {
  const GoogleSignInCanceled();
}

var _googleReady = false;

Future<void> _ensureGoogleInitialized() async {
  if (_googleReady) return;
  final hint = googleConfigHint;
  if (hint != null) throw StateError(hint);
  await GoogleSignIn.instance.initialize(
    serverClientId: googleWebClientId,
    clientId: googleIosClientId.isEmpty ? null : googleIosClientId,
  );
  _googleReady = true;
}

/// Native Google → Supabase session. Throws [GoogleSignInCanceled] on dismiss.
Future<void> signInWithGoogle() async {
  await _ensureGoogleInitialized();
  debugPrint('[auth/google] authenticate start');

  late final GoogleSignInAccount account;
  try {
    account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email', 'profile', 'openid'],
    );
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      throw const GoogleSignInCanceled();
    }
    rethrow;
  }

  final idToken = account.authentication.idToken;
  if (idToken == null || idToken.isEmpty) {
    throw StateError('Google did not return an ID token.');
  }

  // Supabase Google provider expects an access token alongside the ID token.
  final authz =
      await account.authorizationClient.authorizationForScopes(const [
        'email',
        'profile',
        'openid',
      ]) ??
      await account.authorizationClient.authorizeScopes(const [
        'email',
        'profile',
        'openid',
      ]);

  await Supabase.instance.client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: authz.accessToken,
  );
  debugPrint(
    '[auth/google] ok uid=${Supabase.instance.client.auth.currentUser?.id}',
  );
}

/// User-facing message for Google / Supabase failures. Null = silent cancel.
String? mapGoogleAuthError(Object e) {
  if (e is GoogleSignInCanceled) return null;
  if (e is GoogleSignInException) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => null,
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        e.description ??
            'Google Sign-In is misconfigured. Check OAuth client IDs.',
      _ => e.description ?? mapError(e),
    };
  }
  if (e is StateError) return e.message;
  return googleConfigHint ?? mapError(e);
}
