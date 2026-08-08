'use client';

import { useState } from 'react';
import { inviteAppUrl } from '@/lib/invite-link';

/**
 * Called by: join/page.tsx.
 * Client-only for the clipboard copy. No app-installed detection and no
 * auto-redirect timer — both are unreliable across Android browsers, and two
 * explicit buttons work everywhere including desktop.
 */
export function JoinActions({ code, apkUrl }: { code: string; apkUrl?: string }) {
  const [copied, setCopied] = useState(false);

  async function copyCode() {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      window.prompt('Copy this invite code', code);
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <a
        href={inviteAppUrl(code)}
        className="inline-flex h-11 items-center justify-center rounded-lg bg-surface-tint px-4 text-sm font-medium text-on-primary shadow-card transition-colors hover:bg-primary"
      >
        Open in Stall Manager
      </a>

      <button
        type="button"
        onClick={copyCode}
        className="inline-flex h-11 items-center justify-center rounded-lg border border-border bg-surface px-4 text-sm font-medium text-primary transition-colors hover:bg-surface-container-high"
      >
        {copied ? 'Code copied' : 'Copy code'}
      </button>

      {apkUrl && (
        <p className="text-center text-sm text-on-surface-variant">
          Don&apos;t have the app?{' '}
          <a href={apkUrl} className="font-medium text-primary underline">
            Download it
          </a>
          , then open this link again.
        </p>
      )}
    </div>
  );
}
