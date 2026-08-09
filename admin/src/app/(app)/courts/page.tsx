import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { createCourt } from './actions';
import { Btn, Card, EmptyState, Field, PageTitle, SectionTitle } from '@/components/ui';

/**
 * Called by: App Router /courts, linked from the sidebar.
 * Courts the caller OPERATES. Distinct from /group, which is the tenant view
 * of the single court the active stall belongs to.
 *
 * Data: food_court_membership {food_court_id, role}, food_court {id, name},
 * stall {id, group_id} for tenant counts.
 */
export default async function CourtsPage() {
  const supabase = await createClient();

  const { data: memberships } = await supabase
    .from('food_court_membership')
    .select('food_court_id, role');

  const courtIds = (memberships ?? []).map((m) => m.food_court_id);

  const { data: courts } = courtIds.length
    ? await supabase.from('food_court').select('id, name').in('id', courtIds).order('name')
    : { data: [] };

  // One query for all tenant counts rather than one per court.
  const { data: tenants } = courtIds.length
    ? await supabase.from('stall').select('id, group_id').in('group_id', courtIds)
    : { data: [] };

  const countFor = (id: string) => (tenants ?? []).filter((s) => s.group_id === id).length;

  return (
    <div className="space-y-6">
      <PageTitle subtitle="Food courts you operate">Food Courts</PageTitle>

      <div className="space-y-2">
        {(courts ?? []).map((c) => (
          <Link key={c.id} href={`/courts/${c.id}`} className="block">
            <Card className="flex items-center justify-between gap-3 py-4 transition-colors hover:bg-surface-container-high">
              <span className="font-medium text-on-surface">{c.name}</span>
              <span className="text-sm text-on-surface-variant">
                {countFor(c.id)} {countFor(c.id) === 1 ? 'stall' : 'stalls'}
              </span>
            </Card>
          </Link>
        ))}
        {(courts ?? []).length === 0 && (
          <Card className="p-0">
            <EmptyState icon="storefront" title="No food courts yet">
              Create one, then generate an invite code for stall owners.
            </EmptyState>
          </Card>
        )}
      </div>

      <Card>
        <SectionTitle>Create a food court</SectionTitle>
        <form
          action={async (formData: FormData) => {
            'use server';
            await createCourt(String(formData.get('name')));
          }}
          className="flex gap-2"
        >
          <Field name="name" placeholder="Food court name" required className="flex-1" />
          <Btn type="submit">Create</Btn>
        </form>
      </Card>
    </div>
  );
}
