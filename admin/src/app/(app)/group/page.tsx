import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall, activeStallDayContext } from '@/lib/active-stall';
import { stallDayBounds } from '@/lib/dates';
import { formatInr } from '@/lib/money';
import { leaveGroup } from './actions';
import { Btn, Card, PageTitle, SectionTitle } from '@/components/ui';

/**
 * Stall tenant view of the food court they belong to.
 * Joining a court (new stall owner) happens in the mobile app via court invite.
 * Creating courts / minting invites is the operator surface at /courts.
 */
export default async function GroupPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase.from('staff_membership').select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const stallId = active.stall_id;
  const isOwner = active.role === 'owner';

  const { timezone, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = stallDayBounds(timezone, dayStartMinutes);

  const { data: stall } = stallId
    ? await supabase.from('stall').select('id, name, group_id').eq('id', stallId).maybeSingle()
    : { data: null };

  const { data: court } = stall?.group_id
    ? await supabase.from('food_court').select('id, name').eq('id', stall.group_id).maybeSingle()
    : { data: null };

  const { data: memberStalls } = stall?.group_id
    ? await supabase.from('stall').select('id, name').eq('group_id', stall.group_id)
    : { data: [] };

  const { data: sales } = await supabase.rpc('sales_by_stall', { p_from: from, p_to: to });
  const memberIds = new Set((memberStalls ?? []).map((s) => s.id));
  const groupSales = (sales ?? []).filter((r: { stall_id: string }) =>
    memberIds.has(r.stall_id)
  );
  const groupVolume = groupSales.reduce(
    (s: number, r: { revenue: number }) => s + Number(r.revenue),
    0
  );

  const { data: pairs } = await supabase.rpc('settlement_pairs', {
    p_from: from,
    p_to: to,
  });
  const myOpen = ((pairs ?? []) as { stall_a: string; stall_b: string; a_owes_b: number }[])
    .filter((p) => p.stall_a === stallId || p.stall_b === stallId)
    .map((p) => {
      const amt = Number(p.a_owes_b);
      const other = p.stall_a === stallId ? p.stall_b : p.stall_a;
      const owed = p.stall_a === stallId ? amt : -amt;
      return { other, owed };
    })
    .filter((x) => Math.abs(x.owed) > 0.009);

  const { count: pendingMarks } = stallId
    ? await supabase
        .from('settlement_record')
        .select('id', { count: 'exact', head: true })
        .or(`from_stall_id.eq.${stallId},to_stall_id.eq.${stallId}`)
        .is('confirmed_at', null)
        .eq('disputed', false)
    : { count: 0 };

  const blockedLeave = myOpen.length > 0 || (pendingMarks ?? 0) > 0;
  const nameOf = (id: string) =>
    (memberStalls ?? []).find((s) => s.id === id)?.name ?? id.slice(0, 8);

  if (!stall?.group_id || !court) {
    return (
      <div className="space-y-6">
        <PageTitle subtitle="This stall is not in a food court">Court</PageTitle>
        <Card className="space-y-2 text-sm text-on-surface-variant">
          <p>
            To join a food court, open the <strong className="text-on-surface">mobile app</strong>,
            go to Join, and enter the court invite code plus your stall name. You become
            a stall owner in that court immediately.
          </p>
          <p>
            Staff invites are separate — use the{' '}
            <Link href="/staff" className="text-surface-tint hover:underline">
              Staff
            </Link>{' '}
            page after you have a stall.
          </p>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <PageTitle subtitle="Your stall's food court membership">{court.name}</PageTitle>

      <Card className="text-sm text-on-surface-variant">
        Menus and staff stay owned by each stall. Cross-stall orders and settlement
        use this court. Staff invites are on the{' '}
        <Link href="/staff" className="text-surface-tint hover:underline">
          Staff
        </Link>{' '}
        page.
      </Card>

      <div className="grid gap-3 sm:grid-cols-2">
        <Card>
          <p className="text-xs text-on-surface-variant">Group volume today</p>
          <p className="text-2xl font-semibold tabular-nums">{formatInr(groupVolume)}</p>
        </Card>
        <Card>
          <p className="text-xs text-on-surface-variant">Your open settlement</p>
          <p className="text-2xl font-semibold tabular-nums">
            {myOpen.length === 0
              ? formatInr(0)
              : formatInr(myOpen.reduce((s, x) => s + Math.abs(x.owed), 0))}
          </p>
          <Link href="/settlement" className="text-xs text-surface-tint hover:underline">
            Settlement →
          </Link>
        </Card>
      </div>

      <section>
        <SectionTitle>Orders per stall today</SectionTitle>
        <ul className="space-y-1 text-sm">
          {groupSales.map((r: { stall_id: string; revenue: number; order_count: number }) => (
            <li
              key={r.stall_id}
              className="flex justify-between rounded-lg border border-border px-3 py-2"
            >
              <span>{nameOf(r.stall_id)}</span>
              <span className="tabular-nums text-on-surface-variant">
                {r.order_count} orders · {formatInr(Number(r.revenue))}
              </span>
            </li>
          ))}
          {groupSales.length === 0 && (
            <li className="text-on-surface-variant">No sales in the group yet today.</li>
          )}
        </ul>
      </section>

      <section>
        <SectionTitle>Member stalls</SectionTitle>
        <div className="space-y-2">
          {(memberStalls ?? []).map((s) => (
            <Card key={s.id} className="py-3 text-sm font-medium">
              {s.name}
              {s.id === stallId ? (
                <span className="ml-2 text-xs font-normal text-on-surface-variant">(you)</span>
              ) : null}
            </Card>
          ))}
        </div>
      </section>

      {isOwner && (
        <div className="space-y-3">
          {blockedLeave && (
            <Card className="space-y-2 text-sm">
              <p className="font-medium text-warning">Settle first before leaving</p>
              <p className="text-on-surface-variant">
                Leaving stops cross-stall ordering. Past settlements remain in history.
              </p>
              {myOpen.map((x) => (
                <p key={x.other}>
                  {x.owed > 0
                    ? `You owe ${nameOf(x.other)} ${formatInr(x.owed)}`
                    : `${nameOf(x.other)} owes you ${formatInr(-x.owed)}`}
                </p>
              ))}
              {(pendingMarks ?? 0) > 0 && (
                <p>{pendingMarks} settlement mark(s) awaiting confirmation.</p>
              )}
              <Link href="/settlement" className="text-surface-tint hover:underline">
                Go to settlement →
              </Link>
            </Card>
          )}
          <form
            action={async () => {
              'use server';
              await leaveGroup(stallId!);
            }}
          >
            <Btn type="submit" variant="danger" disabled={blockedLeave}>
              Leave food court
            </Btn>
          </form>
        </div>
      )}
    </div>
  );
}
