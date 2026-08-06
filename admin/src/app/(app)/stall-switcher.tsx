'use client';

import { useRouter } from 'next/navigation';

/** Called by shell-sidebar.tsx. Existing file updated for Stitch styling. */
export function StallSwitcher({
  stalls,
  activeId,
}: {
  stalls: { id: string; name: string }[];
  activeId: string;
}) {
  const router = useRouter();
  if (stalls.length <= 1) return null;

  return (
    <div>
      <label className="mb-1.5 block px-1 text-[11px] font-semibold uppercase tracking-wide text-on-surface-variant">
        Active stall
      </label>
      <select
        className="h-11 w-full rounded-lg border border-border bg-surface-container-low px-2.5 text-sm font-medium text-on-surface transition-colors hover:border-outline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-surface-tint"
        value={activeId}
        onChange={(e) => {
          document.cookie = `active_stall_id=${e.target.value}; path=/; max-age=31536000; SameSite=Lax`;
          router.refresh();
        }}
      >
        {stalls.map((s) => (
          <option key={s.id} value={s.id}>
            {s.name}
          </option>
        ))}
      </select>
    </div>
  );
}
