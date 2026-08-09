import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import {
  Card,
  EmptyState,
  PageTitle,
  SectionTitle,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

export default async function ShiftsPage() {
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

  const { data: shifts } = await supabase
    .from('shifts')
    .select(
      'id, stall_id, staff_id, opened_at, closed_at, opening_float, declared_cash, expected_cash, variance, variance_reason'
    )
    .eq('stall_id', active.stall_id)
    .order('opened_at', { ascending: false })
    .limit(50);

  const now = Date.now();
  const staleOpen = (shifts ?? []).filter(
    (s) => !s.closed_at && now - new Date(s.opened_at).getTime() > 12 * 3600_000
  );

  return (
    <div className="space-y-6">
      <PageTitle
        subtitle="Cash sessions for the active stall"
        trailing={
          <Link href="/payments/verify" className="text-sm text-surface-tint hover:underline">
            UPI verify →
          </Link>
        }
      >
        Shifts
      </PageTitle>

      {staleOpen.length > 0 && (
        <Card className="border-warning bg-warning/5 text-sm text-on-surface">
          {staleOpen.length} open shift{staleOpen.length === 1 ? '' : 's'} older than 12 hours —
          review and force-close if forgotten.
        </Card>
      )}

      <section>
        <SectionTitle>Recent shifts</SectionTitle>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Opened</Th>
                <Th>Status</Th>
                <Th className="text-right">Expected</Th>
                <Th className="text-right">Declared</Th>
                <Th className="text-right">Variance</Th>
                <Th />
              </tr>
            </thead>
            <tbody>
              {(shifts ?? []).map((s) => {
                const openHours = !s.closed_at
                  ? (now - new Date(s.opened_at).getTime()) / 3600_000
                  : 0;
                return (
                  <Tr key={s.id}>
                    <Td className="text-sm">{new Date(s.opened_at).toLocaleString()}</Td>
                    <Td className="text-sm">
                      {s.closed_at ? 'Closed' : openHours > 12 ? 'Open (stale)' : 'Open'}
                    </Td>
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
                      <Link
                        href={`/shifts/${s.id}`}
                        className="text-sm text-surface-tint hover:underline"
                      >
                        Open
                      </Link>
                    </Td>
                  </Tr>
                );
              })}
            </tbody>
          </table>
        </TableWrap>
        {(shifts ?? []).length === 0 && (
          <Card className="mt-2 p-0">
            <EmptyState icon="schedule" title="No shifts yet">
              Shifts opened on mobile appear here.
            </EmptyState>
          </Card>
        )}
      </section>
    </div>
  );
}
