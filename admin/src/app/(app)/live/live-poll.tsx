'use client';

import { createClient } from '@/lib/supabase/client';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

/** Realtime refresh for live board. Imported by live/page.tsx. */
export function LivePoll() {
  const router = useRouter();
  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel('live-board')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'orders' },
        () => router.refresh()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'bill' },
        () => router.refresh()
      )
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [router]);
  return (
    <span className="inline-flex items-center gap-2 rounded-full bg-primary-container/40 px-3 py-1 text-[11px] font-medium text-primary">
      <span className="relative flex h-2 w-2">
        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-success opacity-75" />
        <span className="relative inline-flex h-2 w-2 rounded-full bg-success" />
      </span>
      Live
    </span>
  );
}
