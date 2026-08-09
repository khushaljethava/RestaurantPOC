'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Icon } from './icon';
import { StallSwitcher } from '@/app/(app)/stall-switcher';

/**
 * `stallOnly` entries need an active stall and are hidden from an operator who
 * owns none. `/courts` is the operator's own surface — distinct from `/group`,
 * which is the tenant view of the one court the active stall belongs to.
 */
const NAV = [
  { href: '/', label: 'Dashboard', icon: 'dashboard', stallOnly: true },
  { href: '/live', label: 'Live', icon: 'live_tv', stallOnly: true },
  { href: '/orders', label: 'Orders', icon: 'receipt_long', stallOnly: true },
  { href: '/bills', label: 'Bills', icon: 'receipt', stallOnly: true },
  { href: '/settlement', label: 'Settlement', icon: 'payments', stallOnly: true },
  { href: '/shifts', label: 'Shifts', icon: 'schedule', stallOnly: true },
  { href: '/payments/verify', label: 'UPI verify', icon: 'verified', stallOnly: true },
  { href: '/exceptions', label: 'Exceptions', icon: 'warning', stallOnly: true },
  { href: '/reports', label: 'Reports', icon: 'assessment', stallOnly: true },
  { href: '/menu', label: 'Menu', icon: 'restaurant_menu', stallOnly: true },
  { href: '/staff', label: 'Staff', icon: 'badge', stallOnly: true },
  { href: '/group', label: 'Court', icon: 'storefront', stallOnly: true },
  { href: '/audit', label: 'Audit', icon: 'history', manageOnly: true, stallOnly: true },
  { href: '/courts', label: 'Food Courts', icon: 'apartment', operatorOnly: true },
  { href: '/settings', label: 'Settings', icon: 'settings', manageOnly: true, stallOnly: true },
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
  hasStalls,
  isOperator,
}: {
  stalls: { id: string; name: string }[];
  activeId: string;
  activeName: string;
  role: string;
  isOwner: boolean;
  hasStalls: boolean;
  isOperator: boolean;
}) {
  const pathname = usePathname();
  const roleLabel =
    role === 'operator'
      ? 'Court Operator'
      : role === 'owner'
        ? 'Admin Access'
        : role === 'manager'
          ? 'Manager'
          : 'Staff';

  return (
    <aside className="fixed inset-y-0 left-0 z-20 flex w-sidebar-width flex-col border-r border-border bg-surface">
      <div className="flex items-center gap-2.5 px-5 py-5">
        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-surface-tint text-on-primary">
          <Icon name="storefront" filled />
        </span>
        <p className="text-[15px] font-semibold leading-tight tracking-tight text-on-surface">
          StreetStall
          <span className="block text-[11px] font-medium text-on-surface-variant">POS Admin</span>
        </p>
      </div>

      {hasStalls && (
        <div className="px-3 pb-3">
          <StallSwitcher stalls={stalls} activeId={activeId} />
        </div>
      )}

      <nav className="flex-1 overflow-y-auto px-3 py-2">
        <ul className="space-y-1">
          {NAV.filter((item) => {
            if ('ownerOnly' in item && item.ownerOnly && !isOwner) return false;
            if ('manageOnly' in item && item.manageOnly && !(isOwner || role === 'manager')) return false;
            if ('stallOnly' in item && item.stallOnly && !hasStalls) return false;
            if ('operatorOnly' in item && item.operatorOnly && !isOperator) return false;
            return true;
          }).map(
            (item) => {
              const active =
                item.href === '/'
                  ? pathname === '/'
                  : pathname === item.href || pathname.startsWith(`${item.href}/`);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    className={`flex h-11 items-center gap-3 rounded-lg px-3 text-sm transition-colors ${
                      active
                        ? 'bg-primary-container font-semibold text-on-primary-container'
                        : 'font-medium text-on-surface-variant hover:bg-surface-container-high hover:text-on-surface'
                    }`}
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

      <div className="mt-auto border-t border-border p-3">
        <div className="flex w-full items-center gap-3 rounded-lg bg-surface-container-low p-2.5">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary-container text-xs font-bold text-on-primary-container">
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
