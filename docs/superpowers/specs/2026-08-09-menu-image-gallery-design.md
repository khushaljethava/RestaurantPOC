# Menu image gallery + grids (POS + Admin)

**Date:** 2026-08-09  
**Status:** Approved, ready for implementation planning  
**Scope:** Multi-image gallery per menu item; image grids on mobile POS and admin Menu; upload/manage gallery in mobile Stock and admin Menu.

## Problem

Menu items already support a single `image_url` with uploads in admin (`/menu`) and mobile Stock (`MenuItemSheet`), stored in the public Supabase `menu-images` bucket. Gaps:

1. Mobile POS has a list/grid toggle (`pos_grid`) but always renders a list — grid mode is stubbed.
2. Admin Menu is a text-heavy card list with tiny thumbs, not an image grid.
3. Only one image per item; no gallery.

## Decisions (locked)

| Topic | Choice |
| --- | --- |
| Where grids appear | Both POS and Admin |
| Image model | `menu_item_image` table (not `text[]`) |
| Cover | First uploaded = cover (`sort_order` lowest); no explicit “set cover” |
| POS tap | Add to cart; cover only on tile; no gallery browse |
| Cap | 8 images per item; existing bucket MIME/size (2MB, jpeg/png/webp/gif) |

## Out of scope

- Reorder UI / “set as cover”
- POS swipeable gallery preview
- CSV import images
- Extending `menu_recents` / `search_menu_items` RPCs with `image_url` (follow-up if Recents need thumbs)
- Deleting orphaned storage objects from pre-migration single-file paths beyond the migrate script’s care

## Design

### 1. Schema

New table:

```sql
create table public.menu_item_image (
  id            uuid primary key default gen_random_uuid(),
  menu_item_id  uuid not null references public.menu_item (id) on delete cascade,
  url           text not null,
  sort_order    int not null check (sort_order >= 0),
  created_at    timestamptz not null default now(),
  unique (menu_item_id, sort_order)
);
```

RLS: same stall ownership pattern as `menu_item` (owner/manager write; authenticated read as needed for clients). Public consumption continues via public storage URLs.

**Cover cache:** keep `menu_item.image_url`. After any gallery mutate, set it to the URL of the row with `min(sort_order)`, or `null` if none. List/POS/Admin grids keep reading one field.

**Migration of existing data:** for every `menu_item` with non-null `image_url`, insert one `menu_item_image` with `sort_order = 0` and that URL. Do not re-upload or rewrite storage paths for legacy singles (`{stall}/{item}.{ext}` remains valid until replaced).

Next migration number after current latest: `0032_…`.

### 2. Storage paths

| Kind | Path |
| --- | --- |
| Legacy (unchanged) | `{stall_id}/{menu_item_id}.{ext}` |
| New gallery images | `{stall_id}/{menu_item_id}/{image_id}.{ext}` |

Bucket remains `menu-images`. Upload with upsert false for new ids; delete object when deleting a gallery row.

### 3. Write flow (admin server actions + mobile client)

Shared semantics:

1. **Add:** refuse if count ≥ 8. Insert row (prefer: generate `id`, upload to path, insert row with final public URL + `sort_order = coalesce(max+1,0)`). Sync cover.
2. **Delete:** remove storage object (best-effort if missing), delete row, re-pack `sort_order` to `0..n-1`, sync cover.
3. **Replace single-image UX:** remove old “one file overwrites same path” behavior for gallery items; first image remains cover without reordering.

Failed storage upload → no lasting orphan row (delete row or never insert). Surface clear errors for size/MIME/cap.

Admin: extend `uploadItemImage` / `clearItemImage` into gallery add/remove (or replace with `addItemImage` / `removeItemImage`). Mobile: extend `MenuItemSheet` gallery strip (gallery + camera pick).

### 4. UI

**Mobile POS (`pos_screen.dart`)**  
- When `_grid` is true: `GridView` of image-forward tiles using `image_url` (cover), name + price; tap → existing add-to-cart.  
- When false: keep current list.  
- Toggle already persists `pos_grid`.

**Mobile Stock**  
- `MenuItemSheet`: horizontal gallery of thumbs; add / delete; show count toward 8.

**Admin Menu (`menu/page.tsx`)**  
- Responsive CSS grid of cover tiles (image, name, price); click/edit opens existing edit form.  
- Form section: multi-image thumbs + file input(s); remove per image.  
- Create flow: create item first, then allow uploads (same as needing an id for storage path).

### 5. Testing / self-check

One small runnable check (assert script or unit):

1. Given a menu item with legacy `image_url`, after migrate helper/logic: exactly one `menu_item_image` at `sort_order = 0` and cover matches.  
2. After deleting the last gallery image: `menu_item.image_url` is null.

## Files likely touched

- `supabase/migrations/0032_menu_item_image.sql` (name may vary)
- `admin/src/app/(app)/menu/actions.ts`, `page.tsx`
- `mobile/lib/screens/pos_screen.dart`
- `mobile/lib/widgets/menu_item_sheet.dart`

## Success criteria

- POS grid toggle shows image tiles; list mode unchanged.
- Admin Menu is an image grid; edit still works.
- Owner/manager can add up to 8 images and remove them on Stock and Admin.
- Cover always equals first-uploaded remaining image (`sort_order` 0 after re-pack).
- Existing single images still appear after migration.
