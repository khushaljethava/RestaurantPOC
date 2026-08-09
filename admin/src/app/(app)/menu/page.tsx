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
  addItemImage,
  removeItemImage,
  addTable,
  setTableActive,
  deleteTable,
  deleteCategory,
} from './actions';
import { MenuSearch } from './menu-search';
import { Btn, Card, EmptyState, Field, PageTitle, SectionTitle, Select } from '@/components/ui';

/** Route /menu — App Router. Existing page restyled. Tables: category, menu_item. */
export default async function MenuPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase.from('staff_membership').select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const myStallId = active.stall_id;

  const [{ data: categories }, { data: items }, { data: tables }, { data: images }] =
    await Promise.all([
      supabase
        .from('category')
        .select('id, stall_id, name, sort_order')
        .eq('stall_id', myStallId!)
        .order('sort_order'),
      supabase
        .from('menu_item')
        .select('id, stall_id, category_id, name, description, price, is_available, image_url, quick_code, parent_id')
        .order('name'),
      supabase
        .from('restaurant_table')
        .select('id, label, seats, is_active')
        .eq('stall_id', myStallId!)
        .order('sort_order')
        .order('label'),
      supabase
        .from('menu_item_image')
        .select('id, menu_item_id, url, sort_order')
        .order('sort_order'),
    ]);

  const imagesByItem = new Map<string, NonNullable<typeof images>>();
  for (const img of images ?? []) {
    const list = imagesByItem.get(img.menu_item_id) ?? [];
    list.push(img);
    imagesByItem.set(img.menu_item_id, list);
  }

  const mine = (items ?? []).filter((i) => i.stall_id === myStallId);
  const peers = (items ?? []).filter((i) => i.stall_id !== myStallId);

  return (
    <div className="space-y-8">
      <PageTitle
        subtitle="Categories and items for your stall"
        trailing={
          <div className="flex gap-3 text-sm">
            <a href="/menu/availability" className="text-surface-tint hover:underline">
              Availability
            </a>
            <a href="/menu/import" className="text-surface-tint hover:underline">
              CSV import
            </a>
          </div>
        }
      >
        Menu
      </PageTitle>

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
                  <form action={deleteCategory} className="flex flex-wrap items-center gap-1">
                    <input type="hidden" name="id" value={c.id} />
                    <Select name="reassign_to" className="h-9" defaultValue="">
                      <option value="">Reassign to…</option>
                      {(categories ?? [])
                        .filter((other) => other.id !== c.id)
                        .map((other) => (
                          <option key={other.id} value={other.id}>
                            {other.name}
                          </option>
                        ))}
                    </Select>
                    <Btn type="submit" variant="danger" className="h-9 px-2 text-xs">
                      Delete
                    </Btn>
                  </form>
                </Card>
              ))}
            </div>
          </section>

          <section>
            <SectionTitle>Items</SectionTitle>
            <MenuSearch>
              {mine.length > 0 && (
                <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-3">
                  {mine.map((i) => (
                    <a
                      key={i.id}
                      href={`#item-${i.id}`}
                      data-search={`${i.name} ${i.quick_code ?? ''}`}
                      className="block overflow-hidden rounded-lg border border-border bg-surface-container-low shadow-card transition hover:border-surface-tint"
                    >
                    {i.image_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={i.image_url}
                        alt={i.name}
                        className="aspect-square w-full object-cover"
                      />
                    ) : (
                      <div className="flex aspect-square w-full items-center justify-center bg-surface-container-highest text-xs text-on-surface-variant">
                        No img
                      </div>
                    )}
                    <div className="p-2">
                      <p className="truncate text-sm font-medium">{i.name}</p>
                      <p className="text-sm tabular-nums text-on-surface-variant">
                        ₹{Number(i.price).toFixed(2)}
                      </p>
                    </div>
                  </a>
                  ))}
                </div>
              )}
              {mine.map((i) => {
                const gallery = imagesByItem.get(i.id) ?? [];
                return (
                  <div
                    key={i.id}
                    id={`item-${i.id}`}
                    data-search={`${i.name} ${i.quick_code ?? ''}`}
                    className="scroll-mt-20"
                  >
                    <Card className="space-y-3">
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
                          name="quick_code"
                          defaultValue={i.quick_code ?? ''}
                          placeholder="Code"
                          className="h-9 w-20"
                        />
                        <Select name="parent_id" defaultValue={i.parent_id ?? ''} className="h-9">
                          <option value="">No parent (root)</option>
                          {mine
                            .filter((p) => p.id !== i.id && !p.parent_id)
                            .map((p) => (
                              <option key={p.id} value={p.id}>
                                Variant of {p.name}
                              </option>
                            ))}
                        </Select>
                        <Field
                          name="description"
                          defaultValue={i.description ?? ''}
                          placeholder="Description"
                          className="h-9 min-w-[8rem] flex-1"
                        />
                        <Select name="category_id" defaultValue={i.category_id ?? ''} className="h-9">
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
                      {gallery.length > 0 && (
                        <div className="flex flex-wrap gap-2">
                          {gallery.map((img) => (
                            <div key={img.id} className="relative">
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img
                                src={img.url}
                                alt=""
                                className="h-16 w-16 rounded-lg object-cover"
                              />
                              <form
                                action={async () => {
                                  'use server';
                                  await removeItemImage(img.id, i.id);
                                }}
                                className="absolute -right-1 -top-1"
                              >
                                <Btn
                                  type="submit"
                                  variant="danger"
                                  className="h-6 w-6 rounded-full px-0 text-xs"
                                  aria-label="Remove image"
                                >
                                  ×
                                </Btn>
                              </form>
                            </div>
                          ))}
                        </div>
                      )}
                      <div className="flex flex-wrap items-center gap-2 text-sm">
                        {gallery.length < 8 && (
                          <form action={addItemImage} className="flex items-center gap-2">
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
                              Add image
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
                    </Card>
                  </div>
                );
              })}
              {mine.length === 0 && (
                <Card className="p-0">
                  <EmptyState icon="restaurant_menu" title="No items yet">
                    Add your first item with the panel on the right.
                  </EmptyState>
                </Card>
              )}
            </MenuSearch>
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
              <Field name="quick_code" placeholder="Quick code (e.g. 21)" />
              <Select name="parent_id" className="w-full">
                <option value="">No parent (root)</option>
                {mine
                  .filter((p) => !p.parent_id)
                  .map((p) => (
                    <option key={p.id} value={p.id}>
                      Variant of {p.name}
                    </option>
                  ))}
              </Select>
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

          <Card className="mt-8">
            <SectionTitle className="mb-1">Tables</SectionTitle>
            <p className="mb-4 text-xs text-on-surface-variant">
              Offered in the POS table picker. Deactivating hides a table from new orders
              without touching past ones.
            </p>
            <form action={addTable} className="mb-4 flex gap-2">
              <input type="hidden" name="stall_id" value={myStallId} />
              <Field name="label" placeholder="T1" required className="flex-1" />
              <Field name="seats" type="number" min="1" placeholder="Seats" className="w-20" />
              <Btn type="submit">Add</Btn>
            </form>
            {!tables?.length ? (
              <p className="text-sm text-on-surface-variant">No tables yet.</p>
            ) : (
              <ul className="divide-y divide-border">
                {tables.map((t) => (
                  <li key={t.id} className="flex items-center gap-2 py-2">
                    <span
                      className={`flex-1 text-sm ${
                        t.is_active
                          ? 'text-on-surface'
                          : 'text-on-surface-variant line-through'
                      }`}
                    >
                      {t.label}
                      {t.seats != null && (
                        <span className="ml-2 text-on-surface-variant">· {t.seats}</span>
                      )}
                    </span>
                    <form
                      action={async () => {
                        'use server';
                        await setTableActive(t.id, !t.is_active);
                      }}
                    >
                      <Btn type="submit" variant="text">
                        {t.is_active ? 'Deactivate' : 'Activate'}
                      </Btn>
                    </form>
                    <form
                      action={async () => {
                        'use server';
                        await deleteTable(t.id);
                      }}
                    >
                      <Btn type="submit" variant="danger">
                        Delete
                      </Btn>
                    </form>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </aside>
      </div>
    </div>
  );
}
