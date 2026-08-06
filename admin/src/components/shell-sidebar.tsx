'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Icon } from './icon';
import { StallSwitcher } from '@/app/(app)/stall-switcher';

const NAV = [
  { href: '/', label: 'Dashboard', icon: 'dashboard' },
  { href: '/live', label: 'Live', icon: 'live_tv' },
  { href: '/settlement', label: 'Settlement', icon: 'payments' },
  { href: '/reports', label: 'Reports', icon: 'assessment' },
  { href: '/menu', label: 'Menu', icon: 'restaurant_menu' },
  { href: '/staff', label: 'Staff', icon: 'badge' },
  { href: '/group', label: 'Food Court', icon: 'storefront' },
  { href: '/settings', label: 'Settings', icon: 'settings', ownerOnly: true },
] as const;

function initials(name: string) {
  const parts = name.trim().split(/\s+/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return name.slice(0, 2).toUpperCase() || 'ST';
}

export function ShellSidebar({
  stalls,
  activeId,
  activeName,
  role,
  isOwner,
}: {
  stalls: { id: string; name: string }[];
  activeId: string;
  activeName: string;
  role: string;
  isOwner: boolean;
}) {
  const pathname = usePathname();
  const roleLabel =
    role === 'owner' ? 'Admin Access' : role === 'manager' ? 'Manager' : 'Staff';

  return (
    <aside className="fixed inset-y-0 left-0 z-20 flex w-sidebar-width flex-col border-r border-outline-variant bg-surface">
      <div className="px-4 py-6">
        <p className="text-2xl font-bold tracking-tight text-primary">StreetStall POS</p>
        <p className="mt-1 text-[11px] font-medium text-on-surface-variant">{activeName}</p>
      </div>

      <div className="px-4 pb-4">
        <button
          type="button"
          title="Orders are taken in the mobile app"
          className="flex h-11 w-full cursor-default items-center justify-center gap-2 rounded-lg bg-surface-tint text-sm font-medium text-on-primary opacity-90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-surface-tint"
        >
          <Icon name="add" filled />
          New Order
        </button>
        <p className="mt-1.5 text-center text-[11px] text-on-surface-variant">
          Use the mobile app to take orders
        </p>
      </div>

      <div className="px-4 pb-2">
        <StallSwitcher stalls={stalls} activeId={activeId} />
      </div>

      <nav className="flex-1 overflow-y-auto py-2">
        <ul>
          {NAV.filter((item) => !('ownerOnly' in item && item.ownerOnly) || isOwner).map(
            (item) => {
              const active =
                item.href === '/'
                  ? pathname === '/'
                  : pathname === item.href || pathname.startsWith(`${item.href}/`);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    className={
                      active
                        ? 'flex items-center gap-3 border-l-4 border-primary bg-primary-container/10 py-3 pl-3 font-bold text-primary'
                        : 'flex items-center gap-3 py-3 pl-4 font-normal text-on-surface-variant hover:bg-surface-container-highest'
                    }
                    aria-current={active ? 'page' : undefined}
                  >
                    <Icon name={item.icon} filled={active} />
                    <span>{item.label}</span>
                  </Link>
                </li>
              );
            }
          )}
        </ul>
      </nav>

      <div className="mt-auto border-t border-outline-variant p-4">
        <div className="flex w-full items-center gap-3 rounded-lg p-2">
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary-container text-xs font-bold text-primary">
            {initials(activeName)}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium text-on-surface">{activeName}</p>
            <p className="truncate text-[11px] text-on-surface-variant">{roleLabel}</p>
          </div>
        </div>
      </div>
    </aside>
  );
}
