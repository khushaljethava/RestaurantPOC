import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import {
  createItem,
  createCategory,
  toggleAvailability,
  updateItem,
  deleteItem,
  duplicateItem,
  renameCategory,
  moveCategory,
  uploadItemImage,
  clearItemImage,
} from './actions';
import { Btn, Card, EmptyState, Field, PageTitle, SectionTitle, Select } from '@/components/ui';

/** Route /menu — App Router. Existing page restyled. Tables: category, menu_item. */
export default async function MenuPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase.from('staff_membership').select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const myStallId = active.stall_id;

  const [{ data: categories }, { data: items }] = await Promise.all([
    supabase
      .from('category')
      .select('id, stall_id, name, sort_order')
      .eq('stall_id', myStallId!)
      .order('sort_order'),
    supabase
      .from('menu_item')
      .select('id, stall_id, category_id, name, description, price, is_available, image_url')
      .order('name'),
  ]);

  const mine = (items ?? []).filter((i) => i.stall_id === myStallId);
  const peers = (items ?? []).filter((i) => i.stall_id !== myStallId);

  return (
    <div className="space-y-8">
      <PageTitle subtitle="Categories and items for your stall">Menu</PageTitle>

      <div className="grid gap-8 lg:grid-cols-3">
        <div className="space-y-8 lg:col-span-2">
          <section>
            <SectionTitle>Categories</SectionTitle>
            <form action={createCategory} className="mb-3 flex gap-2">
              <input type="hidden" name="stall_id" value={myStallId} />
              <Field name="name" placeholder="Category" required className="flex-1" />
              <Btn type="submit">Add</Btn>
            </form>
            <div className="space-y-2">
              {(categories ?? []).map((c) => (
                <Card key={c.id} className="flex flex-wrap items-center gap-2 py-2">
                  <form
                    action={async (fd: FormData) => {
                      'use server';
                      await renameCategory(c.id, String(fd.get('name')));
                    }}
                    className="flex min-w-0 flex-1 gap-2"
                  >
                    <Field name="name" defaultValue={c.name} className="h-9 flex-1" />
                    <Btn type="submit" variant="text" className="h-9 px-2">
                      Save
                    </Btn>
                  </form>
                  <form
                    action={async () => {
                      'use server';
                      await moveCategory(c.id, myStallId!, -1);
                    }}
                  >
                    <Btn
                      type="submit"
                      variant="outlined"
                      className="h-9 w-9 px-0"
                      aria-label="Move up"
                    >
                      ↑
                    </Btn>
                  </form>
                  <form
                    action={async () => {
                      'use server';
                      await moveCategory(c.id, myStallId!, 1);
                    }}
                  >
                    <Btn
                      type="submit"
                      variant="outlined"
                      className="h-9 w-9 px-0"
                      aria-label="Move down"
                    >
                      ↓
                    </Btn>
                  </form>
                </Card>
              ))}
            </div>
          </section>

          <section>
            <SectionTitle>Items</SectionTitle>
            <div className="space-y-3">
              {mine.map((i) => (
                <Card key={i.id} className="space-y-3">
                  <div className="flex items-start gap-3">
                    {i.image_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={i.image_url}
                        alt={i.name}
                        className="h-10 w-10 rounded-lg object-cover"
                      />
                    ) : (
                      <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-surface-container-highest text-[10px] text-on-surface-variant">
                        No img
                      </div>
                    )}
                    <div className="min-w-0 flex-1 space-y-2">
                      <form action={updateItem} className="flex flex-wrap items-center gap-2">
                        <input type="hidden" name="id" value={i.id} />
                        <Field
                          name="name"
                          defaultValue={i.name}
                          required
                          className="h-9 min-w-[8rem] flex-1"
                        />
                        <Field
                          name="price"
                          type="number"
                          step="0.01"
                          defaultValue={Number(i.price)}
                          required
                          className="h-9 w-24 tabular-nums"
                        />
                        <Field
                          name="description"
                          defaultValue={i.description ?? ''}
                          placeholder="Description"
                          className="h-9 min-w-[8rem] flex-1"
                        />
                        <Select
                          name="category_id"
                          defaultValue={i.category_id ?? ''}
                          className="h-9"
                        >
                          <option value="">No category</option>
                          {(categories ?? []).map((c) => (
                            <option key={c.id} value={c.id}>
                              {c.name}
                            </option>
                          ))}
                        </Select>
                        <Btn type="submit" variant="text" className="h-9 px-2">
                          Save
                        </Btn>
                      </form>
                      <div className="flex flex-wrap items-center gap-2 text-sm">
                        <form action={uploadItemImage} className="flex items-center gap-2">
                          <input type="hidden" name="stall_id" value={myStallId} />
                          <input type="hidden" name="item_id" value={i.id} />
                          <input
                            type="file"
                            name="image"
                            accept="image/*"
                            required
                            className="text-xs"
                          />
                          <Btn type="submit" variant="text" className="h-8 px-2 text-xs">
                            Upload
                          </Btn>
                        </form>
                        {i.image_url && (
                          <form
                            action={async () => {
                              'use server';
                              await clearItemImage(i.id);
                            }}
                          >
                            <Btn type="submit" variant="danger" className="h-8 px-2 text-xs">
                              Remove image
                            </Btn>
                          </form>
                        )}
                        <form
                          action={async () => {
                            'use server';
                            await toggleAvailability(i.id, !i.is_available);
                          }}
                        >
                          <Btn type="submit" variant="tonal" className="h-8 px-2 text-xs">
                            {i.is_available ? 'Available' : 'Sold out'}
                          </Btn>
                        </form>
                        <form
                          action={async () => {
                            'use server';
                            await duplicateItem(i.id);
                          }}
                        >
                          <Btn type="submit" variant="text" className="h-8 px-2 text-xs">
                            Duplicate
                          </Btn>
                        </form>
                        <form
                          action={async () => {
                            'use server';
                            await deleteItem(i.id);
                          }}
                        >
                          <Btn type="submit" variant="danger" className="h-8 px-2 text-xs">
                            Delete
                          </Btn>
                        </form>
                      </div>
                    </div>
                    <p className="shrink-0 text-base font-medium tabular-nums text-on-surface">
                      ₹{Number(i.price).toFixed(2)}
                    </p>
                  </div>
                </Card>
              ))}
              {mine.length === 0 && (
                <Card className="p-0">
                  <EmptyState icon="restaurant_menu" title="No items yet">
                    Add your first item with the panel on the right.
                  </EmptyState>
                </Card>
              )}
            </div>
          </section>

          <details className="rounded-md border border-border bg-surface p-5 shadow-card">
            <summary className="cursor-pointer text-sm font-semibold text-on-surface-variant">
              Peer stall menus
            </summary>
            <ul className="mt-3 divide-y divide-border text-sm text-on-surface-variant">
              {peers.map((i) => (
                <li key={i.id} className="flex justify-between py-2">
                  <span>{i.name}</span>
                  <span className="tabular-nums">₹{Number(i.price).toFixed(2)}</span>
                </li>
              ))}
              {peers.length === 0 && <li className="py-2">No peer items</li>}
            </ul>
          </details>
        </div>

        <aside className="lg:sticky lg:top-20 lg:self-start">
          <Card>
            <SectionTitle className="mb-4">Add item</SectionTitle>
            <form action={createItem} className="space-y-3">
              <input type="hidden" name="stall_id" value={myStallId} />
              <Field name="name" placeholder="Item name" required />
              <Field name="description" placeholder="Description" />
              <Field
                name="price"
                type="number"
                step="0.01"
                placeholder="Price"
                required
                className="tabular-nums"
              />
              <Select name="category_id" className="w-full">
                <option value="">No category</option>
                {(categories ?? []).map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </Select>
              <Btn type="submit" className="w-full">
                Add item
              </Btn>
            </form>
          </Card>
        </aside>
      </div>
    </div>
  );
}
