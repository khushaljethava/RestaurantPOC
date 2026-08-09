import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall, activeStallDayContext } from '@/lib/active-stall';
import { stallDayBounds } from '@/lib/dates';
import { formatInr } from '@/lib/money';
import { Card, PageTitle, SectionTitle } from '@/components/ui';

export default async function ExceptionsPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const canManage = active.role === 'owner' || active.role === 'manager';
  if (!canManage) {
    return <p className="text-on-surface-variant">Owner or manager only.</p>;
  }

  const { timezone, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = stallDayBounds(timezone, dayStartMinutes);

  const { data: bills } = await supabase
    .from('bill')
    .select('id')
    .eq('collected_by_stall_id', active.stall_id);
  const billIds = (bills ?? []).map((b) => b.id);

  const { data: todayOrders } = await supabase
    .from('orders')
    .select('id')
    .eq('stall_id', active.stall_id)
    .gte('created_at', from)
    .lt('created_at', to);
  const orderIds = (todayOrders ?? []).map((o) => o.id);

  const [{ data: unverified }, { data: voids }, { data: refunds }, { data: openShifts }] =
    await Promise.all([
      billIds.length
        ? supabase
            .from('payment')
            .select('id, amount')
            .eq('method', 'upi')
            .eq('upi_verified', false)
            .in('bill_id', billIds)
        : Promise.resolve({ data: [] as { id: string; amount: number }[] }),
      orderIds.length
        ? supabase
            .from('order_item')
            .select('id, name, void_reason, voided_at, order_id')
            .not('voided_at', 'is', null)
            .in('order_id', orderIds)
            .limit(30)
        : Promise.resolve({ data: [] as never[] }),
      billIds.length
        ? supabase
            .from('refund_line')
            .select('id, amount, reason, created_at, bill_id')
            .in('bill_id', billIds)
            .gte('created_at', from)
            .lt('created_at', to)
            .limit(30)
        : Promise.resolve({ data: [] as never[] }),
      supabase
        .from('shifts')
        .select('id, opened_at')
        .eq('stall_id', active.stall_id)
        .is('closed_at', null),
    ]);

  const upiTotal = (unverified ?? []).reduce((s, p) => s + Number(p.amount), 0);

  return (
    <div className="space-y-6">
      <PageTitle subtitle="Money leaks and open loops for today">Exceptions</PageTitle>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <p className="text-xs text-on-surface-variant">Unverified UPI</p>
          <p className="text-xl font-semibold tabular-nums">{formatInr(upiTotal)}</p>
          <Link href="/payments/verify" className="text-xs text-surface-tint hover:underline">
            Verify queue →
          </Link>
        </Card>
        <Card>
          <p className="text-xs text-on-surface-variant">Open shifts</p>
          <p className="text-xl font-semibold tabular-nums">{(openShifts ?? []).length}</p>
          <Link href="/shifts" className="text-xs text-surface-tint hover:underline">
            Shifts →
          </Link>
        </Card>
        <Card>
          <p className="text-xs text-on-surface-variant">Voids today</p>
          <p className="text-xl font-semibold tabular-nums">{(voids ?? []).length}</p>
        </Card>
        <Card>
          <p className="text-xs text-on-surface-variant">Refunds today</p>
          <p className="text-xl font-semibold tabular-nums">{(refunds ?? []).length}</p>
        </Card>
      </div>

      <section>
        <SectionTitle>Recent voids</SectionTitle>
        <ul className="space-y-1 text-sm">
          {(voids ?? []).map((v) => (
            <li key={v.id} className="rounded-lg border border-border px-3 py-2">
              {v.name}
              {v.void_reason ? ` · ${v.void_reason}` : ''}
              <Link
                href={`/orders/${v.order_id}`}
                className="ml-2 text-surface-tint hover:underline"
              >
                order
              </Link>
            </li>
          ))}
          {(voids ?? []).length === 0 && (
            <li className="text-on-surface-variant">None today.</li>
          )}
        </ul>
      </section>

      <section>
        <SectionTitle>Recent refunds</SectionTitle>
        <ul className="space-y-1 text-sm">
          {(refunds ?? []).map((r) => (
            <li key={r.id} className="rounded-lg border border-border px-3 py-2">
              {formatInr(Number(r.amount))}
              {r.reason ? ` · ${r.reason}` : ''}
              <Link href={`/bills/${r.bill_id}`} className="ml-2 text-surface-tint hover:underline">
                bill
              </Link>
            </li>
          ))}
          {(refunds ?? []).length === 0 && (
            <li className="text-on-surface-variant">None today.</li>
          )}
        </ul>
      </section>
    </div>
  );
}
