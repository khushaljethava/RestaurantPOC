import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { createStallInvite } from '../group/actions';
import { revokeInvite, changeRole, removeMember } from './actions';
import { RedeemInviteForm } from './redeem-form';
import { InviteShare } from './invite-share';
import {
  Btn,
  Card,
  EmptyState,
  PageTitle,
  SectionTitle,
  Select,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

/**
 * Called by: App Router /staff.
 * Exists: admin/src/app/(app)/staff/page.tsx (Glob confirmed).
 * Data: staff_membership {id,stall_id,user_id,role}, stall_invite {code,role,revoked_at}.
 * User: "Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself."
 */
export default async function StaffPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: myMemberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role')
    .eq('user_id', user!.id);
  if (!myMemberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(myMemberships);
  const stallId = active.stall_id;
  const isOwner = active.role === 'owner';
  const isManager = active.role === 'manager';

  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('id, stall_id, user_id, role')
    .eq('stall_id', stallId);
  const { data: invites } = await supabase
    .from('stall_invite')
    .select('code, role, revoked_at, stall_id')
    .eq('stall_id', stallId);

  const activeInvites = invites?.filter((i) => !i.revoked_at) ?? [];

  return (
    <div className="space-y-6">
      <PageTitle subtitle="Invite codes and stall members">Staff</PageTitle>

      <RedeemInviteForm />

      <section>
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <SectionTitle className="mb-0">Invite codes</SectionTitle>
          {(isOwner || isManager) && (
            <div className="flex gap-2">
              <form
                action={async () => {
                  'use server';
                  await createStallInvite(stallId, 'staff');
                }}
              >
                <Btn type="submit">Generate staff invite</Btn>
              </form>
              {isOwner && (
                <form
                  action={async () => {
                    'use server';
                    await createStallInvite(stallId, 'manager');
                  }}
                >
                  <Btn type="submit" variant="outlined">
                    Generate manager invite
                  </Btn>
                </form>
              )}
            </div>
          )}
        </div>
        <div className="space-y-2">
          {activeInvites.map((i) => (
            <Card key={i.code} className="flex items-center justify-between gap-3 py-3">
              <span className="text-sm">
                <span className="font-mono font-medium">{i.code}</span>
                <span className="ml-2 text-on-surface-variant">· {i.role}</span>
              </span>
              <div className="flex items-center gap-1">
                <InviteShare code={i.code} />
                {isOwner && (
                  <form
                    action={async () => {
                      'use server';
                      await revokeInvite(i.code);
                    }}
                  >
                    <Btn type="submit" variant="danger" className="h-9 px-2 text-xs">
                      Revoke
                    </Btn>
                  </form>
                )}
              </div>
            </Card>
          ))}
          {activeInvites.length === 0 && (
            <Card className="p-0">
              <EmptyState icon="key" title="No active codes">
                Generate an invite code to add staff.
              </EmptyState>
            </Card>
          )}
        </div>
      </section>

      <section>
        <SectionTitle>Members</SectionTitle>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Member</Th>
                <Th>Role</Th>
                <Th />
              </tr>
            </thead>
            <tbody>
              {memberships?.map((m) => (
                <Tr key={m.id}>
                  <Td>
                    <Link href={`/staff/${m.id}`} className="font-mono text-xs text-surface-tint hover:underline">
                      {m.user_id}
                    </Link>
                  </Td>
                  <Td>
                    {isOwner ? (
                      <form
                        action={async (fd: FormData) => {
                          'use server';
                          await changeRole(m.id, String(fd.get('role')));
                        }}
                        className="flex items-center gap-2"
                      >
                        <Select name="role" defaultValue={m.role} className="h-9">
                          <option value="owner">owner</option>
                          <option value="manager">manager</option>
                          <option value="staff">staff</option>
                        </Select>
                        <Btn type="submit" variant="text" className="h-9 px-2">
                          Set
                        </Btn>
                      </form>
                    ) : (
                      m.role
                    )}
                  </Td>
                  <Td className="text-right">
                    <div className="flex items-center justify-end gap-1">
                      <Link href={`/staff/${m.id}`}>
                        <Btn type="button" variant="text" className="h-9 px-2 text-xs">
                          Open
                        </Btn>
                      </Link>
                      {isOwner && (
                        <form
                          action={async () => {
                            'use server';
                            await removeMember(m.id);
                          }}
                        >
                          <Btn type="submit" variant="danger" className="h-9 px-2 text-xs">
                            Remove
                          </Btn>
                        </form>
                      )}
                    </div>
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
