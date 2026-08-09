import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { toggleAvailability } from '../actions';
import { Btn, Card, PageTitle, SectionTitle } from '@/components/ui';

export default async function AvailabilityBoardPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase.from('staff_membership').select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);

  const [{ data: categories }, { data: items }] = await Promise.all([
    supabase
      .from('category')
      .select('id, name, sort_order')
      .eq('stall_id', active.stall_id)
      .order('sort_order'),
    supabase
      .from('menu_item')
      .select('id, name, category_id, is_available, quick_code')
      .eq('stall_id', active.stall_id)
      .is('parent_id', null)
      .order('name'),
  ]);

  const byCat = new Map<string | null, typeof items>();
  for (const it of items ?? []) {
    const key = it.category_id;
    const list = byCat.get(key) ?? [];
    list.push(it);
    byCat.set(key, list);
  }

  return (
    <div className="space-y-6">
      <PageTitle
        subtitle={
          <Link href="/menu" className="text-surface-tint hover:underline">
            ← Menu
          </Link>
        }
      >
        Availability
      </PageTitle>
      <p className="text-sm text-on-surface-variant">
        Toggle sold-out items. Mirrors mobile stock for laptop managers.
      </p>

      {(categories ?? []).map((c) => (
        <section key={c.id} className="space-y-2">
          <SectionTitle>{c.name}</SectionTitle>
          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {(byCat.get(c.id) ?? []).map((it) => (
              <Card key={it.id} className="flex items-center justify-between gap-2 py-3">
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium">{it.name}</p>
                  {it.quick_code && (
                    <p className="font-mono text-xs text-on-surface-variant">{it.quick_code}</p>
                  )}
                </div>
                <form
                  action={async () => {
                    'use server';
                    await toggleAvailability(it.id, !it.is_available);
                  }}
                >
                  <Btn
                    type="submit"
                    variant={it.is_available ? 'outlined' : 'danger'}
                    className="h-9 px-3 text-xs"
                  >
                    {it.is_available ? 'Available' : 'Sold out'}
                  </Btn>
                </form>
              </Card>
            ))}
          </div>
        </section>
      ))}

      {(byCat.get(null) ?? []).length > 0 && (
        <section className="space-y-2">
          <SectionTitle>Uncategorized</SectionTitle>
          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {(byCat.get(null) ?? []).map((it) => (
              <Card key={it.id} className="flex items-center justify-between gap-2 py-3">
                <p className="truncate text-sm font-medium">{it.name}</p>
                <form
                  action={async () => {
                    'use server';
                    await toggleAvailability(it.id, !it.is_available);
                  }}
                >
                  <Btn
                    type="submit"
                    variant={it.is_available ? 'outlined' : 'danger'}
                    className="h-9 px-3 text-xs"
                  >
                    {it.is_available ? 'Available' : 'Sold out'}
                  </Btn>
                </form>
              </Card>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
