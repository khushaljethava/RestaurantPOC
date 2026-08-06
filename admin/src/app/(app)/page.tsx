import { createClient } from '@/lib/supabase/server';
import { dayEnd, dayStart } from '@/lib/dates';
import { activeStallTimezone } from '@/lib/active-stall';
import { PageTitle, Stat } from '@/components/ui';

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
      <PageTitle subtitle="Today at a glance">Dashboard</PageTitle>
      <div className="grid gap-4 sm:grid-cols-3">
        <Stat
          label="Today's sales"
          value={`₹${todayRevenue.toFixed(2)}`}
          icon="trending_up"
          tone="success"
        />
        <Stat
          label="Open bills"
          value={openCount}
          icon="receipt_long"
          tone="warning"
          href="/live"
          hrefLabel="Live board"
        />
        <Stat
          label={`Net owed ${netOwed >= 0 ? 'to peers' : 'to you'}`}
          value={`₹${Math.abs(netOwed).toFixed(2)}`}
          icon="account_balance_wallet"
          tone="error"
          href="/settlement"
          hrefLabel="Go to settlement"
        />
      </div>
      <p className="mt-6 text-sm text-on-surface-variant">
        Stalls visible: {stalls?.length ?? 0}
      </p>
    </div>
  );
}
