'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Btn, Field } from '@/components/ui';

/**
 * Two kinds of account start here and they are not the same business:
 * a stall owner runs a shop, a court operator runs the building and owns no
 * stall. Without the operator path, `(app)/layout.tsx` would bounce an
 * operator back here forever, since it redirects on empty staff_membership.
 */
type Mode = 'stall' | 'court';

export default function OnboardingPage() {
  const [mode, setMode] = useState<Mode | null>(null);
  const [name, setName] = useState('');
  const [timezone, setTimezone] = useState('Asia/Kolkata');
  const [currency, setCurrency] = useState('INR');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const router = useRouter();

  async function submit() {
    setBusy(true);
    setError(null);
    const supabase = createClient();
    if (mode === 'court') {
      const { error } = await supabase.rpc('create_court', { p_name: name });
      setBusy(false);
      if (error) return setError(error.message);
      router.push('/courts');
      router.refresh();
      return;
    }
    const { data: stallId, error } = await supabase.rpc('register_stall', { p_name: name });
    if (error) {
      setBusy(false);
      return setError(error.message);
    }
    if (stallId) {
      const { error: updErr } = await supabase
        .from('stall')
        .update({ timezone, currency })
        .eq('id', stallId);
      if (updErr) {
        setBusy(false);
        return setError(updErr.message);
      }
    }
    setBusy(false);
    router.push('/');
    router.refresh();
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background p-6">
      <div className="w-full max-w-md rounded-md border border-border bg-surface p-8 shadow-card-hover">
        {mode === null ? (
          <>
            <h1 className="text-2xl font-semibold tracking-tight text-on-surface">
              What are you setting up?
            </h1>
            <p className="mt-2 text-sm text-on-surface-variant">
              You can add the other one later.
            </p>
            <div className="mt-6 space-y-3">
              <Btn type="button" onClick={() => setMode('stall')} className="w-full">
                I run a stall
              </Btn>
              <Btn
                type="button"
                variant="outlined"
                onClick={() => setMode('court')}
                className="w-full"
              >
                I run a food court
              </Btn>
            </div>
          </>
        ) : (
          <>
            <h1 className="text-2xl font-semibold tracking-tight text-on-surface">
              {mode === 'court' ? 'Name your food court' : 'Name your stall'}
            </h1>
            <p className="mt-2 text-sm text-on-surface-variant">
              {mode === 'court'
                ? 'You can invite stalls to join it once it exists.'
                : "This creates your account's first stall. You can join a food court later, or run standalone."}
            </p>
            <div className="mt-6 space-y-3">
              <Field
                placeholder={mode === 'court' ? 'Food court name' : 'Stall name'}
                value={name}
                onChange={(e) => setName(e.target.value)}
                autoFocus
              />
              {mode === 'stall' && (
                <>
                  <Field
                    placeholder="Timezone"
                    value={timezone}
                    onChange={(e) => setTimezone(e.target.value)}
                  />
                  <Field
                    placeholder="Currency"
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value)}
                  />
                </>
              )}
              {error && <p className="text-sm text-error">{error}</p>}
              <Btn
                type="button"
                onClick={submit}
                disabled={!name.trim() || busy}
                className="w-full"
              >
                {mode === 'court' ? 'Create food court' : 'Create stall'}
              </Btn>
              <Btn
                type="button"
                variant="text"
                onClick={() => {
                  setMode(null);
                  setError(null);
                }}
                className="w-full"
              >
                Back
              </Btn>
            </div>
          </>
        )}
      </div>
    </main>
  );
}
