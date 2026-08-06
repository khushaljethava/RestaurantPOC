import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { parseRange } from '@/lib/dates';
import { activeStallTimezone } from '@/lib/active-stall';
import { ReportCsv } from '../reports/report-csv';
import {
  Btn,
  Card,
  EmptyState,
  Field,
  Label,
  PageTitle,
  SectionTitle,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

type Pair = { stall_a: string; stall_b: string; a_owes_b: number };

export default async function SettlementPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string; a?: string; b?: string }>;
}) {
  const sp = await searchParams;
  const tz = await activeStallTimezone();
  const { from, to } = parseRange(tz, sp.from, sp.to);
  const supabase = await createClient();

  const { data: pairs } = await supabase.rpc('settlement_pairs', {
    p_from: from,
    p_to: to,
  });

  const { data: stalls } = await supabase.from('stall').select('id, name');
  const nameOf = (id: string) => stalls?.find((s) => s.id === id)?.name ?? id.slice(0, 8);

  const drillA = sp.a;
  const drillB = sp.b;
  let drillOrders: {
    id: string;
    token_no: number;
    stall_id: string;
    bill_id: string | null;
    status: string;
  }[] = [];

  if (drillA && drillB) {
    const { data: bills } = await supabase
      .from('bill')
      .select('id, collected_by_stall_id, status, total, paid_at')
      .in('status', ['paid'])
      .gte('paid_at', from)
      .lt('paid_at', to)
      .or(`collected_by_stall_id.eq.${drillA},collected_by_stall_id.eq.${drillB}`);
    const billIds = (bills ?? []).map((b) => b.id);
    if (billIds.length) {
      const { data: orders } = await supabase
        .from('orders')
        .select('id, token_no, stall_id, bill_id, status')
        .in('bill_id', billIds)
        .in('stall_id', [drillA, drillB]);
      drillOrders = (orders ?? []) as typeof drillOrders;
    }
  }

  const toDateDefault = new Date(new Date(to).getTime() - 86400000).toISOString().slice(0, 10);

  return (
    <div className="space-y-6">
      <PageTitle
        trailing={
          <ReportCsv
            filename={`settlement-${from.slice(0, 10)}-${toDateDefault}.csv`}
            headers={['payer', 'payee', 'amount']}
            rows={((pairs as Pair[]) ?? []).map((p) => {
              const payer = Number(p.a_owes_b) > 0 ? p.stall_a : p.stall_b;
              const payee = Number(p.a_owes_b) > 0 ? p.stall_b : p.stall_a;
              const amt = Math.abs(Number(p.a_owes_b));
              return [nameOf(payer), nameOf(payee), amt.toFixed(2)];
            })}
          />
        }
      >
        Settlement
      </PageTitle>

      <Card>
        <form className="flex flex-wrap items-end gap-3">
          <div>
            <Label className="mb-1.5">From</Label>
            <Field type="date" name="from" defaultValue={from.slice(0, 10)} className="w-auto" />
          </div>
          <div>
            <Label className="mb-1.5">To</Label>
            <Field type="date" name="to" defaultValue={toDateDefault} className="w-auto" />
          </div>
          <Btn type="submit" variant="primary">
            Apply
          </Btn>
        </form>
      </Card>

      <TableWrap>
        <table className="w-full">
          <thead>
            <tr>
              <Th>Who pays</Th>
              <Th>Who receives</Th>
              <Th className="text-right">Amount</Th>
              <Th />
            </tr>
          </thead>
          <tbody>
            {((pairs as Pair[]) ?? []).map((p) => {
              const payer = Number(p.a_owes_b) > 0 ? p.stall_a : p.stall_b;
              const payee = Number(p.a_owes_b) > 0 ? p.stall_b : p.stall_a;
              const amt = Math.abs(Number(p.a_owes_b));
              return (
                <Tr key={`${p.stall_a}-${p.stall_b}`}>
                  <Td>{nameOf(payer)}</Td>
                  <Td>{nameOf(payee)}</Td>
                  <Td className="text-right tabular-nums">₹{amt.toFixed(2)}</Td>
                  <Td className="text-right">
                    <Link
                      className="text-sm font-medium text-surface-tint hover:underline"
                      href={`/settlement?from=${from.slice(0, 10)}&to=${toDateDefault}&a=${p.stall_a}&b=${p.stall_b}`}
                    >
                      Details
                    </Link>
                  </Td>
                </Tr>
              );
            })}
            {(!pairs || (pairs as Pair[]).length === 0) && (
              <tr>
                <td colSpan={4} className="border-t border-border">
                  <EmptyState icon="account_balance_wallet" title="Nothing to settle">
                    No cross-stall balances in this range.
                  </EmptyState>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </TableWrap>

      {drillA && drillB && (
        <div>
          <SectionTitle>
            Orders behind {nameOf(drillA)} ↔ {nameOf(drillB)}
          </SectionTitle>
          <div className="space-y-2">
            {drillOrders.map((o) => (
              <Card key={o.id} className="flex justify-between py-3 text-sm">
                <span>
                  Token #{o.token_no} · {nameOf(o.stall_id)} · {o.status}
                </span>
                <span className="font-mono text-xs text-on-surface-variant">
                  {o.bill_id?.slice(0, 8)}
                </span>
              </Card>
            ))}
            {drillOrders.length === 0 && (
              <Card className="p-0">
                <EmptyState title="No orders found" />
              </Card>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
