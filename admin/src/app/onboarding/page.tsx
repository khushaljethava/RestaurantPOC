'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Btn, Field } from '@/components/ui';

export default function OnboardingPage() {
  const [name, setName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const router = useRouter();

  async function register() {
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.rpc('register_stall', {
      p_name: name,
    });
    setBusy(false);
    if (error) return setError(error.message);
    router.push('/');
    router.refresh();
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background p-6">
      <div className="w-full max-w-md rounded-md bg-surface p-8">
        <h1 className="text-2xl font-normal tracking-tight text-on-surface">Name your stall</h1>
        <p className="mt-2 text-sm text-on-surface-variant">
          This creates your account&apos;s first stall. You can join a food court later, or run
          standalone.
        </p>
        <div className="mt-6 space-y-3">
          <Field
            placeholder="Stall name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
          />
          {error && <p className="text-sm text-error">{error}</p>}
          <Btn
            type="button"
            onClick={register}
            disabled={!name.trim() || busy}
            className="w-full"
          >
            Create stall
          </Btn>
        </div>
      </div>
    </main>
  );
}
