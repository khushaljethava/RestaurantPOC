'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Btn, Field } from '@/components/ui';
import { Icon } from '@/components/icon';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [mode, setMode] = useState<'in' | 'up'>('in');
  const router = useRouter();

  async function handle(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error } =
      mode === 'in'
        ? await supabase.auth.signInWithPassword({ email, password })
        : await supabase.auth.signUp({ email, password });
    setBusy(false);
    if (error) return setError(error.message);
    router.push('/');
    router.refresh();
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background p-6">
      <div className="w-full max-w-[400px] rounded-md bg-surface p-8">
        <div className="mb-6 flex flex-col items-center text-center">
          <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-primary-container">
            <Icon name="storefront" filled className="text-[28px] text-primary" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-primary">StreetStall POS</h1>
          <p className="mt-1 text-sm text-on-surface-variant">
            {mode === 'in' ? 'Sign in to your stall admin' : 'Create your account'}
          </p>
        </div>

        <form onSubmit={handle} className="space-y-3">
          <Field
            type="email"
            placeholder="Email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <Field
            type="password"
            placeholder="Password"
            autoComplete={mode === 'in' ? 'current-password' : 'new-password'}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          {error && <p className="text-sm text-error">{error}</p>}
          <Btn type="submit" disabled={busy || !email || !password} className="w-full">
            {mode === 'in' ? 'Sign in' : 'Create account'}
          </Btn>
          <button
            type="button"
            className="w-full py-2 text-sm font-medium text-primary hover:underline"
            onClick={() => {
              setMode(mode === 'in' ? 'up' : 'in');
              setError(null);
            }}
          >
            {mode === 'in' ? 'Create an account' : 'Already have an account? Sign in'}
          </button>
        </form>
      </div>
    </main>
  );
}
