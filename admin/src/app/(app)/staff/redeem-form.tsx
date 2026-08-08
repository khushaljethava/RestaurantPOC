'use client';

import { createClient } from '@/lib/supabase/client';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Btn, Card, Field } from '@/components/ui';

/**
 * Called by: staff/page.tsx (import RedeemInviteForm).
 * Exists: admin/src/app/(app)/staff/redeem-form.tsx (Glob confirmed).
 * Data: RPC redeem_stall_invite { p_code: string } — no local files.
 * User: "Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself."
 */
/** Mirror of mobile/lib/invite_code.dart — accepts `ABCD-1234` or `abcd1234`. */
export function normalizeInviteCode(raw: string): string {
  const c = raw.trim().toUpperCase().replace(/\s+/g, '').replace(/[–—−]/g, '-');
  if (c.includes('-') || c.length < 5) return c;
  return `${c.slice(0, 4)}-${c.slice(4)}`;
}

export function RedeemInviteForm() {
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const router = useRouter();

  async function redeem() {
    setError(null);
    setOk(null);
    const supabase = createClient();
    const { error: err } = await supabase.rpc('redeem_stall_invite', {
      p_code: normalizeInviteCode(code),
    });
    if (err) {
      setError(err.message);
      return;
    }
    setOk('Joined stall');
    setCode('');
    router.refresh();
  }

  return (
    <Card>
      <h2 className="mb-3 text-base font-medium text-on-surface">Redeem an invite code</h2>
      <div className="flex gap-2">
        <Field
          value={code}
          onChange={(e) => setCode(e.target.value)}
          placeholder="ABCD-1234"
          className="flex-1 font-mono"
        />
        <Btn type="button" onClick={redeem} disabled={!code.trim()}>
          Join
        </Btn>
      </div>
      {error && <p className="mt-2 text-sm text-error">{error}</p>}
      {ok && <p className="mt-2 text-sm text-success">{ok}</p>}
    </Card>
  );
}
