import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/invite_code.dart';
import 'package:mobile/services/google_auth.dart';

void main() {
  test('pathAfterAuth routes invite to join', () {
    expect(pathAfterAuth(null), '/');
    expect(pathAfterAuth(''), '/');
    expect(pathAfterAuth('ABCD-1234'), '/join?code=ABCD-1234');
    expect(
      pathAfterAuth('A B'),
      '/join?code=${Uri.encodeComponent('A B')}',
    );
  });

  test('mapGoogleAuthError silences cancel', () {
    expect(mapGoogleAuthError(const GoogleSignInCanceled()), isNull);
    expect(
      mapGoogleAuthError(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      isNull,
    );
    expect(
      mapGoogleAuthError(StateError('Google did not return an ID token.')),
      'Google did not return an ID token.',
    );
  });
}
