import { normalizeInviteCode } from '@/lib/invite-link';
import { JoinActions } from './join-actions';

/**
 * Public invite landing page. Reached from a shared invite link, or directly
 * from the Android App Link once assetlinks.json carries the real fingerprint.
 *
 * Outside the (app) route group on purpose: no auth layout, no stall lookup.
 * /join is also allowlisted in middleware.ts — without that, every visit
 * redirects to /login and the whole invite flow silently breaks.
 *
 * Deliberately does NOT look the code up in the database. Doing so would let an
 * anonymous visitor probe which invite codes exist, and the codes are short.
 * Validity is decided by redeem_stall_invite at redemption time, behind auth.
 */
export const metadata = {
  title: 'Join a stall · StreetStall POS',
};

export default async function JoinPage({
  searchParams,
}: {
  searchParams: Promise<{ code?: string }>;
}) {
  const { code: raw } = await searchParams;
  const code = raw ? normalizeInviteCode(raw) : '';

  if (!code) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-3 p-6 text-center">
        <h1 className="text-xl font-semibold text-on-surface">
          This invite link is incomplete
        </h1>
        <p className="text-sm text-on-surface-variant">
          Ask whoever sent it to share the link again, or open the Stall Manager app
          and enter the code by hand.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <div className="text-center">
        <h1 className="text-xl font-semibold text-on-surface">
          You&apos;ve been invited to a stall
        </h1>
        <p className="mt-1 text-sm text-on-surface-variant">
          Open this in the Stall Manager app to join.
        </p>
      </div>

      <div className="rounded-md border border-border bg-surface p-5 text-center shadow-card">
        <p className="text-xs uppercase tracking-wide text-on-surface-variant">
          Invite code
        </p>
        <p className="mt-2 font-mono text-3xl font-medium tracking-[0.2em] text-on-surface">
          {code}
        </p>
      </div>

      <JoinActions code={code} apkUrl={process.env.NEXT_PUBLIC_APK_URL} />
    </main>
  );
}
