import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall, activeStallDayContext } from '@/lib/active-stall';
import { stallDayBounds } from '@/lib/dates';
import {
  Card,
  EmptyState,
  PageTitle,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

export default async function AuditPage() {
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

  const { timezone, dayStartMinutes } = await activeStallDayContext();
  const { from } = stallDayBounds(timezone, dayStartMinutes);
  // last 30 business days approx
  const since = new Date(new Date(from).getTime() - 30 * 86400000).toISOString();

  const { data: rows } = await supabase
    .from('audit_log')
    .select('id, action, entity_type, entity_id, actor_id, reason, created_at, payload')
    .eq('stall_id', active.stall_id)
    .gte('created_at', since)
    .order('created_at', { ascending: false })
    .limit(200);

  return (
    <div className="space-y-6">
      <PageTitle subtitle="Recent mutations for this stall (30 days)">Audit log</PageTitle>
      <TableWrap>
        <table className="w-full">
          <thead>
            <tr>
              <Th>When</Th>
              <Th>Action</Th>
              <Th>Entity</Th>
              <Th>Actor</Th>
              <Th>Reason</Th>
            </tr>
          </thead>
          <tbody>
            {(rows ?? []).map((r) => (
              <Tr key={r.id}>
                <Td className="whitespace-nowrap text-xs">
                  {new Date(r.created_at).toLocaleString()}
                </Td>
                <Td className="font-medium">{r.action}</Td>
                <Td className="font-mono text-xs">
                  {r.entity_type} · {r.entity_id.slice(0, 8)}
                </Td>
                <Td className="font-mono text-xs">{r.actor_id.slice(0, 8)}</Td>
                <Td className="text-sm text-on-surface-variant">{r.reason ?? '—'}</Td>
              </Tr>
            ))}
          </tbody>
        </table>
      </TableWrap>
      {(rows ?? []).length === 0 && (
        <Card className="p-0">
          <EmptyState icon="history" title="No audit rows">
            Sensitive actions write here when they run through RPCs / settings.
          </EmptyState>
        </Card>
      )}
    </div>
  );
}
