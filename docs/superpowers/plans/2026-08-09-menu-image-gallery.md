# Menu Image Gallery + Grids Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Multi-image gallery per menu item (cover = first uploaded), image grids on mobile POS and admin Menu, gallery upload/delete in mobile Stock and admin.

**Architecture:** New `menu_item_image` rows + Supabase Storage paths `{stall}/{item}/{imageId}.ext`. A DB trigger keeps `menu_item.image_url` equal to the cover (`min(sort_order)`). Admin server actions and mobile `MenuItemSheet` mutate the gallery; POS/Admin list UIs only read `image_url` for tiles.

**Tech Stack:** Postgres (Supabase migrations + pgTAP), Next.js App Router server actions, Flutter (`image_picker`, `cached_network_image`), Supabase Storage `menu-images` bucket.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-09-menu-image-gallery-design.md`. Spec wins on disagreement.
- Cap **8** images per item; MIME/size already enforced by bucket (2MB, jpeg/png/webp/gif).
- Cover = lowest `sort_order`; no reorder UI / set-cover.
- POS tap = add to cart; no gallery browse on POS.
- Do not extend `menu_recents` / `search_menu_items` in this plan.
- Commit after every task. Conventional prefixes (`feat:`, `test:`, `fix:`).
- Supabase CLI: `npx supabase@2.111.0` (project convention).

---

## File Structure

```
supabase/migrations/0032_menu_item_image.sql   # table, RLS, backfill, cover trigger, max-8 trigger
supabase/tests/250_menu_item_image.sql         # migrate + cover sync + RLS allow/deny
admin/src/app/(app)/menu/actions.ts            # addItemImage / removeItemImage
admin/src/app/(app)/menu/page.tsx              # image grid + gallery controls in edit
mobile/lib/widgets/menu_item_sheet.dart        # gallery strip, multi upload/delete, camera
mobile/lib/screens/pos_screen.dart             # honor _grid with GridView tiles
```

No new packages. Storage policies from `0018_storage_and_upi.sql` already allow `{stall_id}/...` folder writes for owner/manager — nested `{stall}/{item}/{id}.ext` still has foldername[1] = stall_id.

---

### Task 1: Migration — `menu_item_image` + cover trigger + backfill

**Files:**
- Create: `supabase/migrations/0032_menu_item_image.sql`
- Create: `supabase/tests/250_menu_item_image.sql`

**Interfaces:**
- Consumes: `public.menu_item`, `public.my_group_stall_ids()`, `public.staff_membership`
- Produces: table `menu_item_image`; trigger keeps `menu_item.image_url` in sync; max 8 rows/item

- [ ] **Step 1: Write the failing pgTAP test**

Create `supabase/tests/250_menu_item_image.sql`:

```sql
begin;
select plan(7);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.local');

insert into public.food_court (id, name, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Test Court',
   '11111111-1111-1111-1111-111111111111');

insert into public.stall (id, name, group_id, created_by) values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'Stall A',
   'aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-2222-0000-0000-000000000001', 'Stall B',
   'aaaaaaaa-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222');

insert into public.staff_membership (stall_id, user_id, role) values
  ('aaaaaaaa-1111-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-2222-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222', 'owner');

insert into public.menu_item (id, stall_id, name, price, image_url) values
  ('bbbbbbbb-1111-0000-0000-000000000001',
   'aaaaaaaa-1111-0000-0000-000000000001',
   'Samosa', 40.00, 'https://example.test/samosa.jpg');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ insert into public.menu_item_image (id, menu_item_id, url, sort_order)
     values ('cccccccc-0000-0000-0000-000000000001',
             'bbbbbbbb-1111-0000-0000-000000000001',
             'https://example.test/samosa.jpg', 0) $$,
  'owner can insert gallery row'
);

select results_eq(
  $$ select image_url from public.menu_item
     where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  array['https://example.test/samosa.jpg'::text],
  'cover stays first image url'
);

select lives_ok(
  $$ insert into public.menu_item_image (id, menu_item_id, url, sort_order)
     values ('cccccccc-0000-0000-0000-000000000002',
             'bbbbbbbb-1111-0000-0000-000000000001',
             'https://example.test/samosa-2.jpg', 1) $$,
  'owner can add second image'
);

select results_eq(
  $$ select image_url from public.menu_item
     where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  array['https://example.test/samosa.jpg'::text],
  'cover remains sort_order 0 after second upload'
);

select lives_ok(
  $$ delete from public.menu_item_image
     where id = 'cccccccc-0000-0000-0000-000000000001' $$,
  'owner can delete cover image'
);

select results_eq(
  $$ select image_url from public.menu_item
     where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  array['https://example.test/samosa-2.jpg'::text],
  'cover follows remaining lowest sort_order'
);

select lives_ok(
  $$ delete from public.menu_item_image
     where menu_item_id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  'owner can delete last image'
);

select results_eq(
  $$ select image_url from public.menu_item
     where id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  array[null::text],
  'cover null when gallery empty'
);

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

-- Match 040_menu_rls.sql style: peer write "succeeds" but matches nothing / inserts 0.
select lives_ok(
  $$ insert into public.menu_item_image (menu_item_id, url, sort_order)
     values ('bbbbbbbb-1111-0000-0000-000000000001',
             'https://example.test/evil.jpg', 0) $$,
  'peer insert attempt does not error at SQL level'
);

reset role;
select results_eq(
  $$ select count(*)::int from public.menu_item_image
     where menu_item_id = 'bbbbbbbb-1111-0000-0000-000000000001' $$,
  array[0],
  'peer did not add a gallery row'
);

select * from finish();
rollback;
```

Adjust `plan(n)` if you merge/split assertions. If peer `INSERT` raises `42501` instead of no-op, switch that assertion to `throws_ok` and drop the count check as needed.

- [ ] **Step 2: Run test to verify it fails**

```bash
npx supabase@2.111.0 test db
```

Expected: `250_menu_item_image` fails because `menu_item_image` does not exist yet.

- [ ] **Step 3: Write migration**

Create `supabase/migrations/0032_menu_item_image.sql`:

```sql
-- Multi-image gallery for menu items. Cover cached on menu_item.image_url.
-- Callers: admin menu actions, mobile MenuItemSheet. Grids read image_url only.

create table public.menu_item_image (
  id            uuid primary key default gen_random_uuid(),
  menu_item_id  uuid not null references public.menu_item (id) on delete cascade,
  url           text not null,
  sort_order    int not null check (sort_order >= 0),
  created_at    timestamptz not null default now(),
  unique (menu_item_id, sort_order)
);

create index menu_item_image_item_idx on public.menu_item_image (menu_item_id);

alter table public.menu_item_image enable row level security;

create policy menu_item_image_group_can_read
  on public.menu_item_image for select
  to authenticated
  using (
    menu_item_id in (
      select i.id from public.menu_item i
      where i.stall_id in (select public.my_group_stall_ids())
    )
  );

create policy menu_item_image_own_stall_can_write
  on public.menu_item_image for all
  to authenticated
  using (
    exists (
      select 1
      from public.menu_item i
      join public.staff_membership m on m.stall_id = i.stall_id
      where i.id = menu_item_image.menu_item_id
        and m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  )
  with check (
    exists (
      select 1
      from public.menu_item i
      join public.staff_membership m on m.stall_id = i.stall_id
      where i.id = menu_item_image.menu_item_id
        and m.user_id = (select auth.uid())
        and m.role in ('owner', 'manager')
    )
  );

grant select, insert, update, delete on public.menu_item_image to authenticated;

create or replace function public.sync_menu_item_cover()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item uuid := coalesce(new.menu_item_id, old.menu_item_id);
  v_url text;
begin
  select mi.url into v_url
  from public.menu_item_image mi
  where mi.menu_item_id = v_item
  order by mi.sort_order
  limit 1;

  update public.menu_item
  set image_url = v_url
  where id = v_item;

  return coalesce(new, old);
end;
$$;

create trigger menu_item_image_sync_cover
  after insert or update or delete on public.menu_item_image
  for each row execute function public.sync_menu_item_cover();

create or replace function public.enforce_menu_item_image_cap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.menu_item_image where menu_item_id = new.menu_item_id) >= 8 then
    raise exception 'menu item image cap is 8';
  end if;
  return new;
end;
$$;

create trigger menu_item_image_cap
  before insert on public.menu_item_image
  for each row execute function public.enforce_menu_item_image_cap();

insert into public.menu_item_image (menu_item_id, url, sort_order)
select i.id, i.image_url, 0
from public.menu_item i
where i.image_url is not null
  and not exists (
    select 1 from public.menu_item_image g where g.menu_item_id = i.id
  );
```

- [ ] **Step 4: Run tests**

```bash
npx supabase@2.111.0 db reset
npx supabase@2.111.0 test db
```

Expected: all green including `250_menu_item_image.sql`.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/0032_menu_item_image.sql supabase/tests/250_menu_item_image.sql
git commit -m "$(cat <<'EOF'
feat: add menu_item_image gallery with cover sync

Backfill legacy image_url rows and keep menu_item.image_url as cover cache.
EOF
)"
```

---

### Task 2: Admin server actions — add / remove gallery image

**Files:**
- Modify: `admin/src/app/(app)/menu/actions.ts` (replace `uploadItemImage` / `clearItemImage`)
- Modify: `admin/src/app/(app)/menu/page.tsx` (imports) — prefer committing with Task 3 if `tsc` breaks

**Interfaces:**
- Consumes: `menu_item_image`, storage `menu-images`, cover trigger
- Produces:
  - `addItemImage(formData: FormData): Promise<void>` — fields `stall_id`, `item_id`, `image` (File)
  - `removeItemImage(imageId: string, itemId: string): Promise<void>`

- [ ] **Step 1: Replace upload helpers**

In `actions.ts`, replace `uploadItemImage` and `clearItemImage` with:

```typescript
const MAX_IMAGES = 8;

async function nextSortOrder(
  supabase: Awaited<ReturnType<typeof createClient>>,
  itemId: string,
): Promise<number> {
  const { data } = await supabase
    .from('menu_item_image')
    .select('sort_order')
    .eq('menu_item_id', itemId)
    .order('sort_order', { ascending: false })
    .limit(1)
    .maybeSingle();
  return (data?.sort_order ?? -1) + 1;
}

export async function addItemImage(formData: FormData) {
  const supabase = await createClient();
  const stallId = String(formData.get('stall_id'));
  const itemId = String(formData.get('item_id'));
  const file = formData.get('image');
  if (!(file instanceof File) || file.size === 0) {
    throw new Error('image required');
  }

  const { count } = await supabase
    .from('menu_item_image')
    .select('id', { count: 'exact', head: true })
    .eq('menu_item_id', itemId);
  if ((count ?? 0) >= MAX_IMAGES) {
    throw new Error('max 8 images per item');
  }

  const imageId = crypto.randomUUID();
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '') || 'jpg';
  const path = `${stallId}/${itemId}/${imageId}.${ext}`;
  const buf = Buffer.from(await file.arrayBuffer());
  const { error: upErr } = await supabase.storage
    .from('menu-images')
    .upload(path, buf, { contentType: file.type || 'image/jpeg', upsert: false });
  if (upErr) throw new Error(upErr.message);

  const { data: pub } = supabase.storage.from('menu-images').getPublicUrl(path);
  const sortOrder = await nextSortOrder(supabase, itemId);
  const { error } = await supabase.from('menu_item_image').insert({
    id: imageId,
    menu_item_id: itemId,
    url: `${pub.publicUrl}?v=${Date.now()}`,
    sort_order: sortOrder,
  });
  if (error) {
    await supabase.storage.from('menu-images').remove([path]);
    throw new Error(error.message);
  }
  revalidatePath('/menu');
}

export async function removeItemImage(imageId: string, itemId: string) {
  const supabase = await createClient();
  const { data: row } = await supabase
    .from('menu_item_image')
    .select('id, url, sort_order')
    .eq('id', imageId)
    .eq('menu_item_id', itemId)
    .maybeSingle();
  if (!row) throw new Error('image not found');

  const marker = '/menu-images/';
  const idx = row.url.indexOf(marker);
  if (idx >= 0) {
    const path = row.url.slice(idx + marker.length).split('?')[0];
    await supabase.storage.from('menu-images').remove([path]);
  }

  const { error: delErr } = await supabase
    .from('menu_item_image')
    .delete()
    .eq('id', imageId);
  if (delErr) throw new Error(delErr.message);

  const { data: rest } = await supabase
    .from('menu_item_image')
    .select('id')
    .eq('menu_item_id', itemId)
    .order('sort_order');
  for (let i = 0; i < (rest ?? []).length; i++) {
    await supabase
      .from('menu_item_image')
      .update({ sort_order: i + 1000 })
      .eq('id', rest![i].id);
  }
  for (let i = 0; i < (rest ?? []).length; i++) {
    await supabase
      .from('menu_item_image')
      .update({ sort_order: i })
      .eq('id', rest![i].id);
  }
  revalidatePath('/menu');
}
```

- [ ] **Step 2: Typecheck** (may fail until page imports updated — finish with Task 3 in same commit if needed)

```bash
cd admin && npx tsc --noEmit
```

- [ ] **Step 3: Commit** (with Task 3 if imports break)

```bash
git add admin/src/app/(app)/menu/actions.ts
git commit -m "feat: admin gallery add/remove image actions"
```

---

### Task 3: Admin Menu UI — image grid + gallery controls

**Files:**
- Modify: `admin/src/app/(app)/menu/page.tsx`

**Interfaces:**
- Consumes: `addItemImage`, `removeItemImage`; select `menu_item_image`
- Produces: responsive cover grid for `mine`; edit form gallery thumbs

- [ ] **Step 1: Load gallery rows**

```typescript
const [{ data: categories }, { data: items }, { data: tables }, { data: images }] =
  await Promise.all([
    // existing category / items / tables queries unchanged
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
```

- [ ] **Step 2: Cover grid for own items**

Replace the dense card list of `mine` with a responsive image grid (`grid-cols-2 sm:grid-cols-3`), each tile showing `image_url` (or “No img”), name, price; link/anchor to `#item-${id}` edit block below. Use existing `Btn` / surface tokens — no new theme.

- [ ] **Step 3: Gallery controls in edit form**

Replace `uploadItemImage` / `clearItemImage` UI with thumbs from `imagesByItem.get(i.id)`, per-image `removeItemImage`, and `addItemImage` file form when `gallery.length < 8`.

- [ ] **Step 4: Manual check**

```bash
cd admin && npm run dev
```

Open `/menu`: grid; add/delete images; cover updates.

- [ ] **Step 5: Commit**

```bash
git add admin/src/app/(app)/menu/page.tsx admin/src/app/(app)/menu/actions.ts
git commit -m "feat: admin menu image grid and gallery upload"
```

---

### Task 4: Mobile Stock — gallery in `MenuItemSheet`

**Files:**
- Modify: `mobile/lib/widgets/menu_item_sheet.dart`

**Interfaces:**
- Consumes: `menu_item_image`, storage `{stall}/{item}/{imageId}.ext`, cover trigger
- Produces: gallery strip; gallery + camera pick; delete; max 8

- [ ] **Step 1: State for gallery**

```dart
static const _maxImages = 8;
List<Map<String, dynamic>> _images = [];
final _pending = <XFile>[];

Future<void> _loadImages() async {
  if (widget.existing == null) return;
  final rows = await Supabase.instance.client
      .from('menu_item_image')
      .select('id, url, sort_order')
      .eq('menu_item_id', widget.existing!['id'] as String)
      .order('sort_order');
  if (!mounted) return;
  setState(() => _images = List<Map<String, dynamic>>.from(rows));
}
```

Call via `addPostFrameCallback` in `initState`.

- [ ] **Step 2: Multi upload helpers**

Replace single-path `_uploadImage` with uploads to `${stallId}/$itemId/$imageId.$ext`, insert `menu_item_image` with next `sort_order`. Do not update `menu_item.image_url` (trigger). Generate UUID with existing `uuid` package if in `pubspec.yaml`, else small `_uuidV4()` helper using `Random.secure()`.

- [ ] **Step 3: Delete + re-pack**

Delete storage object (best-effort), delete row, re-pack `sort_order` with temp `i+1000` then `i` (same as admin). Reload gallery. Remove `_clearImage` that only nulls `image_url`.

- [ ] **Step 4: UI**

Horizontal thumbs for `_images` + `_pending`; add gallery / camera buttons; `{count}/8` label.

- [ ] **Step 5: Analyze**

```bash
cd mobile && dart analyze lib/widgets/menu_item_sheet.dart
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/widgets/menu_item_sheet.dart
git commit -m "feat: mobile menu item multi-image gallery"
```

---

### Task 5: Mobile POS — honor `_grid` with image tiles

**Files:**
- Modify: `mobile/lib/screens/pos_screen.dart` (~line 676 `ListView.separated`)

**Interfaces:**
- Consumes: `_grid`, menu rows with `image_url`
- Produces: `GridView` when `_grid`; existing list otherwise; tap → `CartLine`

- [ ] **Step 1: Branch UI on `_grid`**

When `_grid` is true, use `GridView.builder` (`crossAxisCount: 2`, image-forward tile, name + `MoneyText`, `CachedNetworkImage` / `_thumbFallback`). `onTap` uses the same `CartLine` add as the list. When false, keep current `ListView.separated` unchanged.

Use colors/widgets already in the file (`RosColors`, etc.).

- [ ] **Step 2: Analyze**

```bash
cd mobile && dart analyze lib/screens/pos_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Manual check** — toggle grid; tiles show covers; tap adds; list mode OK.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/screens/pos_screen.dart
git commit -m "feat: POS menu image grid mode"
```

---

### Task 6: Final verification

**Files:** none new (confirm Task 1 test covers empty → null)

- [ ] **Step 1: Run full db tests**

```bash
npx supabase@2.111.0 test db
```

Expected: PASS.

- [ ] **Step 2: Admin + mobile analyze**

```bash
cd admin && npx tsc --noEmit
cd ../mobile && dart analyze lib/widgets/menu_item_sheet.dart lib/screens/pos_screen.dart
```

Expected: clean.

---

## Spec coverage (self-review)

| Spec requirement | Task |
| --- | --- |
| `menu_item_image` + unique sort_order | 1 |
| RLS owner/manager write, group read | 1 |
| Cover via `image_url` sync | 1 (trigger) |
| Backfill legacy `image_url` | 1 |
| Storage `{stall}/{item}/{id}.ext` | 2, 4 |
| Cap 8 | 1 + 2/4 |
| Admin add/remove + grid | 2, 3 |
| Mobile Stock gallery + camera | 4 |
| POS grid, tap = cart | 5 |
| Last delete → null cover | 1 |
| Out of scope (recents RPC, reorder, POS gallery) | not scheduled |

No TBD placeholders. Re-pack temp offset `+1000` is consistent in admin and mobile. Clients must not write `image_url` directly after gallery exists.
