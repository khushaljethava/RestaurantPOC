'use client';

import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Field } from '@/components/ui';

/**
 * Client filter over already-rendered menu item cards (data-search attribute).
 * Callers: menu/page.tsx Items section.
 * User: Implement the plan as specified, it is attached for your reference.
 */
export function MenuSearch({ children }: { children: ReactNode }) {
  const [q, setQ] = useState('');
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const needle = q.trim().toLowerCase();
    root.querySelectorAll<HTMLElement>('[data-search]').forEach((el) => {
      const hay = (el.dataset.search ?? '').toLowerCase();
      el.hidden = needle !== '' && !hay.includes(needle);
    });
  }, [q]);

  return (
    <div className="space-y-3">
      <Field
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder="Search name or code"
        aria-label="Search menu items"
        className="max-w-sm"
      />
      <div ref={rootRef} className="space-y-3">
        {children}
      </div>
    </div>
  );
}
