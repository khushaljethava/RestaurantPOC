import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { parseRange } from '@/lib/dates';
import { activeStallDayContext } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { ReportCsv } from '../report-csv';
import { DateRangeForm } from '../date-range-form';
import { PageTitle, SectionTitle, TableWrap, Td, Th, Tr } from '@/components/ui';

export default async function ItemsReportPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const sp = await searchParams;
  const { timezone: tz, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = parseRange(tz, sp.from, sp.to, dayStartMinutes);
  const supabase = await createClient();
  const [{ data: byItem }, { data: stalls }] = await Promise.all([
    supabase.rpc('sales_by_item', { p_from: from, p_to: to }),
    supabase.from('stall').select('id, name'),
  ]);
  const nameOf = (id: string) => stalls?.find((s) => s.id === id)?.name ?? id.slice(0, 8);
  const rows = [...(byItem ?? [])].sort(
    (a: { revenue: number }, b: { revenue: number }) => Number(b.revenue) - Number(a.revenue)
  );
  const top = rows.slice(0, 20);
  const bottom = [...rows].reverse().slice(0, 20);
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
        Items
      </PageTitle>
      <DateRangeForm fromYmd={from.slice(0, 10)} toYmd={toYmd} />

      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">Top 20 by revenue</SectionTitle>
          <ReportCsv
            filename="items-top.csv"
            headers={['item', 'stall', 'qty', 'revenue']}
            rows={top.map(
              (r: { item_name: string; stall_id: string; qty: number; revenue: number }) => [
                r.item_name,
                nameOf(r.stall_id),
                r.qty,
                r.revenue,
              ]
            )}
          />
        </div>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Item</Th>
                <Th>Stall</Th>
                <Th className="text-right">Qty</Th>
                <Th className="text-right">Revenue</Th>
              </tr>
            </thead>
            <tbody>
              {top.map(
                (r: {
                  menu_item_id: string;
                  item_name: string;
                  stall_id: string;
                  qty: number;
                  revenue: number;
                }) => (
                  <Tr key={`t-${r.menu_item_id}-${r.stall_id}`}>
                    <Td>{r.item_name}</Td>
                    <Td>{nameOf(r.stall_id)}</Td>
                    <Td className="text-right tabular-nums">{Number(r.qty)}</Td>
                    <Td className="text-right tabular-nums">{formatInr(Number(r.revenue))}</Td>
                  </Tr>
                )
              )}
            </tbody>
          </table>
        </TableWrap>
      </section>

      <section className="space-y-3">
        <SectionTitle>Bottom 20 by revenue</SectionTitle>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Item</Th>
                <Th>Stall</Th>
                <Th className="text-right">Qty</Th>
                <Th className="text-right">Revenue</Th>
              </tr>
            </thead>
            <tbody>
              {bottom.map(
                (r: {
                  menu_item_id: string;
                  item_name: string;
                  stall_id: string;
                  qty: number;
                  revenue: number;
                }) => (
                  <Tr key={`b-${r.menu_item_id}-${r.stall_id}`}>
                    <Td>{r.item_name}</Td>
                    <Td>{nameOf(r.stall_id)}</Td>
                    <Td className="text-right tabular-nums">{Number(r.qty)}</Td>
                    <Td className="text-right tabular-nums">{formatInr(Number(r.revenue))}</Td>
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
