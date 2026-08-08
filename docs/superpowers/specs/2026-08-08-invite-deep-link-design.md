# Invite deep link: admin website → mobile app

**Date:** 2026-08-08
**Status:** Approved, ready for implementation planning
**Scope:** Stall invites only. Android only.

## Problem

An owner generates a stall invite code in the admin app at `/staff`. The only way a
new staff member can use it is to read the code off someone's screen and retype it
into the mobile app. There is no link.

The link half of the flow was never built:

| Layer | State before this change |
| --- | --- |
| `mobile/android/app/src/main/AndroidManifest.xml` | Only `MAIN`/`LAUNCHER` intent-filters. No URL can open the app. |
| `mobile/pubspec.yaml` | No deep-link package, and `flutter_deeplinking_enabled` is not set. |
| `admin/src/app/(app)/staff/page.tsx` | Renders the code as bare text. No copy, no share, no URL. |
| `admin/src/app/` | No public `/join` route. |
| `admin/public/` | No `.well-known/assetlinks.json`. |

What already works and must not be rebuilt: the in-app routing. `mobile/lib/app.dart`
declares `/join` and exempts it from the auth redirect; `login_screen.dart:23` and
`signup_screen.dart:25` thread `?invite=` through sign-in and sign-up back into
`/join?code=`; `JoinScreen` auto-redeems when it arrives with a code and a session;
`normalizeInviteCode` is mirrored between `mobile/lib/invite_code.dart` and
`admin/src/app/(app)/staff/redeem-form.tsx`. This spec only feeds a URL into that
existing machinery.

## Constraints

- The app is unpublished and sideloaded as an APK. There is no Play Store listing.
- There is no Apple developer team and iOS is not planned. No iOS work in this spec.
- Android 12+ ignores an unverified `https` intent-filter entirely — no chooser, the
  link just opens the browser. So `https` links cannot be the day-one mechanism, but
  the manifest entry costs nothing and activates at publication.

## Design

### 1. Mobile: Flutter built-in deep linking

Add to `AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="true" />
```

Flutter passes the incoming URI's **path** to `GoRouter`. No Dart changes and no new
dependency: `/join?code=…` already resolves to `JoinScreen`, and the router's
`redirect` already treats `/join` as auth-exempt.

Two intent-filters on `MainActivity`:

```xml
<!-- Works today on a sideloaded APK. -->
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="ros" />
</intent-filter>

<!-- Inert until assetlinks.json carries the real fingerprint. -->
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https"
        android:host="restaurant-poc-eight.vercel.app"
        android:pathPrefix="/join" />
</intent-filter>
```

The custom-scheme URL is `ros:///join?code=ABCD-1234` — **three slashes**. With two
(`ros://join?…`) the `join` segment parses as the URI host and the path is empty, so
GoRouter would resolve `/` instead of `/join`.

The `ros` filter constrains scheme only, with no host. Any `ros://` URI opens the app
and is routed by path; unknown paths fall through GoRouter's normal handling.

Also fix `android:label="mobile"` → `"ROS"`. It is the name users see under the
launcher icon, and this is the file being edited.

**Rejected alternative:** the `app_links` package with a manual URI stream. Same
behavior, but adds a dependency and makes us own the cold-start/session-restore race
that the built-in path handles. If built-in deep linking proves unreliable on cold
start, `app_links` is a contained follow-up behind the same routes.

### 2. Admin: link generation

New `admin/src/lib/invite-link.ts`:

```ts
export function inviteUrl(code: string): string {
  const base =
    process.env.NEXT_PUBLIC_SITE_URL ??
    `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`;
  return `${base}/join?code=${encodeURIComponent(code)}`;
}
```

Single source of truth so the URL cannot drift between call sites.

New client component `admin/src/app/(app)/staff/invite-share.tsx`, rendered in each
active invite `<Card>` on `staff/page.tsx`:

- **Copy link** — `navigator.clipboard.writeText(inviteUrl(code))`, with a transient
  "Copied" confirmation.
- **Share** — `navigator.share({ url })` when available, otherwise falls back to the
  same copy behavior.

Only these buttons need to be a client component; the existing Revoke server-action
form stays exactly as it is.

### 3. Admin: public `/join` landing page

New `admin/src/app/join/page.tsx`, deliberately outside the `(app)` route group so it
inherits no authenticated layout. A server component reading `searchParams.code`.

Renders:

- The code, large and monospace, with a copy button.
- **Open in ROS app** → `ros:///join?code=…`
- **Don't have the app?** → `process.env.NEXT_PUBLIC_APK_URL`, a direct APK download.
  At publication this env var becomes a Play Store URL; no code changes.

If `code` is absent or malformed, render a plain "This invite link is incomplete"
message with no buttons.

Two deliberate non-features:

- **No database lookup of the code.** Validating server-side would let an anonymous
  visitor probe which invite codes exist, and codes are short. Validity is decided by
  `redeem_stall_invite` at redemption time, behind auth.
- **No app-installed detection and no auto-redirect timer.** These are unreliable
  across Android browsers. Two explicit buttons work everywhere.

### 4. Admin: middleware

`admin/src/middleware.ts` currently redirects every document request to `/login`
unless the path starts with `/login` or `/onboarding`. Without a change here the
landing page is unreachable and the whole feature silently fails in production.

- Add `/join` to the `isPublic` check.
- Add `.well-known` to the `config.matcher` exclusion list, so Google's verification
  fetch does not trigger a Supabase auth call.

### 5. Android App Links assets

`admin/public/.well-known/assetlinks.json`, served statically by Next.js:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.rest.mobile",
    "sha256_cert_fingerprints": ["REPLACE_AT_PUBLICATION"]
  }
}]
```

`com.rest.mobile` is the current `applicationId`
(`mobile/android/app/build.gradle.kts:24`). It is permanent once published — if it
should be something else, change it before the first Play upload, not after.

The fingerprint comes from Play Console → Setup → App Signing after the first upload.
Until it is real, `https` invite links land on the web page, which offers the `ros://`
button — one extra tap, nothing broken.

## Data flow

```
Owner clicks "Generate staff invite" on /staff
  → create_stall_invite RPC returns ABCD-1234
  → inviteUrl() → https://restaurant-poc-eight.vercel.app/join?code=ABCD-1234
  → owner shares the link

Recipient opens the link on Android
  ├─ app installed + App Links verified → app opens directly at /join?code=…
  └─ otherwise → /join landing page
       ├─ "Open in ROS app" → ros:///join?code=… → app opens at /join?code=…
       └─ "Download" → APK

In the app at /join?code=…
  ├─ session exists → JoinScreen auto-redeems via redeem_stall_invite → /
  └─ no session   → /login?invite=… → sign in or sign up
                  → router redirect returns to /join?code=… → auto-redeem → /
```

## Error handling

| Case | Behavior |
| --- | --- |
| Link opened on desktop | Landing page renders normally; `ros://` does nothing; APK link still works. |
| `?code` missing/malformed | "This invite link is incomplete", no action buttons. |
| `ros://` tapped, app not installed | Android shows no handler; the download button is directly below it. |
| Code revoked or invalid | `redeem_stall_invite` raises `P0002`; `JoinScreen`'s existing `PostgrestException` handler shows the message. |
| Deep link arrives cold, session still restoring | GoRouter's `redirect` sends to `/login?invite=…`; sign-in returns to `/join`. Unauthenticated is the safe default. |
| `NEXT_PUBLIC_APK_URL` unset | Download button is not rendered. Code and app button still work. |

## Testing

Automated coverage is limited to the existing `normalizeInviteCode` unit test; this
feature is inherently manual to verify.

Manual matrix via
`adb shell am start -a android.intent.action.VIEW -d "ros:///join?code=ABCD-1234"`:

1. Cold start, signed in → lands on `/join`, auto-redeems, ends at `/`.
2. Warm start, signed in → same.
3. Cold start, signed out → `/login?invite=…`; after sign-in, redeems, ends at `/`.
4. Cold start, no account → `/login?invite=…` → sign up → redeems, ends at `/`.
5. Malformed path `ros:///nope` → app opens without crashing.

Plus, on the deployed admin: `/join?code=X` loads without a login redirect while
signed out, and `/join` with no code renders the incomplete-link message.

## Out of scope

- **iOS.** No Universal Links, no `apple-app-site-association`, no entitlements.
- **Group invites.** `/group` codes go through `request_join_group`, and mobile has no
  `/join-group` route to land on. Linking them requires designing a mobile screen that
  does not exist.
- **Invite security hardening.** Reading `supabase/migrations/0006_invites.sql` during
  this design surfaced four issues, all pre-existing and none introduced here. They
  belong to a separate spec and should be scheduled before public launch:
  1. `grant insert, update, delete on public.stall_invite to authenticated` combined
     with an RLS policy that only checks stall membership lets any staff member bypass
     the owner-only check in `create_stall_invite` and mint a `manager` invite for
     themselves.
  2. Invites have no `expires_at`, `max_uses`, or `used_at` — a leaked code is a
     permanent bearer credential.
  3. Codes are 4 characters from a 32-character alphabet plus a number, redeemable
     through an unthrottled `security definer` RPC.
  4. `gen_invite_code` can emit five digits (`lpad` over a value up to 65535),
     producing e.g. `ABCD-65535`, which the hyphen-less branch of `normalizeInviteCode`
     would split incorrectly.

  Publishing invite *links* widens the blast radius of items 2 and 3, since links are
  more likely to be forwarded than typed codes.
- **Production hardening and mobile gap analysis.** Both were part of the original
  request and are deferred to their own spec → plan → implementation cycles.
