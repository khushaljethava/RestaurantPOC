import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { stallDayBounds, previousPeriod, pctChange, formatPctDelta } from '@/lib/dates';
import { activeStallDayContext, resolveActiveStall } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { Card, PageTitle, SectionTitle, Stat } from '@/components/ui';
import { SetupChecklist } from './setup-checklist';

/**
 * Dashboard: today metrics, vs-yesterday, needs-attention, payment mix.
 * Callers: App Router /. User: go next (W3).
 */
export default async function DashboardPage() {
  const supabase = await createClient();
  const { timezone: tz, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = stallDayBounds(tz, dayStartMinutes);
  const prev = previousPeriod(from, to);

  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  const hasStalls = (memberships?.length ?? 0) > 0;
  const active = hasStalls ? await resolveActiveStall(memberships!) : null;
  const stallId = active?.stall_id;

  const [
    { data: stalls },
    { data: sales },
    { data: prevSales },
    openBillsRes,
    { data: pairs },
    { data: byMode },
    { data: paidToday },
  ] = await Promise.all([
    supabase.from('stall').select('id, name, group_id, upi_vpa'),
    supabase.rpc('sales_by_stall', { p_from: from, p_to: to }),
    supabase.rpc('sales_by_stall', { p_from: prev.from, p_to: prev.to }),
    supabase.from('bill').select('id', { count: 'exact', head: true }).eq('status', 'open'),
    supabase.rpc('settlement_pairs', { p_from: from, p_to: to }),
    supabase.rpc('sales_by_payment_mode', { p_from: from, p_to: to }),
    stallId
      ? supabase
          .from('bill')
          .select('id, paid_at, total, discount')
          .eq('collected_by_stall_id', stallId)
          .not('paid_at', 'is', null)
          .gte('paid_at', from)
          .lt('paid_at', to)
      : Promise.resolve({ data: [] as { id: string; paid_at: string; total: number; discount: number }[] }),
  ]);

  const sumRev = (rows: { revenue: number }[] | null | undefined) =>
    (rows ?? []).reduce((s, r) => s + Number(r.revenue), 0);
  const sumOrders = (rows: { order_count: number }[] | null | undefined) =>
    (rows ?? []).reduce((s, r) => s + Number(r.order_count), 0);

  const todayRevenue = sumRev(sales);
  const ydayRevenue = sumRev(prevSales);
  const todayOrders = sumOrders(sales);
  const ydayOrders = sumOrders(prevSales);
  const avgBill = todayOrders ? todayRevenue / todayOrders : 0;
  const ydayAvg = ydayOrders ? ydayRevenue / ydayOrders : 0;
  const openCount = openBillsRes.count ?? 0;

  const myIds = new Set((memberships ?? []).map((m) => m.stall_id));
  let netOwed = 0;
  for (const p of pairs ?? []) {
    const amt = Number(p.a_owes_b);
    if (myIds.has(p.stall_a)) netOwed += amt;
    if (myIds.has(p.stall_b)) netOwed -= amt;
  }

  // Hourly buckets in stall timezone (display hour 0–23)
  const hourBuckets = Array.from({ length: 24 }, () => 0);
  for (const b of paidToday ?? []) {
    if (!b.paid_at) continue;
    const hour = Number(
      new Intl.DateTimeFormat('en-GB', {
        timeZone: tz,
        hour: '2-digit',
        hour12: false,
      }).format(new Date(b.paid_at))
    );
    hourBuckets[hour] += Number(b.total) - Number(b.discount);
  }
  const maxHour = Math.max(1, ...hourBuckets);

  let checklist = {
    hasCategory: false,
    hasFiveItems: false,
    hasUpi: false,
    hasStaffOrInvite: false,
  };

  let attention = { upi: 0, upiCount: 0, openShifts: 0, unavailable: 0 };

  if (stallId) {
    const stall = (stalls ?? []).find((s) => s.id === stallId);
    const [
      { count: catCount },
      { count: itemCount },
      { count: memberCount },
      { count: inviteCount },
      { data: billIds },
      { count: openShifts },
      { count: unavailable },
    ] = await Promise.all([
      supabase.from('category').select('id', { count: 'exact', head: true }).eq('stall_id', stallId),
      supabase
        .from('menu_item')
        .select('id', { count: 'exact', head: true })
        .eq('stall_id', stallId)
        .is('parent_id', null),
      supabase
        .from('staff_membership')
        .select('id', { count: 'exact', head: true })
        .eq('stall_id', stallId),
      supabase
        .from('stall_invite')
        .select('code', { count: 'exact', head: true })
        .eq('stall_id', stallId)
        .is('revoked_at', null),
      supabase.from('bill').select('id').eq('collected_by_stall_id', stallId),
      supabase
        .from('shifts')
        .select('id', { count: 'exact', head: true })
        .eq('stall_id', stallId)
        .is('closed_at', null),
      supabase
        .from('menu_item')
        .select('id', { count: 'exact', head: true })
        .eq('stall_id', stallId)
        .eq('is_available', false),
    ]);
    checklist = {
      hasCategory: (catCount ?? 0) >= 1,
      hasFiveItems: (itemCount ?? 0) >= 5,
      hasUpi: Boolean(stall?.upi_vpa),
      hasStaffOrInvite: (memberCount ?? 0) > 1 || (inviteCount ?? 0) >= 1,
    };
    const ids = (billIds ?? []).map((b) => b.id);
    if (ids.length) {
      const { data: unverified } = await supabase
        .from('payment')
        .select('amount')
        .eq('method', 'upi')
        .eq('upi_verified', false)
        .in('bill_id', ids);
      attention.upi = (unverified ?? []).reduce((s, p) => s + Number(p.amount), 0);
      attention.upiCount = unverified?.length ?? 0;
    }
    attention.openShifts = openShifts ?? 0;
    attention.unavailable = unavailable ?? 0;
  }

  const modeTotal = (byMode ?? []).reduce(
    (s: number, r: { amount: number }) => s + Number(r.amount),
    0
  );

  return (
    <div className="space-y-8">
      <PageTitle subtitle="Today at a glance">Dashboard</PageTitle>
      {stallId && <SetupChecklist flags={checklist} />}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Stat
          label="Today's sales"
          value={formatInr(todayRevenue)}
          icon="trending_up"
          tone="success"
          delta={formatPctDelta(pctChange(todayRevenue, ydayRevenue))}
          href="/reports/sales"
          hrefLabel="Sales report"
        />
        <Stat
          label="Orders"
          value={todayOrders}
          icon="receipt_long"
          delta={formatPctDelta(pctChange(todayOrders, ydayOrders))}
          href="/orders"
          hrefLabel="Orders"
        />
        <Stat
          label="Avg bill"
          value={formatInr(avgBill)}
          icon="payments"
          delta={formatPctDelta(pctChange(avgBill, ydayAvg))}
        />
        <Stat
          label="Open bills"
          value={openCount}
          icon="pending"
          tone="warning"
          href="/live"
          hrefLabel="Live board"
        />
      </div>

      {stallId && (
        <Card className="space-y-3">
          <SectionTitle className="mb-0">Needs attention</SectionTitle>
          <ul className="grid gap-2 sm:grid-cols-2 text-sm">
            <li>
              <Link href="/payments/verify" className="text-surface-tint hover:underline">
                Unverified UPI {formatInr(attention.upi)} ({attention.upiCount})
              </Link>
            </li>
            <li>
              <Link href="/shifts" className="text-surface-tint hover:underline">
                Open shifts {attention.openShifts}
              </Link>
            </li>
            <li>
              <Link href="/settlement" className="text-surface-tint hover:underline">
                Net owed {formatInr(Math.abs(netOwed))} {netOwed >= 0 ? 'to peers' : 'to you'}
              </Link>
            </li>
            <li>
              <Link href="/exceptions" className="text-surface-tint hover:underline">
                Unavailable items {attention.unavailable}
              </Link>
            </li>
          </ul>
        </Card>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="space-y-3">
          <SectionTitle className="mb-0">Payment mix today</SectionTitle>
          {(byMode ?? []).length === 0 && (
            <p className="text-sm text-on-surface-variant">No payments yet.</p>
          )}
          {(byMode ?? []).map((r: { method: string; amount: number }) => {
            const share = modeTotal > 0 ? (Number(r.amount) / modeTotal) * 100 : 0;
            return (
              <div key={r.method} className="flex items-center gap-2 text-sm">
                <span className="w-14 capitalize">{r.method}</span>
                <div className="h-2 flex-1 overflow-hidden rounded-full bg-surface-container-highest">
                  <div className="h-full bg-surface-tint" style={{ width: `${share}%` }} />
                </div>
                <span className="w-20 text-right tabular-nums text-xs">
                  {formatInr(Number(r.amount))}
                </span>
              </div>
            );
          })}
          <Link href="/reports/sales" className="text-xs text-surface-tint hover:underline">
            Full sales report →
          </Link>
        </Card>

        <Card className="space-y-3">
          <SectionTitle className="mb-0">Hourly sales today</SectionTitle>
          <div className="flex h-28 items-end gap-0.5">
            {hourBuckets.map((v, h) => (
              <div
                key={h}
                title={`${h}:00 · ${formatInr(v)}`}
                className="flex-1 rounded-t bg-surface-tint/80"
                style={{ height: `${Math.max(v > 0 ? 8 : 2, (v / maxHour) * 100)}%` }}
              />
            ))}
          </div>
          <p className="text-[10px] text-on-surface-variant">0–23h · {tz}</p>
        </Card>
      </div>
    </div>
  );
}
