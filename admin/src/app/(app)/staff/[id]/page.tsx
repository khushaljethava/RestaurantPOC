import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { changeRole, removeMember, resetStaffPin } from '../actions';
import { Btn, Card, Field, Label, PageTitle, SectionTitle } from '@/components/ui';

/**
 * Staff detail: role, remove, PIN reset.
 * Callers: App Router /staff/[id] from staff list links.
 * User: Implement the plan as specified, it is attached for your reference.
 */
export default async function StaffDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ pin?: string }>;
}) {
  const { id } = await params;
  const sp = await searchParams;
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
  const canManage = active.role === 'owner' || active.role === 'manager';
  const isOwner = active.role === 'owner';

  const { data: member } = await supabase
    .from('staff_membership')
    .select('id, stall_id, user_id, role, pin_hash')
    .eq('id', id)
    .eq('stall_id', active.stall_id)
    .maybeSingle();

  if (!member) notFound();

  const shownPin = sp.pin && /^\d{4}$/.test(sp.pin) ? sp.pin : null;

  return (
    <div className="mx-auto max-w-[640px] space-y-6">
      <PageTitle
        subtitle={
          <Link href="/staff" className="text-surface-tint hover:underline">
            ← Staff
          </Link>
        }
      >
        Member
      </PageTitle>

      <Card className="space-y-4">
        <div>
          <p className="text-xs text-on-surface-variant">User id</p>
          <p className="font-mono text-sm break-all">{member.user_id}</p>
        </div>
        <div>
          <p className="text-xs text-on-surface-variant">PIN</p>
          <p className="text-sm">{member.pin_hash ? 'Set' : 'Not set'}</p>
        </div>

        {isOwner && (
          <form
            action={async (fd: FormData) => {
              'use server';
              await changeRole(member.id, String(fd.get('role')));
            }}
            className="flex flex-wrap items-end gap-2"
          >
            <Label className="flex-1">
              Role
              <select
                name="role"
                defaultValue={member.role}
                className="mt-1 w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm"
              >
                <option value="owner">owner</option>
                <option value="manager">manager</option>
                <option value="staff">staff</option>
              </select>
            </Label>
            <Btn type="submit">Update role</Btn>
          </form>
        )}

        {!isOwner && (
          <p className="text-sm text-on-surface-variant">Role: {member.role}</p>
        )}
      </Card>

      {canManage && (
        <Card className="space-y-3">
          <SectionTitle className="mb-0">Reset PIN</SectionTitle>
          <p className="text-xs text-on-surface-variant">
            Sets a temporary 4-digit PIN. Shown once after save — never stored in plain text.
          </p>
          {shownPin && (
            <p className="rounded-lg bg-primary-container px-3 py-2 font-mono text-lg font-semibold text-on-primary-container">
              New PIN: {shownPin}
            </p>
          )}
          <form
            action={async (fd: FormData) => {
              'use server';
              const pin = String(fd.get('pin') || '');
              const set = await resetStaffPin(member.stall_id, member.user_id, pin);
              const { redirect } = await import('next/navigation');
              redirect(`/staff/${member.id}?pin=${set}`);
            }}
            className="flex flex-wrap items-end gap-2"
          >
            <Label className="flex-1">
              New PIN
              <Field
                name="pin"
                inputMode="numeric"
                pattern="\d{4}"
                maxLength={4}
                placeholder="1234"
                required
                className="mt-1"
              />
            </Label>
            <Btn type="submit">Reset PIN</Btn>
          </form>
        </Card>
      )}

      {isOwner && (
        <form
          action={async () => {
            'use server';
            await removeMember(member.id);
            const { redirect } = await import('next/navigation');
            redirect('/staff');
          }}
        >
          <Btn type="submit" variant="danger">
            Remove from stall
          </Btn>
        </form>
      )}
    </div>
  );
}
