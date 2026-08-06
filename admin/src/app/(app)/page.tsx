import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { dayEnd, dayStart } from '@/lib/dates';
import { activeStallTimezone } from '@/lib/active-stall';
import { Card, PageTitle } from '@/components/ui';
import { Icon } from '@/components/icon';

export default async function DashboardPage() {
  const supabase = await createClient();
  const tz = await activeStallTimezone();
  const from = dayStart(tz);
  const to = dayEnd(tz);

  const [{ data: stalls }, { data: sales }, openBillsRes, { data: pairs }] =
    await Promise.all([
      supabase.from('stall').select('id, name, group_id'),
      supabase.rpc('sales_by_stall', { p_from: from, p_to: to }),
      supabase.from('bill').select('id', { count: 'exact', head: true }).eq('status', 'open'),
      supabase.rpc('settlement_pairs', { p_from: from, p_to: to }),
    ]);

  const todayRevenue = (sales ?? []).reduce(
    (s: number, r: { revenue: number }) => s + Number(r.revenue),
    0
  );
  const openCount = openBillsRes.count ?? 0;

  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id');
  const myIds = new Set((memberships ?? []).map((m) => m.stall_id));

  let netOwed = 0;
  for (const p of pairs ?? []) {
    const amt = Number(p.a_owes_b);
    if (myIds.has(p.stall_a)) netOwed += amt;
    if (myIds.has(p.stall_b)) netOwed -= amt;
  }

  return (
    <div>
      <PageTitle>Dashboard</PageTitle>
      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="relative">
          <Icon name="trending_up" className="absolute right-4 top-4 text-success" />
          <div className="text-[11px] font-medium text-on-surface-variant">Today&apos;s sales</div>
          <div className="mt-2 text-[40px] font-medium leading-none tabular-nums text-on-surface">
            ₹{todayRevenue.toFixed(2)}
          </div>
        </Card>
        <Card className="relative">
          <Icon name="receipt_long" className="absolute right-4 top-4 text-warning" />
          <div className="text-[11px] font-medium text-on-surface-variant">Open bills</div>
          <div className="mt-2 text-[40px] font-medium leading-none tabular-nums text-on-surface">
            {openCount}
          </div>
          <Link
            href="/live"
            className="mt-3 inline-block text-sm font-medium text-surface-tint hover:underline"
          >
            Live board →
          </Link>
        </Card>
        <Card className="relative">
          <Icon name="account_balance_wallet" className="absolute right-4 top-4 text-error" />
          <div className="text-[11px] font-medium text-on-surface-variant">
            Net owed {netOwed >= 0 ? 'to peers' : 'to you'}
          </div>
          <div className="mt-2 text-[40px] font-medium leading-none tabular-nums text-on-surface">
            ₹{Math.abs(netOwed).toFixed(2)}
          </div>
          <Link
            href="/settlement"
            className="mt-3 inline-block text-sm font-medium text-surface-tint hover:underline"
          >
            Go to settlement →
          </Link>
        </Card>
      </div>
      <p className="mt-8 text-center text-sm text-on-surface-variant">
        Stalls visible: {stalls?.length ?? 0}
      </p>
    </div>
  );
}
