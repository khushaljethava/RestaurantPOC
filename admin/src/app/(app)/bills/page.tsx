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

export default async function BillsPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const { timezone, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = stallDayBounds(timezone, dayStartMinutes);

  const { data: bills } = await supabase
    .from('bill')
    .select(
      'id, token_no, status, total, discount, table_label, created_at, collected_by_stall_id'
    )
    .eq('collected_by_stall_id', active.stall_id)
    .gte('created_at', from)
    .lt('created_at', to)
    .order('created_at', { ascending: false })
    .limit(100);

  return (
    <div className="space-y-6">
      <PageTitle subtitle="Today’s bills collected by this stall">Bills</PageTitle>
      <TableWrap>
        <table className="w-full">
          <thead>
            <tr>
              <Th>Time</Th>
              <Th>Token</Th>
              <Th>Status</Th>
              <Th>Table</Th>
              <Th className="text-right">Gross</Th>
              <Th className="text-right">Net</Th>
              <Th />
            </tr>
          </thead>
          <tbody>
            {(bills ?? []).map((b) => (
              <Tr key={b.id}>
                <Td className="text-xs">{new Date(b.created_at).toLocaleTimeString()}</Td>
                <Td className="tabular-nums">#{b.token_no ?? '—'}</Td>
                <Td>{b.status}</Td>
                <Td>{b.table_label ?? '—'}</Td>
                <Td className="text-right tabular-nums">{formatInr(Number(b.total))}</Td>
                <Td className="text-right tabular-nums">
                  {formatInr(Number(b.total) - Number(b.discount))}
                </Td>
                <Td className="text-right">
                  <Link href={`/bills/${b.id}`} className="text-surface-tint hover:underline">
                    Open
                  </Link>
                </Td>
              </Tr>
            ))}
          </tbody>
        </table>
      </TableWrap>
      {(bills ?? []).length === 0 && (
        <Card className="p-0">
          <EmptyState icon="receipt_long" title="No bills today">
            Paid and open bills from mobile appear here.
          </EmptyState>
        </Card>
      )}
    </div>
  );
}
