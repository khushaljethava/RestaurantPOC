import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { parseRange } from '@/lib/dates';
import { activeStallDayContext, resolveActiveStall } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { ReportCsv } from '../reports/report-csv';
import { DateRangeForm } from '../reports/date-range-form';
import {
  markSettlement,
  confirmSettlement,
  disputeSettlement,
} from './actions';
import {
  Btn,
  Card,
  EmptyState,
  Field,
  PageTitle,
  SectionTitle,
  StatusPill,
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
  const { timezone: tz, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = parseRange(tz, sp.from, sp.to, dayStartMinutes);
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  const active = memberships?.length ? await resolveActiveStall(memberships) : null;
  const canManage =
    active?.role === 'owner' || active?.role === 'manager';
  const myStall = active?.stall_id;

  const { data: pairs } = await supabase.rpc('settlement_pairs', {
    p_from: from,
    p_to: to,
  });
  const list = (pairs as Pair[]) ?? [];

  const { data: stalls } = await supabase.from('stall').select('id, name');
  const nameOf = (id: string) => stalls?.find((s) => s.id === id)?.name ?? id.slice(0, 8);

  const { data: ledger } = myStall
    ? await supabase
        .from('settlement_record')
        .select(
          'id, from_stall_id, to_stall_id, amount, day, method, marked_by, marked_at, confirmed_by, confirmed_at, disputed, dispute_note'
        )
        .or(`from_stall_id.eq.${myStall},to_stall_id.eq.${myStall}`)
        .gte('day', from.slice(0, 10))
        .lte('day', new Date(new Date(to).getTime() - 86400000).toISOString().slice(0, 10))
        .order('day', { ascending: false })
        .limit(100)
    : { data: [] as never[] };

  const drillA = sp.a;
  const drillB = sp.b;
  let drillOrders: {
    id: string;
    token_no: number | null;
    stall_id: string;
    bill_id: string | null;
    status: string;
  }[] = [];

  if (drillA && drillB) {
    const { data: bills } = await supabase
      .from('bill')
      .select('id, collected_by_stall_id, status, paid_at')
      .eq('status', 'paid')
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
  const settleDay = toDateDefault;
  const twoDaysAgo = new Date(Date.now() - 2 * 86400000).toISOString().slice(0, 10);

  // Matrix ids
  const ids = Array.from(new Set(list.flatMap((p) => [p.stall_a, p.stall_b]))).sort();
  function cell(row: string, col: string): number {
    if (row === col) return 0;
    const ab = list.find((p) => p.stall_a === row && p.stall_b === col);
    if (ab) return Number(ab.a_owes_b);
    const ba = list.find((p) => p.stall_a === col && p.stall_b === row);
    if (ba) return -Number(ba.a_owes_b);
    return 0;
  }

  // Reconciliation: sum of confirmed settlements for day vs computed nets (abs)
  const computedNet = list.reduce((s, p) => s + Math.abs(Number(p.a_owes_b)), 0) / 2;
  const confirmedSum = (ledger ?? [])
    .filter((r) => r.confirmed_at && r.day === settleDay)
    .reduce((s, r) => s + Number(r.amount), 0);
  const drift =
    confirmedSum > 0 && Math.abs(confirmedSum - computedNet) > 0.05
      ? confirmedSum - computedNet
      : null;

  const aging = (ledger ?? []).filter(
    (r) => !r.confirmed_at && !r.disputed && r.day <= twoDaysAgo
  );

  return (
    <div className="space-y-8">
      <PageTitle
        subtitle="Cross-stall balances, ledger, and confirmations"
        trailing={
          <div className="flex flex-wrap gap-2">
            <Link
              href={`/settlement/print?from=${from.slice(0, 10)}&to=${toDateDefault}`}
              className="inline-flex h-9 items-center rounded-lg border border-border px-3 text-xs font-medium text-primary hover:bg-surface-container-high"
            >
              Print / PDF
            </Link>
            <ReportCsv
              filename={`settlement-${from.slice(0, 10)}-${toDateDefault}.csv`}
              headers={['payer', 'payee', 'amount']}
              rows={list.map((p) => {
                const payer = Number(p.a_owes_b) > 0 ? p.stall_a : p.stall_b;
                const payee = Number(p.a_owes_b) > 0 ? p.stall_b : p.stall_a;
                return [nameOf(payer), nameOf(payee), Math.abs(Number(p.a_owes_b)).toFixed(2)];
              })}
            />
          </div>
        }
      >
        Settlement
      </PageTitle>

      <DateRangeForm fromYmd={from.slice(0, 10)} toYmd={toDateDefault} />

      {aging.length > 0 && (
        <Card className="border-warning text-sm">
          {aging.length} settlement{aging.length === 1 ? '' : 's'} pending confirmation for &gt;2
          days — follow up with the counterparty.
        </Card>
      )}

      {drift != null && (
        <Card className="text-sm text-error">
          Reconciliation warning: confirmed marks for {settleDay} ({formatInr(confirmedSum)})
          differ from computed net ({formatInr(computedNet)}) by {formatInr(drift)}.
        </Card>
      )}

      {ids.length > 0 && (
        <section className="space-y-3">
          <SectionTitle>Matrix (row owes column)</SectionTitle>
          <TableWrap>
            <table className="w-full">
              <thead>
                <tr>
                  <Th />
                  {ids.map((id) => (
                    <Th key={id} className="text-right">
                      {nameOf(id)}
                    </Th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {ids.map((row) => (
                  <Tr key={row}>
                    <Td className="font-medium">{nameOf(row)}</Td>
                    {ids.map((col) => {
                      const v = cell(row, col);
                      return (
                        <Td
                          key={col}
                          className={`text-right tabular-nums ${v !== 0 ? '' : 'text-on-surface-variant'}`}
                        >
                          {row === col ? '—' : (
                            <Link
                              href={`/settlement?from=${from.slice(0, 10)}&to=${toDateDefault}&a=${row}&b=${col}`}
                              className="text-surface-tint hover:underline"
                            >
                              {formatInr(v)}
                            </Link>
                          )}
                        </Td>
                      );
                    })}
                  </Tr>
                ))}
              </tbody>
            </table>
          </TableWrap>
        </section>
      )}

      <section className="space-y-3">
        <SectionTitle>Computed balances</SectionTitle>
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
              {list.map((p) => {
                const payer = Number(p.a_owes_b) > 0 ? p.stall_a : p.stall_b;
                const payee = Number(p.a_owes_b) > 0 ? p.stall_b : p.stall_a;
                const amt = Math.abs(Number(p.a_owes_b));
                const iPay = myStall === payer;
                return (
                  <Tr key={`${p.stall_a}-${p.stall_b}`}>
                    <Td>{nameOf(payer)}</Td>
                    <Td>{nameOf(payee)}</Td>
                    <Td className="text-right tabular-nums">{formatInr(amt)}</Td>
                    <Td className="text-right">
                      <div className="flex flex-wrap items-center justify-end gap-2">
                        <Link
                          className="text-sm font-medium text-surface-tint hover:underline"
                          href={`/settlement?from=${from.slice(0, 10)}&to=${toDateDefault}&a=${p.stall_a}&b=${p.stall_b}`}
                        >
                          Details
                        </Link>
                        {canManage && iPay && (
                          <form action={markSettlement} className="inline">
                            <input type="hidden" name="from_stall" value={payer} />
                            <input type="hidden" name="to_stall" value={payee} />
                            <input type="hidden" name="day" value={settleDay} />
                            <input type="hidden" name="amount" value={String(amt)} />
                            <input type="hidden" name="method" value="cash" />
                            <Btn type="submit" variant="outlined" className="h-8 px-2 text-xs">
                              Mark settled
                            </Btn>
                          </form>
                        )}
                      </div>
                    </Td>
                  </Tr>
                );
              })}
              {list.length === 0 && (
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
      </section>

      <section className="space-y-3">
        <SectionTitle>Ledger</SectionTitle>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Day</Th>
                <Th>From → To</Th>
                <Th className="text-right">Amount</Th>
                <Th>Status</Th>
                <Th />
              </tr>
            </thead>
            <tbody>
              {(ledger ?? []).map((r) => {
                const status = r.disputed
                  ? 'disputed'
                  : r.confirmed_at
                    ? 'confirmed'
                    : 'pending';
                const agingRow = !r.confirmed_at && !r.disputed && r.day <= twoDaysAgo;
                const iReceive = myStall === r.to_stall_id;
                const iParty =
                  myStall === r.from_stall_id || myStall === r.to_stall_id;
                return (
                  <Tr key={r.id}>
                    <Td className={agingRow ? 'text-warning' : ''}>{r.day}</Td>
                    <Td className="text-sm">
                      {nameOf(r.from_stall_id)} → {nameOf(r.to_stall_id)}
                      <span className="ml-1 text-xs text-on-surface-variant">· {r.method}</span>
                    </Td>
                    <Td className="text-right tabular-nums">{formatInr(Number(r.amount))}</Td>
                    <Td>
                      <StatusPill
                        tone={
                          status === 'confirmed'
                            ? 'success'
                            : status === 'disputed'
                              ? 'error'
                              : 'warning'
                        }
                      >
                        {status}
                        {agingRow ? ' · aging' : ''}
                      </StatusPill>
                      {r.dispute_note && (
                        <p className="mt-1 text-xs text-on-surface-variant">{r.dispute_note}</p>
                      )}
                    </Td>
                    <Td className="text-right">
                      {canManage && iParty && status === 'pending' && (
                        <div className="flex flex-col items-end gap-2">
                          {iReceive && (
                            <form
                              action={async () => {
                                'use server';
                                await confirmSettlement(r.id);
                              }}
                            >
                              <Btn type="submit" className="h-8 px-2 text-xs">
                                Confirm
                              </Btn>
                            </form>
                          )}
                          <form action={disputeSettlement} className="flex gap-1">
                            <input type="hidden" name="id" value={r.id} />
                            <Field
                              name="note"
                              placeholder="Dispute reason"
                              required
                              className="h-8 w-36 text-xs"
                            />
                            <Btn type="submit" variant="danger" className="h-8 px-2 text-xs">
                              Dispute
                            </Btn>
                          </form>
                        </div>
                      )}
                    </Td>
                  </Tr>
                );
              })}
            </tbody>
          </table>
        </TableWrap>
        {(ledger ?? []).length === 0 && (
          <p className="text-sm text-on-surface-variant">No settlement marks in this range.</p>
        )}
      </section>

      {drillA && drillB && (
        <div>
          <SectionTitle>
            Orders behind {nameOf(drillA)} ↔ {nameOf(drillB)}
          </SectionTitle>
          <div className="space-y-2">
            {drillOrders.map((o) => (
              <Card key={o.id} className="flex justify-between py-3 text-sm">
                <Link href={`/orders/${o.id}`} className="text-surface-tint hover:underline">
                  Token #{o.token_no} · {nameOf(o.stall_id)} · {o.status}
                </Link>
                {o.bill_id && (
                  <Link href={`/bills/${o.bill_id}`} className="text-xs text-on-surface-variant hover:underline">
                    bill
                  </Link>
                )}
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
