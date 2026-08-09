import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { parseRange } from '@/lib/dates';
import { activeStallDayContext } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { ReportCsv } from '../report-csv';
import { DateRangeForm } from '../date-range-form';
import { Card, PageTitle, SectionTitle, TableWrap, Td, Th, Tr } from '@/components/ui';

type Pair = { stall_a: string; stall_b: string; a_owes_b: number };

export default async function CrossStallReportPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const sp = await searchParams;
  const { timezone: tz, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = parseRange(tz, sp.from, sp.to, dayStartMinutes);
  const supabase = await createClient();
  const [{ data: pairs }, { data: stalls }] = await Promise.all([
    supabase.rpc('settlement_pairs', { p_from: from, p_to: to }),
    supabase.from('stall').select('id, name'),
  ]);
  const nameOf = (id: string) => stalls?.find((s) => s.id === id)?.name ?? id.slice(0, 8);
  const list = (pairs ?? []) as Pair[];
  const ids = Array.from(
    new Set(list.flatMap((p) => [p.stall_a, p.stall_b]))
  ).sort();
  const toYmd = new Date(new Date(to).getTime() - 86400000).toISOString().slice(0, 10);

  function cell(row: string, col: string): number {
    if (row === col) return 0;
    const ab = list.find((p) => p.stall_a === row && p.stall_b === col);
    if (ab) return Number(ab.a_owes_b);
    const ba = list.find((p) => p.stall_a === col && p.stall_b === row);
    if (ba) return -Number(ba.a_owes_b);
    return 0;
  }

  return (
    <div className="space-y-8">
      <PageTitle
        subtitle={
          <Link href="/reports" className="text-surface-tint hover:underline">
            ← Reports
          </Link>
        }
      >
        Cross-stall
      </PageTitle>
      <DateRangeForm fromYmd={from.slice(0, 10)} toYmd={toYmd} />
      <p className="text-sm text-on-surface-variant">
        Matrix: row owes column. Drill into settlement for order-level detail.
      </p>

      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">Net matrix</SectionTitle>
          <ReportCsv
            filename="cross-stall.csv"
            headers={['from', 'to', 'amount']}
            rows={list.map((p) => [nameOf(p.stall_a), nameOf(p.stall_b), p.a_owes_b])}
          />
        </div>
        {ids.length === 0 ? (
          <Card>
            <p className="text-sm text-on-surface-variant">No cross-stall activity in range.</p>
          </Card>
        ) : (
          <TableWrap>
            <table className="w-full">
              <thead>
                <tr>
                  <Th>Owes →</Th>
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
                          className={`text-right tabular-nums ${v < 0 ? 'text-error' : ''}`}
                        >
                          {row === col ? '—' : formatInr(v)}
                        </Td>
                      );
                    })}
                  </Tr>
                ))}
              </tbody>
            </table>
          </TableWrap>
        )}
      </section>

      <p className="text-sm">
        <Link href={`/settlement?from=${from.slice(0, 10)}&to=${toYmd}`} className="text-surface-tint hover:underline">
          Open settlement ledger →
        </Link>
      </p>
    </div>
  );
}
