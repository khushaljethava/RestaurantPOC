import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { forceCloseShift } from '../actions';
import {
  Btn,
  Card,
  Field,
  Label,
  PageTitle,
  SectionTitle,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

export default async function ShiftDetailPage({
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
  const canManage = active.role === 'owner' || active.role === 'manager';

  const { data: shift } = await supabase
    .from('shifts')
    .select(
      'id, stall_id, staff_id, device_id, opened_at, closed_at, opening_float, declared_cash, expected_cash, variance, variance_reason, notes'
    )
    .eq('id', id)
    .eq('stall_id', active.stall_id)
    .maybeSingle();
  if (!shift) notFound();

  const [{ data: movements }, { data: bills }] = await Promise.all([
    supabase
      .from('cash_movements')
      .select('id, kind, amount, reason, created_at')
      .eq('shift_id', id)
      .order('created_at'),
    supabase
      .from('bill')
      .select('id, token_no, total, discount, status, created_at')
      .eq('shift_id', id)
      .order('created_at', { ascending: false })
      .limit(100),
  ]);

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <PageTitle
        subtitle={
          <Link href="/shifts" className="text-surface-tint hover:underline">
            ← Shifts
          </Link>
        }
      >
        Shift detail
      </PageTitle>

      <Card className="space-y-2 text-sm">
        <p>
          <span className="text-on-surface-variant">Staff</span>{' '}
          <span className="font-mono text-xs">{shift.staff_id}</span>
        </p>
        <p>
          <span className="text-on-surface-variant">Opened</span>{' '}
          {new Date(shift.opened_at).toLocaleString()}
        </p>
        <p>
          <span className="text-on-surface-variant">Closed</span>{' '}
          {shift.closed_at ? new Date(shift.closed_at).toLocaleString() : 'Still open'}
        </p>
        <p>
          Float {formatInr(Number(shift.opening_float))} · Expected{' '}
          {shift.expected_cash != null ? formatInr(Number(shift.expected_cash)) : '—'} · Declared{' '}
          {shift.declared_cash != null ? formatInr(Number(shift.declared_cash)) : '—'} · Variance{' '}
          <span className={shift.variance != null && Number(shift.variance) !== 0 ? 'text-error' : ''}>
            {shift.variance != null ? formatInr(Number(shift.variance)) : '—'}
          </span>
        </p>
        {shift.variance_reason && (
          <p className="text-on-surface-variant">Reason: {shift.variance_reason}</p>
        )}
        {shift.notes && <p className="text-on-surface-variant">Notes: {shift.notes}</p>}
      </Card>

      {!shift.closed_at && canManage && (
        <Card className="space-y-3">
          <SectionTitle className="mb-0">Force close</SectionTitle>
          <p className="text-xs text-on-surface-variant">
            Uses the same close_shift RPC as mobile. Enter declared cash count; add a reason if
            variance exceeds the stall threshold.
          </p>
          <form action={forceCloseShift} className="space-y-3">
            <input type="hidden" name="shift_id" value={shift.id} />
            <Label>
              Declared cash (₹)
              <Field
                name="declared_cash"
                type="number"
                step="0.01"
                min="0"
                required
                defaultValue={String(shift.expected_cash ?? shift.opening_float ?? 0)}
                className="mt-1"
              />
            </Label>
            <Label>
              Variance reason
              <Field name="variance_reason" placeholder="Optional unless over threshold" className="mt-1" />
            </Label>
            <Label>
              Notes
              <Field name="notes" placeholder="Force closed from admin" className="mt-1" />
            </Label>
            <Btn type="submit" variant="danger">
              Force close shift
            </Btn>
          </form>
        </Card>
      )}

      <section>
        <SectionTitle>Cash movements</SectionTitle>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>When</Th>
                <Th>Kind</Th>
                <Th className="text-right">Amount</Th>
                <Th>Reason</Th>
              </tr>
            </thead>
            <tbody>
              {(movements ?? []).map((m) => (
                <Tr key={m.id}>
                  <Td className="text-xs">{new Date(m.created_at).toLocaleString()}</Td>
                  <Td>{m.kind}</Td>
                  <Td className="text-right tabular-nums">{formatInr(Number(m.amount))}</Td>
                  <Td className="text-sm text-on-surface-variant">{m.reason}</Td>
                </Tr>
              ))}
            </tbody>
          </table>
        </TableWrap>
        {(movements ?? []).length === 0 && (
          <p className="mt-2 text-sm text-on-surface-variant">No cash movements.</p>
        )}
      </section>

      <section>
        <SectionTitle>Bills in shift</SectionTitle>
        <ul className="space-y-1 text-sm">
          {(bills ?? []).map((b) => (
            <li key={b.id} className="flex justify-between gap-2 rounded-lg border border-border px-3 py-2">
              <Link href={`/bills/${b.id}`} className="text-surface-tint hover:underline">
                #{b.token_no ?? b.id.slice(0, 8)} · {b.status}
              </Link>
              <span className="tabular-nums">
                {formatInr(Number(b.total) - Number(b.discount))}
              </span>
            </li>
          ))}
          {(bills ?? []).length === 0 && (
            <li className="text-on-surface-variant">No bills linked to this shift.</li>
          )}
        </ul>
      </section>
    </div>
  );
}
