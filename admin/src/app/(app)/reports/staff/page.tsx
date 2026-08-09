import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { parseRange } from '@/lib/dates';
import { activeStallDayContext } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { ReportCsv } from '../report-csv';
import { DateRangeForm } from '../date-range-form';
import { PageTitle, SectionTitle, TableWrap, Td, Th, Tr } from '@/components/ui';

/** Staff/collector report — sales_by_collector is the available RPC (stall-level). */
export default async function StaffReportPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const sp = await searchParams;
  const { timezone: tz, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = parseRange(tz, sp.from, sp.to, dayStartMinutes);
  const supabase = await createClient();
  const [{ data: byCollector }, { data: stalls }] = await Promise.all([
    supabase.rpc('sales_by_collector', { p_from: from, p_to: to }),
    supabase.from('stall').select('id, name'),
  ]);
  const nameOf = (id: string) => stalls?.find((s) => s.id === id)?.name ?? id.slice(0, 8);
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
        Staff / collectors
      </PageTitle>
      <p className="text-sm text-on-surface-variant">
        Collections by collecting stall (RPC granularity). Per-user staff sales land when the
        backend exposes them.
      </p>
      <DateRangeForm fromYmd={from.slice(0, 10)} toYmd={toYmd} />
      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">Collections</SectionTitle>
          <ReportCsv
            filename="collectors.csv"
            headers={['collector', 'amount', 'bills']}
            rows={(byCollector ?? []).map(
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
                <Th>Collector stall</Th>
                <Th className="text-right">Amount</Th>
                <Th className="text-right">Bills</Th>
                <Th className="text-right">Avg bill</Th>
              </tr>
            </thead>
            <tbody>
              {(byCollector ?? []).map(
                (r: { collected_by_stall_id: string; amount: number; bill_count: number }) => {
                  const avg =
                    Number(r.bill_count) > 0 ? Number(r.amount) / Number(r.bill_count) : 0;
                  return (
                    <Tr key={r.collected_by_stall_id}>
                      <Td>{nameOf(r.collected_by_stall_id)}</Td>
                      <Td className="text-right tabular-nums">{formatInr(Number(r.amount))}</Td>
                      <Td className="text-right tabular-nums">{r.bill_count}</Td>
                      <Td className="text-right tabular-nums">{formatInr(avg)}</Td>
                    </Tr>
                  );
                }
              )}
            </tbody>
          </table>
        </TableWrap>
      </section>
    </div>
  );
}
