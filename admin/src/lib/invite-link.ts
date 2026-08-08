/**
 * Called by: staff/invite-share.tsx (Copy link / Share), join/page.tsx (Open in app).
 * Single source of truth for the invite URL so it can't drift between call sites.
 *
 * NEXT_PUBLIC_* because these are read in a client component. The bare VERCEL_URL
 * is deliberately not used as a fallback: it points at the per-deployment preview
 * host, which changes on every push and would bake a dead link into a shared invite.
 */
/**
 * Mirror of mobile/lib/invite_code.dart — accepts `ABCD-1234` or `abcd1234`.
 * Lives here rather than in redeem-form.tsx because that file is 'use client',
 * so its exports become client references and can't run during a server render.
 */
export function normalizeInviteCode(raw: string): string {
  const c = raw.trim().toUpperCase().replace(/\s+/g, '').replace(/[–—−]/g, '-');
  if (c.includes('-') || c.length < 5) return c;
  return `${c.slice(0, 4)}-${c.slice(4)}`;
}

export function inviteUrl(code: string): string {
  const base =
    process.env.NEXT_PUBLIC_SITE_URL ??
    (process.env.NEXT_PUBLIC_VERCEL_PROJECT_PRODUCTION_URL
      ? `https://${process.env.NEXT_PUBLIC_VERCEL_PROJECT_PRODUCTION_URL}`
      : '');
  return `${base}/join?code=${encodeURIComponent(code)}`;
}

/** Custom-scheme URL that opens the mobile app straight at its /join route. */
export function inviteAppUrl(code: string): string {
  // Three slashes: "join" must parse as the path, not the host, or GoRouter
  // resolves "/" instead of "/join". Mirrors the ros intent-filter in
  // mobile/android/app/src/main/AndroidManifest.xml.
  return `ros:///join?code=${encodeURIComponent(code)}`;
}
