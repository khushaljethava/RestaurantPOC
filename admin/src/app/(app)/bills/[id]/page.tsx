import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import {
  Card,
  PageTitle,
  SectionTitle,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

export default async function BillDetailPage({
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

  const { data: bill } = await supabase
    .from('bill')
    .select(
      'id, token_no, status, total, discount, discount_reason, table_label, created_at, collected_by_stall_id, shift_id, rounding_amount'
    )
    .eq('id', id)
    .maybeSingle();
  if (!bill) notFound();
  if (bill.collected_by_stall_id !== active.stall_id) notFound();

  const [{ data: orders }, { data: payments }, { data: refunds }, { data: audit }] =
    await Promise.all([
      supabase
        .from('orders')
        .select('id, token_no, status, stall_id')
        .eq('bill_id', id),
      supabase
        .from('payment')
        .select('id, method, amount, upi_ref, upi_verified, created_at')
        .eq('bill_id', id)
        .order('created_at'),
      supabase
        .from('refund_line')
        .select('id, amount, reason, created_at')
        .eq('bill_id', id)
        .order('created_at'),
      supabase
        .from('audit_log')
        .select('id, action, actor_id, reason, created_at')
        .eq('entity_id', id)
        .order('created_at', { ascending: false })
        .limit(50),
    ]);

  const orderIds = (orders ?? []).map((o) => o.id);
  const { data: lines } = orderIds.length
    ? await supabase
        .from('order_item')
        .select('id, order_id, name, qty, unit_price, voided_at, void_reason')
        .in('order_id', orderIds)
    : { data: [] as never[] };

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageTitle
        subtitle={
          <Link href="/bills" className="text-surface-tint hover:underline">
            ← Bills
          </Link>
        }
      >
        Bill #{bill.token_no ?? bill.id.slice(0, 8)}
      </PageTitle>

      <Card className="space-y-1 text-sm">
        <p>
          Status <strong>{bill.status}</strong>
          {bill.table_label ? ` · Table ${bill.table_label}` : ''}
        </p>
        <p>
          Gross {formatInr(Number(bill.total))} · Discount {formatInr(Number(bill.discount))}
          {bill.discount_reason ? ` (${bill.discount_reason})` : ''} · Net{' '}
          {formatInr(Number(bill.total) - Number(bill.discount) + Number(bill.rounding_amount ?? 0))}
        </p>
        <p className="text-on-surface-variant">
          {new Date(bill.created_at).toLocaleString()}
          {bill.shift_id ? (
            <>
              {' · '}
              <Link href={`/shifts/${bill.shift_id}`} className="text-surface-tint hover:underline">
                Shift
              </Link>
            </>
          ) : null}
        </p>
        <p className="text-xs text-on-surface-variant">
          Paid bills are append-only — corrections use refunds, not edits.
        </p>
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
              {(lines ?? []).map((i) => (
                <Tr key={i.id}>
                  <Td className={i.voided_at ? 'line-through text-on-surface-variant' : ''}>
                    {i.name}
                    {i.void_reason ? ` · void: ${i.void_reason}` : ''}
                  </Td>
                  <Td className="text-right tabular-nums">{Number(i.qty)}</Td>
                  <Td className="text-right tabular-nums">{formatInr(Number(i.unit_price))}</Td>
                </Tr>
              ))}
            </tbody>
          </table>
        </TableWrap>
        {(lines ?? []).length === 0 && (
          <p className="mt-2 text-sm text-on-surface-variant">No lines.</p>
        )}
      </section>

      <section>
        <SectionTitle>Payments</SectionTitle>
        <ul className="space-y-2 text-sm">
          {(payments ?? []).map((p) => (
            <li
              key={p.id}
              className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border px-3 py-2"
            >
              <span>
                {p.method.toUpperCase()} · {formatInr(Number(p.amount))}
                {p.method === 'upi' && (
                  <span className="ml-2 text-xs text-on-surface-variant">
                    {p.upi_verified ? 'verified' : 'unverified'}
                    {p.upi_ref ? ` · ${p.upi_ref}` : ''}
                  </span>
                )}
              </span>
              <span className="text-xs text-on-surface-variant">
                {new Date(p.created_at).toLocaleString()}
              </span>
            </li>
          ))}
          {(payments ?? []).length === 0 && (
            <li className="text-on-surface-variant">No payments yet.</li>
          )}
        </ul>
      </section>

      <section>
        <SectionTitle>Refunds</SectionTitle>
        <ul className="space-y-2 text-sm">
          {(refunds ?? []).map((r) => (
            <li key={r.id} className="rounded-lg border border-border px-3 py-2">
              {formatInr(Number(r.amount))}
              {r.reason ? ` · ${r.reason}` : ''}
              <span className="ml-2 text-xs text-on-surface-variant">
                {new Date(r.created_at).toLocaleString()}
              </span>
            </li>
          ))}
          {(refunds ?? []).length === 0 && (
            <li className="text-on-surface-variant">No refunds.</li>
          )}
        </ul>
      </section>

      <section>
        <SectionTitle>Orders on bill</SectionTitle>
        <ul className="space-y-1 text-sm">
          {(orders ?? []).map((o) => (
            <li key={o.id}>
              <Link href={`/orders/${o.id}`} className="text-surface-tint hover:underline">
                Order #{o.token_no ?? o.id.slice(0, 8)} · {o.status}
              </Link>
            </li>
          ))}
        </ul>
      </section>

      <section>
        <SectionTitle>Audit timeline</SectionTitle>
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
            <li className="text-on-surface-variant">No audit rows.</li>
          )}
        </ul>
      </section>
    </div>
  );
}
