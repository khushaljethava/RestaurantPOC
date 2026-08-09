import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { parseRange } from '@/lib/dates';
import { activeStallDayContext, resolveActiveStall } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { ReportCsv } from '../report-csv';
import { DateRangeForm } from '../date-range-form';
import { PageTitle, SectionTitle, TableWrap, Td, Th, Tr } from '@/components/ui';

export default async function CashReportPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const sp = await searchParams;
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const { timezone: tz, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = parseRange(tz, sp.from, sp.to, dayStartMinutes);

  const { data: shifts } = await supabase
    .from('shifts')
    .select(
      'id, staff_id, opened_at, closed_at, opening_float, expected_cash, declared_cash, variance, variance_reason'
    )
    .eq('stall_id', active.stall_id)
    .gte('opened_at', from)
    .lt('opened_at', to)
    .order('opened_at', { ascending: false })
    .limit(200);

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
        Cash reconciliation
      </PageTitle>
      <DateRangeForm fromYmd={from.slice(0, 10)} toYmd={toYmd} />
      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">Shifts in range</SectionTitle>
          <ReportCsv
            filename="cash-shifts.csv"
            headers={['opened', 'staff', 'float', 'expected', 'declared', 'variance', 'reason']}
            rows={(shifts ?? []).map((s) => [
              s.opened_at,
              s.staff_id,
              s.opening_float,
              s.expected_cash,
              s.declared_cash,
              s.variance,
              s.variance_reason,
            ])}
          />
        </div>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Opened</Th>
                <Th className="text-right">Float</Th>
                <Th className="text-right">Expected</Th>
                <Th className="text-right">Declared</Th>
                <Th className="text-right">Variance</Th>
                <Th />
              </tr>
            </thead>
            <tbody>
              {(shifts ?? []).map((s) => (
                <Tr key={s.id}>
                  <Td className="text-xs">{new Date(s.opened_at).toLocaleString()}</Td>
                  <Td className="text-right tabular-nums">{formatInr(Number(s.opening_float))}</Td>
                  <Td className="text-right tabular-nums">
                    {s.expected_cash != null ? formatInr(Number(s.expected_cash)) : '—'}
                  </Td>
                  <Td className="text-right tabular-nums">
                    {s.declared_cash != null ? formatInr(Number(s.declared_cash)) : '—'}
                  </Td>
                  <Td
                    className={`text-right tabular-nums ${
                      s.variance != null && Number(s.variance) !== 0 ? 'text-error' : ''
                    }`}
                  >
                    {s.variance != null ? formatInr(Number(s.variance)) : '—'}
                  </Td>
                  <Td className="text-right">
                    <Link href={`/shifts/${s.id}`} className="text-surface-tint hover:underline">
                      Open
                    </Link>
                  </Td>
                </Tr>
              ))}
            </tbody>
          </table>
        </TableWrap>
      </section>
    </div>
  );
}
