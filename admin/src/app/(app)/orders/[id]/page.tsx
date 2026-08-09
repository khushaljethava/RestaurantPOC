import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { Card, PageTitle, SectionTitle, TableWrap, Td, Th, Tr } from '@/components/ui';

export default async function OrderDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);

  const { data: order } = await supabase
    .from('orders')
    .select(
      'id, token_no, status, stall_id, recorded_by_stall_id, table_label, created_at, bill_id, notes'
    )
    .eq('id', id)
    .maybeSingle();
  if (!order) notFound();
  if (
    order.stall_id !== active.stall_id &&
    order.recorded_by_stall_id !== active.stall_id
  ) {
    notFound();
  }

  const [{ data: items }, { data: audit }] = await Promise.all([
    supabase
      .from('order_item')
      .select('id, name, qty, unit_price, voided_at, void_reason')
      .eq('order_id', id)
      .order('created_at'),
    supabase
      .from('audit_log')
      .select('id, action, actor_id, reason, created_at, payload')
      .eq('entity_id', id)
      .order('created_at', { ascending: false })
      .limit(50),
  ]);

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageTitle
        subtitle={
          <Link href="/orders" className="text-surface-tint hover:underline">
            ← Orders
          </Link>
        }
      >
        Order #{order.token_no ?? order.id.slice(0, 8)}
      </PageTitle>
      <Card className="space-y-1 text-sm">
        <p>
          Status <strong>{order.status}</strong>
          {order.table_label ? ` · Table ${order.table_label}` : ''}
        </p>
        <p className="text-on-surface-variant">
          {new Date(order.created_at).toLocaleString()}
        </p>
        {order.bill_id && (
          <p>
            Bill{' '}
            <Link href={`/bills/${order.bill_id}`} className="text-surface-tint hover:underline">
              open
            </Link>
          </p>
        )}
        {order.notes && <p>Notes: {order.notes}</p>}
      </Card>

      <section>
        <SectionTitle>Lines</SectionTitle>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Item</Th>
                <Th className="text-right">Qty</Th>
                <Th className="text-right">Price</Th>
              </tr>
            </thead>
            <tbody>
              {(items ?? []).map((i) => (
                <Tr key={i.id}>
                  <Td className={i.voided_at ? 'line-through text-on-surface-variant' : ''}>
                    {i.name}
                    {i.void_reason ? ` (${i.void_reason})` : ''}
                  </Td>
                  <Td className="text-right tabular-nums">{Number(i.qty)}</Td>
                  <Td className="text-right tabular-nums">{formatInr(Number(i.unit_price))}</Td>
                </Tr>
              ))}
            </tbody>
          </table>
        </TableWrap>
      </section>

      <section>
        <SectionTitle>Audit</SectionTitle>
        <ul className="space-y-2 text-sm">
          {(audit ?? []).map((a) => (
            <li key={a.id} className="rounded-lg border border-border px-3 py-2">
              <p className="font-medium">{a.action}</p>
              <p className="text-xs text-on-surface-variant">
                {new Date(a.created_at).toLocaleString()}
                {a.reason ? ` · ${a.reason}` : ''}
              </p>
            </li>
          ))}
          {(audit ?? []).length === 0 && (
            <li className="text-on-surface-variant">No audit rows for this order.</li>
          )}
        </ul>
      </section>
    </div>
  );
}
