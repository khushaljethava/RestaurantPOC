import Link from 'next/link';
import { Card, PageTitle } from '@/components/ui';

const LINKS = [
  { href: '/reports/sales', title: 'Sales', blurb: 'By stall, payment mode, and collector' },
  { href: '/reports/items', title: 'Items', blurb: 'Best / worst sellers by qty and revenue' },
  { href: '/reports/staff', title: 'Staff / collectors', blurb: 'Collections attributed to each stall' },
  { href: '/reports/cash', title: 'Cash reconciliation', blurb: 'Shift float, expected, declared, variance' },
  { href: '/reports/cross-stall', title: 'Cross-stall', blurb: 'Who owes whom in the food court' },
  { href: '/exceptions', title: 'Exceptions', blurb: 'Voids, refunds, unverified UPI' },
] as const;

export default function ReportsHubPage() {
  return (
    <div className="space-y-6">
      <PageTitle subtitle="Pick a report — all respect the date range on each page">
        Reports
      </PageTitle>
      <div className="grid gap-3 sm:grid-cols-2">
        {LINKS.map((l) => (
          <Link key={l.href} href={l.href} className="block">
            <Card className="transition-shadow hover:shadow-card-hover">
              <p className="text-base font-semibold text-on-surface">{l.title}</p>
              <p className="mt-1 text-sm text-on-surface-variant">{l.blurb}</p>
            </Card>
          </Link>
        ))}
      </div>
    </div>
  );
}
