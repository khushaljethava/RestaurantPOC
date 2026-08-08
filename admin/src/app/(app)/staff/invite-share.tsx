'use client';

import { useState } from 'react';
import { inviteUrl } from '@/lib/invite-link';
import { Btn } from '@/components/ui';

/**
 * Called by: staff/page.tsx, inside each active invite Card.
 * Client-only because copying and sharing need browser APIs; the sibling
 * Revoke form stays a server action.
 */
export function InviteShare({ code }: { code: string }) {
  const [copied, setCopied] = useState(false);
  const url = inviteUrl(code);

  async function copy() {
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard is blocked on insecure origins and by some permission
      // policies. Prompt rather than failing silently.
      window.prompt('Copy this invite link', url);
    }
  }

  async function share() {
    if (!navigator.share) return copy();
    try {
      await navigator.share({ title: 'Join my stall on Stall Manager', url });
    } catch {
      // User dismissed the share sheet. Not an error.
    }
  }

  return (
    <div className="flex gap-1">
      <Btn type="button" variant="text" onClick={copy} className="h-9 px-2 text-xs">
        {copied ? 'Copied' : 'Copy link'}
      </Btn>
      <Btn type="button" variant="text" onClick={share} className="h-9 px-2 text-xs">
        Share
      </Btn>
    </div>
  );
}
