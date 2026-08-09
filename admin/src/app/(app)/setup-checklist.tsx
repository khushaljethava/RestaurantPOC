'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Card, Btn } from '@/components/ui';

export type ChecklistFlags = {
  hasCategory: boolean;
  hasFiveItems: boolean;
  hasUpi: boolean;
  hasStaffOrInvite: boolean;
};

/**
 * Dismissible setup progress for new stalls.
 * Callers: (app)/page.tsx. Persistence: localStorage only.
 * User: Implement the plan as specified, it is attached for your reference.
 */
export function SetupChecklist({ flags }: { flags: ChecklistFlags }) {
  const [ready, setReady] = useState(false);
  const [dismissed, setDismissed] = useState(false);

  const webDone =
    flags.hasCategory && flags.hasFiveItems && flags.hasUpi && flags.hasStaffOrInvite;

  useEffect(() => {
    if (webDone) {
      setDismissed(true);
      setReady(true);
      return;
    }
    setDismissed(localStorage.getItem('setup_checklist_dismissed') === '1');
    setReady(true);
  }, [webDone]);

  if (!ready || dismissed || webDone) return null;

  const steps = [
    { ok: flags.hasCategory, label: 'Add a category', href: '/menu' },
    { ok: flags.hasFiveItems, label: 'Add 5 menu items', href: '/menu' },
    { ok: flags.hasUpi, label: 'Set UPI VPA', href: '/settings' },
    { ok: flags.hasStaffOrInvite, label: 'Invite one staff member', href: '/staff' },
  ];
  const required = steps.filter((s) => !('optional' in s && s.optional));  const doneCount = required.filter((s) => s.ok).length;
  const pct = Math.round((doneCount / required.length) * 100);

  function dismiss() {
    localStorage.setItem('setup_checklist_dismissed', '1');
    setDismissed(true);
  }

  return (
    <Card className="mb-6 space-y-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <p className="text-base font-semibold text-on-surface">Setup checklist</p>
          <p className="text-sm text-on-surface-variant">{pct}% complete</p>
        </div>
        <Btn type="button" variant="text" className="h-9 px-2 text-xs" onClick={dismiss}>
          Dismiss
        </Btn>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-surface-container-highest">
        <div className="h-full bg-surface-tint" style={{ width: `${pct}%` }} />
      </div>
      <ul className="space-y-2 text-sm">
        {steps.map((s) => (
          <li key={s.label} className="flex items-center justify-between gap-2">
            <span className={s.ok ? 'text-on-surface-variant line-through' : 'text-on-surface'}>
              {s.ok ? '✓ ' : '○ '}
              {s.label}
            </span>
            {!s.ok && s.href && (
              <Link href={s.href} className="text-surface-tint hover:underline">
                Go
              </Link>
            )}
          </li>
        ))}
      </ul>
    </Card>
  );
}
