# ROS Mobile

Flutter staff app (Android + iOS) for Stall Manager / ROS.

## Run

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://uhmaizdntpztcozoreel.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVobWFpemRudHB6dGNvem9yZWVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0ODAwNzcsImV4cCI6MjA5MDA1NjA3N30.DDfTkyx9GynsIBp3XmtpcCzuZEeCMxTO_6JC5QCC4Rk \
  --dart-define=GOOGLE_WEB_CLIENT_ID=623493181876-rur8usmhh2up73m3eic7is92da6b2oh7.apps.googleusercontent.com
```

Optional iOS client (needed for iOS Google Sign-In):

```bash
--dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
```

## Google Sign-In setup

1. **Google Cloud Console**
   - Create OAuth **Web** client → copy client ID + secret.
   - Create OAuth **Android** client: package `com.kj.stall`, SHA-1 from your debug/release keystore (`keytool -list -v -keystore ~/.android/debug.keystore`).
   - For iOS: OAuth iOS client + URL scheme in Xcode (reversed client ID).

2. **Supabase Dashboard** (Auth → Providers → Google)
   - Enable Google.
   - Paste the **Web** client ID and secret (same Web client ID as `GOOGLE_WEB_CLIENT_ID`).

3. **App**
   - Pass `GOOGLE_WEB_CLIENT_ID` via `--dart-define` (see above).
   - Login primary CTA is **Continue with Google**; email/password is under **Use email instead**.




flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://uhmaizdntpztcozoreel.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVobWFpemRudHB6dGNvem9yZWVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0ODAwNzcsImV4cCI6MjA5MDA1NjA3N30.DDfTkyx9GynsIBp3XmtpcCzuZEeCMxTO_6JC5QCC4Rk \
  --dart-define=GOOGLE_WEB_CLIENT_ID=623493181876-rur8usmhh2up73m3eic7is92da6b2oh7.apps.googleusercontent.com