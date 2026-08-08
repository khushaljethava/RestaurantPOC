import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import {
  approveRequest,
  createCourtInvite,
  rejectRequest,
  removeStallFromCourt,
  renameCourt,
  revokeCourtInvite,
} from '../actions';
import {
  Btn,
  Card,
  EmptyState,
  Field,
  PageTitle,
  SectionTitle,
  StatusPill,
} from '@/components/ui';

/**
 * Called by: App Router /courts/[id], linked from courts/page.tsx.
 * One court's operator view: roster, pending requests, invite codes, rename.
 *
 * A single overview page on purpose — tabs are premature until the live board
 * and revenue views exist. Access control is RLS: a non-operator sees no court
 * row and gets notFound(), so there is no separate permission check here.
 */
export default async function CourtPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: court } = await supabase
    .from('food_court')
    .select('id, name')
    .eq('id', id)
    .maybeSingle();
  if (!court) notFound();

  const { data: stalls } = await supabase
    .from('stall')
    .select('id, name')
    .eq('group_id', id)
    .order('name');

  const { data: invites } = await supabase
    .from('group_invite')
    .select('code, revoked_at, created_at')
    .eq('group_id', id)
    .order('created_at', { ascending: false });

  const { data: requests } = await supabase
    .from('group_join_request')
    .select('id, stall_id, status')
    .eq('group_id', id)
    .eq('status', 'pending');

  // Join request rows carry a stall_id but no name; resolve them so the
  // operator sees who is asking rather than a raw UUID.
  const requestStallIds = (requests ?? []).map((r) => r.stall_id);
  const { data: requestStalls } = requestStallIds.length
    ? await supabase.from('stall').select('id, name').in('id', requestStallIds)
    : { data: [] };
  const nameFor = (stallId: string) =>
    (requestStalls ?? []).find((s) => s.id === stallId)?.name ?? stallId;

  const activeInvites = (invites ?? []).filter((i) => !i.revoked_at);

  return (
    <div className="space-y-6">
      <div>
        <Link href="/courts" className="text-sm text-primary hover:underline">
          ← All food courts
        </Link>
        <PageTitle subtitle={`${(stalls ?? []).length} stalls`}>{court.name}</PageTitle>
      </div>

      <section>
        <SectionTitle>Stalls</SectionTitle>
        <div className="space-y-2">
          {(stalls ?? []).map((s) => (
            <Card key={s.id} className="flex items-center justify-between gap-3 py-3">
              <span className="text-sm font-medium text-on-surface">{s.name}</span>
              <form
                action={async () => {
                  'use server';
                  await removeStallFromCourt(id, s.id);
                }}
              >
                <Btn type="submit" variant="danger" className="h-9 px-2 text-xs">
                  Remove
                </Btn>
              </form>
            </Card>
          ))}
          {(stalls ?? []).length === 0 && (
            <Card className="p-0">
              <EmptyState icon="storefront" title="No stalls yet">
                Share an invite code to bring stalls into this court.
              </EmptyState>
            </Card>
          )}
        </div>
      </section>

      <section>
        <SectionTitle>Pending join requests</SectionTitle>
        <div className="space-y-2">
          {(requests ?? []).map((r) => (
            <Card key={r.id} className="flex items-center justify-between gap-3 py-3">
              <span className="flex items-center gap-2 text-sm">
                {nameFor(r.stall_id)}
                <StatusPill tone="warning">{r.status}</StatusPill>
              </span>
              <span className="inline-flex gap-2">
                <form
                  action={async () => {
                    'use server';
                    await approveRequest(id, r.id);
                  }}
                >
                  <Btn type="submit" variant="tonal" className="h-9 px-3 text-xs">
                    Approve
                  </Btn>
                </form>
                <form
                  action={async () => {
                    'use server';
                    await rejectRequest(id, r.id);
                  }}
                >
                  <Btn type="submit" variant="danger" className="h-9 px-3 text-xs">
                    Reject
                  </Btn>
                </form>
              </span>
            </Card>
          ))}
          {(requests ?? []).length === 0 && (
            <Card className="p-0">
              <EmptyState icon="how_to_reg" title="No pending requests" />
            </Card>
          )}
        </div>
      </section>

      <section>
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <SectionTitle className="mb-0">Invite codes</SectionTitle>
          <form
            action={async () => {
              'use server';
              await createCourtInvite(id);
            }}
          >
            <Btn type="submit" variant="outlined">
              Generate code
            </Btn>
          </form>
        </div>
        <div className="space-y-2">
          {activeInvites.map((i) => (
            <Card key={i.code} className="flex items-center justify-between gap-3 py-3">
              <span className="font-mono text-sm font-medium">{i.code}</span>
              <form
                action={async () => {
                  'use server';
                  await revokeCourtInvite(id, i.code);
                }}
              >
                <Btn type="submit" variant="danger" className="h-9 px-2 text-xs">
                  Revoke
                </Btn>
              </form>
            </Card>
          ))}
          {activeInvites.length === 0 && (
            <Card className="p-0">
              <EmptyState icon="key" title="No active codes" />
            </Card>
          )}
        </div>
      </section>

      <section>
        <SectionTitle>Court settings</SectionTitle>
        <Card>
          <form
            action={async (formData: FormData) => {
              'use server';
              await renameCourt(id, String(formData.get('name')));
            }}
            className="flex gap-2"
          >
            <Field
              name="name"
              defaultValue={court.name}
              required
              className="flex-1"
              aria-label="Court name"
            />
            <Btn type="submit" variant="outlined">
              Rename
            </Btn>
          </form>
        </Card>
      </section>
    </div>
  );
}
