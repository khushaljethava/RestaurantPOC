import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { verifyUpiPayment } from '../actions';
import {
  Btn,
  Card,
  EmptyState,
  PageTitle,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

export default async function UpiVerifyPage() {
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

  const { data: bills } = await supabase
    .from('bill')
    .select('id')
    .eq('collected_by_stall_id', active.stall_id);
  const billIds = (bills ?? []).map((b) => b.id);

  const { data: payments } = billIds.length
    ? await supabase
        .from('payment')
        .select('id, amount, upi_ref, created_at, bill_id, screenshot_path')
        .eq('method', 'upi')
        .eq('upi_verified', false)
        .in('bill_id', billIds)
        .order('created_at', { ascending: false })
        .limit(100)
    : { data: [] as never[] };

  const total = (payments ?? []).reduce((s, p) => s + Number(p.amount), 0);

  return (
    <div className="space-y-6">
      <PageTitle subtitle="Manually confirmed UPI awaiting bank check">
        Unverified UPI
      </PageTitle>
      <Card className="text-sm">
        Running total:{' '}
        <span className="font-semibold tabular-nums text-warning">{formatInr(total)}</span>
        {' · '}
        {(payments ?? []).length} payment{(payments ?? []).length === 1 ? '' : 's'}
      </Card>

      <TableWrap>
        <table className="w-full">
          <thead>
            <tr>
              <Th>When</Th>
              <Th className="text-right">Amount</Th>
              <Th>Ref</Th>
              <Th>Bill</Th>
              <Th />
            </tr>
          </thead>
          <tbody>
            {(payments ?? []).map((p) => (
              <Tr key={p.id}>
                <Td className="text-xs">{new Date(p.created_at).toLocaleString()}</Td>
                <Td className="text-right tabular-nums">{formatInr(Number(p.amount))}</Td>
                <Td className="font-mono text-xs">{p.upi_ref ?? '—'}</Td>
                <Td>
                  <Link href={`/bills/${p.bill_id}`} className="text-surface-tint hover:underline">
                    Open
                  </Link>
                </Td>
                <Td className="text-right">
                  <form
                    action={async () => {
                      'use server';
                      await verifyUpiPayment(p.id);
                    }}
                  >
                    <Btn type="submit" className="h-9 px-3 text-xs">
                      Mark verified
                    </Btn>
                  </form>
                </Td>
              </Tr>
            ))}
          </tbody>
        </table>
      </TableWrap>
      {(payments ?? []).length === 0 && (
        <Card className="p-0">
          <EmptyState icon="payments" title="All clear">
            No unverified UPI for this stall.
          </EmptyState>
        </Card>
      )}
    </div>
  );
}
