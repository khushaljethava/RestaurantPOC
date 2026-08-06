'use client';

import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Icon } from './icon';

export function SignOutButton() {
  const router = useRouter();

  async function signOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  return (
    <button
      type="button"
      onClick={signOut}
      title="Sign out"
      aria-label="Sign out"
      className="flex h-10 w-10 items-center justify-center rounded-full text-on-surface-variant hover:bg-surface-container-highest focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-surface-tint"
    >
      <Icon name="account_circle" className="text-[28px]" />
    </button>
  );
}
