import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import {
  createCourtInvite,
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
} from '@/components/ui';

/**
 * Court operator view: roster, invite codes, rename.
 * Stall owners join via mobile (court code + stall name) — no approve step.
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
                Generate a code below. Owners join in the mobile app with the code
                and their stall name.
              </EmptyState>
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
        <p className="mb-3 text-sm text-on-surface-variant">
          Stall owners enter this code in the mobile app with their stall name and
          join immediately. Staff use separate invites from each stall&apos;s Staff
          page.
        </p>
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
