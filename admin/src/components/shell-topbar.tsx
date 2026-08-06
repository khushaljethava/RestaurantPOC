'use client';

import { Icon } from './icon';
import { SignOutButton } from './sign-out-button';

export function ShellTopbar() {
  return (
    /* ponytail: dropped the disabled search box and dead notifications bell —
       fake affordances read as broken. Add back when they actually work. */
    <header className="sticky top-0 z-10 flex h-14 items-center gap-4 border-b border-border bg-background/80 px-page-padding backdrop-blur">
      <p className="flex items-center gap-1.5 text-xs text-on-surface-variant">
        <Icon name="smartphone" className="!text-base" />
        Orders are taken in the mobile app
      </p>
      <div className="ml-auto flex items-center gap-1">
        <SignOutButton />
      </div>
    </header>
  );
}
