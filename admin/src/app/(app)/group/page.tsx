import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { requestJoinGroup, createFoodCourt, leaveGroup } from './actions';
import {
  Btn,
  Card,
  EmptyState,
  Field,
  PageTitle,
  SectionTitle,
  StatusPill,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

/**
 * Called by: App Router /group.
 * Exists: admin/src/app/(app)/group/page.tsx (Glob confirmed).
 * Data: stall {id,name,group_id}, food_court {id,name}, group_invite {code,revoked_at}, group_join_request {id,stall_id,status}.
 * User: "Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself."
 */
export default async function GroupPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase.from('staff_membership').select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const stallId = active.stall_id;
  const isOwner = active.role === 'owner';

  const { data: stall } = stallId
    ? await supabase.from('stall').select('id, name, group_id').eq('id', stallId).maybeSingle()
    : { data: null };

  const { data: court } = stall?.group_id
    ? await supabase.from('food_court').select('id, name').eq('id', stall.group_id).maybeSingle()
    : { data: null };

  // Only this stall's own requests. Approving and rejecting are court-operator
  // powers and live at /courts/[id]; a tenant sees the outcome, not the controls.
  const { data: requests } = stallId
    ? await supabase
        .from('group_join_request')
        .select('id, stall_id, group_id, status')
        .eq('stall_id', stallId)
    : { data: [] };

  const { data: memberStalls } = stall?.group_id
    ? await supabase.from('stall').select('id, name').eq('group_id', stall.group_id)
    : { data: [] };


  return (
    <div className="space-y-6">
      <PageTitle subtitle="The food court this stall belongs to">Food court</PageTitle>

      {stall?.group_id && court ? (
        <div className="space-y-6">
          <div>
            <h2 className="text-xl font-semibold tracking-tight text-on-surface">{court.name}</h2>
            <p className="mt-1 text-sm text-on-surface-variant">
              Your stall is a member of this food court.
            </p>
          </div>

          <section>
            <SectionTitle>Member stalls</SectionTitle>
            <div className="space-y-2">
              {(memberStalls ?? []).map((s) => (
                <Card key={s.id} className="py-3 text-sm font-medium">
                  {s.name}
                </Card>
              ))}
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
              <SectionTitle>Create a food court</SectionTitle>
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
            <SectionTitle>Join with a code</SectionTitle>
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
        <SectionTitle>Your join requests</SectionTitle>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Requested</Th>
                <Th>Status</Th>
              </tr>
            </thead>
            <tbody>
              {requests?.map((r) => (
                <Tr key={r.id}>
                  <Td>Join food court</Td>
                  <Td>
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
                  </Td>
                </Tr>
              ))}
              {(!requests || requests.length === 0) && (
                <tr>
                  <td colSpan={2} className="border-t border-border">
                    <EmptyState icon="how_to_reg" title="No join requests" />
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
