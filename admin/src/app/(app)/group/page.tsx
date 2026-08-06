import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import {
  requestJoinGroup,
  approveJoinRequest,
  rejectJoinRequest,
  createFoodCourt,
  createGroupInvite,
  leaveGroup,
} from './actions';
import { Btn, Card, Field, PageTitle, StatusPill, TableWrap, Th } from '@/components/ui';

/**
 * Called by: App Router /group.
 * Exists: admin/src/app/(app)/group/page.tsx (Glob confirmed).
 * Data: stall {id,name,group_id}, food_court {id,name}, group_invite {code,revoked_at}, group_join_request {id,stall_id,status}.
 * User: "Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself."
 */
export default async function GroupPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const stallId = active.stall_id;
  const isOwner = active.role === 'owner';

  const { data: stall } = stallId
    ? await supabase
        .from('stall')
        .select('id, name, group_id')
        .eq('id', stallId)
        .maybeSingle()
    : { data: null };

  const { data: court } = stall?.group_id
    ? await supabase
        .from('food_court')
        .select('id, name')
        .eq('id', stall.group_id)
        .maybeSingle()
    : { data: null };

  const { data: invites } = stall?.group_id
    ? await supabase
        .from('group_invite')
        .select('code, revoked_at, created_at')
        .eq('group_id', stall.group_id)
        .order('created_at', { ascending: false })
    : { data: [] };

  const { data: requests } = await supabase
    .from('group_join_request')
    .select('id, stall_id, group_id, status');

  const { data: memberStalls } = stall?.group_id
    ? await supabase.from('stall').select('id, name').eq('group_id', stall.group_id)
    : { data: [] };

  const activeInvites = (invites ?? []).filter((i) => !i.revoked_at);

  return (
    <div className="space-y-6">
      <PageTitle>Food court</PageTitle>

      {stall?.group_id && court ? (
        <div className="space-y-6">
          <div>
            <h2 className="text-2xl font-normal text-on-surface">{court.name}</h2>
            <p className="mt-1 text-sm text-on-surface-variant">
              Your stall is a member of this food court.
            </p>
          </div>

          <section>
            <h3 className="mb-3 text-base font-medium text-on-surface">Member stalls</h3>
            <div className="space-y-2">
              {(memberStalls ?? []).map((s) => (
                <Card key={s.id} className="py-3 text-sm font-medium">
                  {s.name}
                </Card>
              ))}
            </div>
          </section>

          <section>
            <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
              <h3 className="text-base font-medium text-on-surface">Invite codes</h3>
              {isOwner && (
                <form
                  action={async () => {
                    'use server';
                    await createGroupInvite(stall.group_id!);
                  }}
                >
                  <Btn type="submit" variant="outlined">
                    Generate new code
                  </Btn>
                </form>
              )}
            </div>
            <div className="space-y-2">
              {activeInvites.map((i) => (
                <Card key={i.code} className="py-3 font-mono text-sm">
                  {i.code}
                </Card>
              ))}
              {activeInvites.length === 0 && (
                <Card className="text-sm text-on-surface-variant">No active codes</Card>
              )}
            </div>
          </section>

          {isOwner && (
            <form
              action={async () => {
                'use server';
                await leaveGroup(stallId!);
              }}
            >
              <Btn type="submit" variant="danger">
                Leave food court
              </Btn>
            </form>
          )}
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {isOwner && (
            <Card>
              <h2 className="mb-3 text-base font-medium text-on-surface">Create a food court</h2>
              <form
                action={async (formData: FormData) => {
                  'use server';
                  await createFoodCourt(String(formData.get('name')), stallId!);
                }}
                className="space-y-3"
              >
                <Field name="name" placeholder="Food court name" required />
                <Btn type="submit" className="w-full">
                  Create food court
                </Btn>
              </form>
            </Card>
          )}
          <Card>
            <h2 className="mb-3 text-base font-medium text-on-surface">Join with a code</h2>
            <form
              action={async (formData: FormData) => {
                'use server';
                await requestJoinGroup(String(formData.get('code')), stallId!);
              }}
              className="space-y-3"
            >
              <Field name="code" placeholder="Group invite code" className="font-mono" />
              <Btn type="submit" className="w-full">
                Request to join
              </Btn>
            </form>
          </Card>
        </div>
      )}

      <section>
        <h2 className="mb-3 text-base font-medium text-on-surface">Pending join requests</h2>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Stall</Th>
                <Th>Status</Th>
                <Th />
              </tr>
            </thead>
            <tbody>
              {requests?.map((r) => (
                <tr key={r.id}>
                  <td className="h-11 border-t border-border px-3 text-sm">
                    <span className="font-mono text-xs">{r.stall_id}</span>
                  </td>
                  <td className="h-11 border-t border-border px-3 text-sm">
                    <StatusPill
                      tone={
                        r.status === 'pending'
                          ? 'warning'
                          : r.status === 'approved'
                            ? 'success'
                            : 'neutral'
                      }
                    >
                      {r.status}
                    </StatusPill>
                  </td>
                  <td className="h-11 border-t border-border px-3 text-right text-sm">
                    {r.status === 'pending' && (
                      <span className="inline-flex gap-2">
                        <form
                          action={async () => {
                            'use server';
                            await approveJoinRequest(r.id);
                          }}
                        >
                          <Btn type="submit" variant="tonal" className="h-9 px-3 text-xs">
                            Approve
                          </Btn>
                        </form>
                        <form
                          action={async () => {
                            'use server';
                            await rejectJoinRequest(r.id);
                          }}
                        >
                          <Btn type="submit" variant="danger" className="h-9 px-3 text-xs">
                            Reject
                          </Btn>
                        </form>
                      </span>
                    )}
                  </td>
                </tr>
              ))}
              {(!requests || requests.length === 0) && (
                <tr>
                  <td colSpan={3} className="h-11 border-t border-border px-3 text-sm text-on-surface-variant">
                    No requests
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </TableWrap>
      </section>
    </div>
  );
}
