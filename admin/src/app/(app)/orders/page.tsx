import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall, activeStallDayContext } from '@/lib/active-stall';
import { stallDayBounds } from '@/lib/dates';
import { formatInr } from '@/lib/money';
import {
  Card,
  EmptyState,
  PageTitle,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

export default async function OrdersPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const { timezone, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = stallDayBounds(timezone, dayStartMinutes);

  const { data: orders } = await supabase
    .from('orders')
    .select(
      'id, token_no, status, stall_id, recorded_by_stall_id, table_label, created_at, bill_id'
    )
    .or(`stall_id.eq.${active.stall_id},recorded_by_stall_id.eq.${active.stall_id}`)
    .gte('created_at', from)
    .lt('created_at', to)
    .order('created_at', { ascending: false })
    .limit(100);

  const { data: items } = (orders ?? []).length
    ? await supabase
        .from('order_item')
        .select('order_id, name, qty, unit_price, voided_at')
        .in(
          'order_id',
          (orders ?? []).map((o) => o.id)
        )
    : { data: [] as never[] };

  const totalFor = (orderId: string) =>
    (items ?? [])
      .filter((i) => i.order_id === orderId && !i.voided_at)
      .reduce((s, i) => s + Number(i.qty) * Number(i.unit_price), 0);

  return (
    <div className="space-y-6">
      <PageTitle subtitle="Today’s orders for the active stall (own + recorded-for)">
        Orders
      </PageTitle>
      <TableWrap>
        <table className="w-full">
          <thead>
            <tr>
              <Th>Time</Th>
              <Th>Token</Th>
              <Th>Status</Th>
              <Th>Table</Th>
              <Th className="text-right">Amount</Th>
              <Th />
            </tr>
          </thead>
          <tbody>
            {(orders ?? []).map((o) => (
              <Tr key={o.id}>
                <Td className="text-xs">{new Date(o.created_at).toLocaleTimeString()}</Td>
                <Td className="tabular-nums">#{o.token_no ?? '—'}</Td>
                <Td>{o.status}</Td>
                <Td>{o.table_label ?? '—'}</Td>
                <Td className="text-right tabular-nums">{formatInr(totalFor(o.id))}</Td>
                <Td className="text-right">
                  <Link href={`/orders/${o.id}`} className="text-surface-tint hover:underline">
                    Open
                  </Link>
                </Td>
              </Tr>
            ))}
          </tbody>
        </table>
      </TableWrap>
      {(orders ?? []).length === 0 && (
        <Card className="p-0">
          <EmptyState icon="receipt_long" title="No orders today">
            Orders placed on mobile show up here.
          </EmptyState>
        </Card>
      )}
    </div>
  );
}
