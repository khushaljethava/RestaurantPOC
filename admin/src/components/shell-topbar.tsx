'use client';

import { Icon } from './icon';
import { SignOutButton } from './sign-out-button';

export function ShellTopbar() {
  return (
    <header className="sticky top-0 z-10 flex h-16 items-center gap-4 border-b border-outline-variant bg-background/95 px-page-padding backdrop-blur-sm">
      <div className="relative max-w-xl flex-1">
        <Icon
          name="search"
          className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant"
        />
        <input
          type="search"
          placeholder="Search orders, items…"
          disabled
          title="Search coming soon"
          className="h-11 w-full cursor-not-allowed rounded-full border border-border bg-surface-container-lowest pl-10 pr-4 text-sm text-on-surface-variant opacity-70"
        />
      </div>
      <div className="ml-auto flex items-center gap-1">
        <button
          type="button"
          disabled
          title="Notifications coming soon"
          aria-label="Notifications"
          className="flex h-10 w-10 cursor-not-allowed items-center justify-center rounded-full text-on-surface-variant opacity-70"
        >
          <Icon name="notifications" />
        </button>
        <SignOutButton />
      </div>
    </header>
  );
}
