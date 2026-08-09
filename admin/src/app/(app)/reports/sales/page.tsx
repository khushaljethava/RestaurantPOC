import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { parseRange, previousPeriod, pctChange, formatPctDelta } from '@/lib/dates';
import { activeStallDayContext } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { ReportCsv } from '../report-csv';
import { DateRangeForm } from '../date-range-form';
import {
  Card,
  PageTitle,
  SectionTitle,
  Stat,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

export default async function SalesReportPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const sp = await searchParams;
  const { timezone: tz, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = parseRange(tz, sp.from, sp.to, dayStartMinutes);
  const prev = previousPeriod(from, to);
  const supabase = await createClient();

  const [byStall, byMode, byCollector, stalls, prevStall] = await Promise.all([
    supabase.rpc('sales_by_stall', { p_from: from, p_to: to }),
    supabase.rpc('sales_by_payment_mode', { p_from: from, p_to: to }),
    supabase.rpc('sales_by_collector', { p_from: from, p_to: to }),
    supabase.from('stall').select('id, name'),
    supabase.rpc('sales_by_stall', { p_from: prev.from, p_to: prev.to }),
  ]);

  const nameOf = (id: string) => stalls.data?.find((s) => s.id === id)?.name ?? id.slice(0, 8);
  const rev = (rows: { revenue: number }[] | null) =>
    (rows ?? []).reduce((s, r) => s + Number(r.revenue), 0);
  const orders = (rows: { order_count: number }[] | null) =>
    (rows ?? []).reduce((s, r) => s + Number(r.order_count), 0);

  const curRev = rev(byStall.data);
  const prevRev = rev(prevStall.data);
  const curOrders = orders(byStall.data);
  const prevOrders = orders(prevStall.data);
  const avg = curOrders ? curRev / curOrders : 0;
  const prevAvg = prevOrders ? prevRev / prevOrders : 0;

  const toYmd = new Date(new Date(to).getTime() - 86400000).toISOString().slice(0, 10);

  return (
    <div className="space-y-8">
      <PageTitle
        subtitle={
          <Link href="/reports" className="text-surface-tint hover:underline">
            ← Reports
          </Link>
        }
      >
        Sales
      </PageTitle>
      <DateRangeForm fromYmd={from.slice(0, 10)} toYmd={toYmd} />

      <div className="grid gap-4 sm:grid-cols-3">
        <Stat
          label="Net sales"
          value={formatInr(curRev)}
          icon="trending_up"
          tone="success"
          delta={formatPctDelta(pctChange(curRev, prevRev))}
        />
        <Stat
          label="Orders"
          value={curOrders}
          icon="receipt_long"
          delta={formatPctDelta(pctChange(curOrders, prevOrders))}
        />
        <Stat
          label="Avg bill"
          value={formatInr(avg)}
          icon="payments"
          delta={formatPctDelta(pctChange(avg, prevAvg))}
        />
      </div>

      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">By stall</SectionTitle>
          <ReportCsv
            filename="sales-by-stall.csv"
            headers={['stall', 'revenue', 'orders']}
            rows={(byStall.data ?? []).map(
              (r: { stall_id: string; revenue: number; order_count: number }) => [
                nameOf(r.stall_id),
                r.revenue,
                r.order_count,
              ]
            )}
          />
        </div>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Stall</Th>
                <Th className="text-right">Revenue</Th>
                <Th className="text-right">Orders</Th>
              </tr>
            </thead>
            <tbody>
              {(byStall.data ?? []).map(
                (r: { stall_id: string; revenue: number; order_count: number }) => (
                  <Tr key={r.stall_id}>
                    <Td>{nameOf(r.stall_id)}</Td>
                    <Td className="text-right tabular-nums">{formatInr(Number(r.revenue))}</Td>
                    <Td className="text-right tabular-nums">{r.order_count}</Td>
                  </Tr>
                )
              )}
            </tbody>
          </table>
        </TableWrap>
      </section>

      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">Payment modes</SectionTitle>
          <ReportCsv
            filename="sales-by-payment.csv"
            headers={['method', 'amount', 'count']}
            rows={(byMode.data ?? []).map(
              (r: { method: string; amount: number; payment_count: number }) => [
                r.method,
                r.amount,
                r.payment_count,
              ]
            )}
          />
        </div>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Method</Th>
                <Th className="text-right">Amount</Th>
                <Th className="text-right">Share</Th>
                <Th className="text-right">Payments</Th>
              </tr>
            </thead>
            <tbody>
              {(byMode.data ?? []).map(
                (r: { method: string; amount: number; payment_count: number }) => {
                  const share = curRev > 0 ? (Number(r.amount) / curRev) * 100 : 0;
                  return (
                    <Tr key={r.method}>
                      <Td className="capitalize">{r.method}</Td>
                      <Td className="text-right tabular-nums">{formatInr(Number(r.amount))}</Td>
                      <Td className="text-right tabular-nums">{share.toFixed(0)}%</Td>
                      <Td className="text-right tabular-nums">{r.payment_count}</Td>
                    </Tr>
                  );
                }
              )}
            </tbody>
          </table>
        </TableWrap>
        <Card className="space-y-2">
          <p className="text-xs font-medium text-on-surface-variant">Mix (relative bar)</p>
          {(byMode.data ?? []).map(
            (r: { method: string; amount: number }) => {
              const share = curRev > 0 ? (Number(r.amount) / curRev) * 100 : 0;
              return (
                <div key={r.method} className="flex items-center gap-2 text-sm">
                  <span className="w-16 capitalize">{r.method}</span>
                  <div className="h-2 flex-1 overflow-hidden rounded-full bg-surface-container-highest">
                    <div className="h-full bg-surface-tint" style={{ width: `${share}%` }} />
                  </div>
                  <span className="w-12 text-right tabular-nums text-xs">{share.toFixed(0)}%</span>
                </div>
              );
            }
          )}
        </Card>
      </section>

      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">By collector</SectionTitle>
          <ReportCsv
            filename="sales-by-collector.csv"
            headers={['collector', 'amount', 'bills']}
            rows={(byCollector.data ?? []).map(
              (r: { collected_by_stall_id: string; amount: number; bill_count: number }) => [
                nameOf(r.collected_by_stall_id),
                r.amount,
                r.bill_count,
              ]
            )}
          />
        </div>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Collector</Th>
                <Th className="text-right">Amount</Th>
                <Th className="text-right">Bills</Th>
              </tr>
            </thead>
            <tbody>
              {(byCollector.data ?? []).map(
                (r: { collected_by_stall_id: string; amount: number; bill_count: number }) => (
                  <Tr key={r.collected_by_stall_id}>
                    <Td>{nameOf(r.collected_by_stall_id)}</Td>
                    <Td className="text-right tabular-nums">{formatInr(Number(r.amount))}</Td>
                    <Td className="text-right tabular-nums">{r.bill_count}</Td>
                  </Tr>
                )
              )}
            </tbody>
          </table>
        </TableWrap>
      </section>
    </div>
  );
}
