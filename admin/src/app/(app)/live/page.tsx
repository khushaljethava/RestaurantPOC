import { createClient } from '@/lib/supabase/server';
import { LivePoll } from './live-poll';
import { Card, PageTitle, StatusPill } from '@/components/ui';

export default async function LivePage() {
  const supabase = await createClient();

  const { data: openBills } = await supabase
    .from('bill')
    .select('id, total, discount, table_label, collected_by_stall_id, created_at, status')
    .eq('status', 'open')
    .order('created_at', { ascending: false })
    .limit(50);

  const { data: activeOrders } = await supabase
    .from('orders')
    .select('id, token_no, status, stall_id, table_label, created_at')
    .in('status', ['pending', 'ready'])
    .order('created_at', { ascending: false })
    .limit(50);

  const { data: stalls } = await supabase.from('stall').select('id, name');
  const nameOf = (id: string) => stalls?.find((s) => s.id === id)?.name ?? id.slice(0, 8);

  return (
    <div>
      <PageTitle trailing={<LivePoll />}>Live board</PageTitle>

      <div className="grid gap-6 lg:grid-cols-2">
        <section>
          <h2 className="mb-3 text-base font-medium text-on-surface">
            Open bills ({openBills?.length ?? 0})
          </h2>
          <div className="space-y-2">
            {(openBills ?? []).map((b) => (
              <Card key={b.id} className="flex items-center justify-between gap-3 py-3">
                <div>
                  <p className="text-sm font-medium text-on-surface">
                    {b.table_label ? `Table ${b.table_label}` : 'Counter'}
                  </p>
                  <p className="text-[11px] text-on-surface-variant">
                    {nameOf(b.collected_by_stall_id)}
                  </p>
                </div>
                <p className="text-xl font-medium tabular-nums text-on-surface">
                  ₹{(Number(b.total) - Number(b.discount)).toFixed(2)}
                </p>
              </Card>
            ))}
            {(!openBills || openBills.length === 0) && (
              <Card className="text-sm text-on-surface-variant">No open bills</Card>
            )}
          </div>
        </section>

        <section>
          <h2 className="mb-3 text-base font-medium text-on-surface">
            Active orders ({activeOrders?.length ?? 0})
          </h2>
          <div className="space-y-2">
            {(activeOrders ?? []).map((o) => (
              <Card key={o.id} className="flex items-center justify-between gap-3 py-3">
                <div>
                  <p className="text-sm font-medium text-on-surface">
                    Token #{o.token_no}
                    {o.table_label ? ` · T${o.table_label}` : ''}
                  </p>
                  <p className="text-[11px] text-on-surface-variant">{nameOf(o.stall_id)}</p>
                </div>
                <StatusPill tone={o.status === 'ready' ? 'success' : 'warning'}>
                  {o.status === 'ready' ? 'Ready' : 'Pending'}
                </StatusPill>
              </Card>
            ))}
            {(!activeOrders || activeOrders.length === 0) && (
              <Card className="text-sm text-on-surface-variant">No active orders</Card>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
