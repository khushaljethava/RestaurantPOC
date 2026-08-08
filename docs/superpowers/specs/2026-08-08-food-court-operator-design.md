# Food court operator: multi-court tenancy

**Date:** 2026-08-08
**Status:** Approved, in implementation
**Scope:** Spec 1 of 3 — tenancy foundation and roster management.

## Problem

There is no such thing as a food court operator. `food_court` (`0002_tenancy.sql:3`)
has a `name` and a `created_by` and nothing else — no membership table, no roles.
Every path into a court runs through a stall you own:

- `/group` resolves the **active stall**, reads `stall.group_id`, and renders that one
  court. Managing a second court means owning a stall in it and flipping the
  `active_stall_id` cookie.
- `create_group_invite`, `approve_join_request`, `reject_join_request` and
  `leave_group` all authorize as "owner of *some* stall in this group". Every stall
  owner in a court therefore holds full admin power over it.
- No one can remove a stall from a court. Only the stall itself can `leave_group`.
- There is zero court-level logic anywhere: `0015_settlement.sql` never mentions
  `group_id`, and the settlement, live and reports pages never mention courts. A food
  court today is a label plus invite codes. It grants nothing and aggregates nothing.

A landlord running several courts, owning no stalls in any of them, cannot use this
system at all.

## Target capabilities

Agreed with the user: manage the tenant roster, see live operations across stalls, see
revenue across stalls. **Not** rent or commission billing.

Delivered across three specs, in this order — the last two are read-only views that
cannot exist without the first:

1. **This spec.** Membership table, RLS, backfill, onboarding fork, `/courts`, roster
   management.
2. Court live board.
3. Court revenue.

## Design

### Tenancy model

A new `food_court_membership` table mirroring `staff_membership`:

```sql
create table public.food_court_membership (
  id            uuid primary key default gen_random_uuid(),
  food_court_id uuid not null references public.food_court (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  role          text not null check (role in ('owner', 'manager')),
  created_at    timestamptz not null default now(),
  unique (food_court_id, user_id)
);
```

`manager` is permitted by the constraint but not yet surfaced in the UI, which only
creates owners. Allowing the value now costs nothing and avoids a constraint migration
later.

**Rejected alternatives.** Reusing `staff_membership` with a nullable `stall_id` means
re-auditing every policy that reads it for rows with no stall, and `my_stall_ids()` is
load-bearing in `0004`, `0008` and `0012`. Giving the operator a `staff_membership` row
on each tenant stall needs no schema change but grants full write access to tenant
stalls — a landlord could edit a tenant's menu or void their bills.

### Helpers

Three new functions alongside the existing `my_stall_ids()` / `my_group_stall_ids()`,
all `security definer` with `set search_path = ''`, for the recursion and
schema-shadowing reasons documented in `0003_helpers.sql`:

- `my_food_court_ids()` — courts the caller operates.
- `is_court_owner(p_group_id uuid)` — for use inside RLS policies without recursion.
- `my_court_stall_ids()` — stalls belonging to courts the caller operates. The basis
  for operator reads, and **only** for reads.

### RLS

**`my_stall_ids()` is not modified.** Every write policy in the system routes through
it; folding court access in would silently grant operators write access to every
tenant stall. Operator visibility arrives instead as new policies that are
`for select` only:

| Table | New operator policy |
| --- | --- |
| `food_court` | select where `id in my_food_court_ids()` |
| `food_court_membership` | select own rows, and rows of courts the caller operates |
| `stall` | select where `id in my_court_stall_ids()` |
| `group_invite` | select/insert where `group_id in my_food_court_ids()` |
| `group_join_request` | select and update where `group_id in my_food_court_ids()` |

Operators get no insert, update or delete on `stall`, and nothing at all on
`staff_membership` — a landlord must not see or alter a tenant's staff roster.

### RPC changes

Authorization for `create_group_invite`, `approve_join_request` and
`reject_join_request` moves from "owner of a stall in the group" to
`is_court_owner(group_id)`.

New RPCs, all `security definer`, all gated on `is_court_owner`:

- `create_court(p_name text) returns uuid` — creates a court with no stall and makes
  the caller its owner. The existing `create_food_court(name, stall_id)` stays for
  stall owners bootstrapping a court around their own stall, and additionally inserts
  the creator into `food_court_membership`.
- `rename_court(p_group_id uuid, p_name text)`
- `remove_stall_from_court(p_group_id uuid, p_stall_id uuid)` — sets
  `stall.group_id = null`. Today only the stall itself can leave.

### Backfill

```sql
insert into public.food_court_membership (food_court_id, user_id, role)
select id, created_by, 'owner' from public.food_court
on conflict do nothing;
```

**This is a permission removal.** Today any stall owner in a court can approve joins
and mint invites; afterwards only the backfilled creator can. That is the intended
model, but it changes behavior for existing users.

### Admin routing

URL-based, not another active-context cookie. Handling multiple courts is the whole
point; a second cookie beside `active_stall_id` would force a single current court,
require a switcher, and break the back button.

- `/courts` — courts the caller operates, plus "Create food court".
- `/courts/[id]` — one court: roster, pending join requests, invite codes, rename.
  A single overview page. Tabs are premature until specs 2 and 3 add the live board
  and revenue views.

Two nav entries, each rendered only when it applies. They are different roles:

- **Food Court** (`/group`) — my stall's court: join, leave, see peers. Unchanged.
- **Food Courts** (`/courts`) — courts I operate. New.

### No-stall users

Two things break for a user who operates a court but owns no stall:

- `resolveActiveStall` throws `no memberships`. The `(app)` layout, sidebar and topbar
  must tolerate a stall-less session and hide stall-scoped navigation.
- `(app)/layout.tsx` redirects to `/onboarding` whenever `staff_membership` is empty,
  which would lock operators out permanently. The redirect must also consider
  `food_court_membership`, and `/onboarding` needs an "I run a food court" fork calling
  `create_court`.

An operator with no stalls lands on `/courts`.

## Error handling

| Case | Behavior |
| --- | --- |
| Non-operator opens `/courts/[id]` | RLS returns no rows; page renders not-found. |
| Last operator removed from a court | Blocked, mirroring `changeRole`'s last-owner guard in `staff/actions.ts`. |
| Remove a stall that has open bills | Allowed. `group_id` is a grouping label; bills are stall-private and unaffected. |
| Operator tries to write tenant data | No policy grants it; the write fails. |
| Court deleted | `on delete cascade` clears memberships; `stall.group_id` is `on delete set null`, so tenants become standalone. |

## Testing

pgTAP, following the existing `supabase/tests/` convention, as `180_court_operator.sql`:

1. An operator with no stalls can create a court and is its owner.
2. An operator sees tenant stalls via `my_court_stall_ids()`.
3. An operator **cannot** update a tenant stall — the read/write split holds.
4. An operator cannot read tenant `staff_membership`.
5. A stall owner who is not a court operator can no longer mint group invites.
6. `remove_stall_from_court` nulls `group_id` and is refused for non-operators.

## Out of scope

- Court live board and court revenue — specs 2 and 3.
- Rent and commission billing.
- Tenant consent for revenue visibility. Opening tenant takings to a landlord is a
  policy decision the user accepted; there is deliberately no consent flow.
- Mobile. `mobile/lib/screens/group_screen.dart` keeps the stall-owner view; there is
  no operator UI on mobile.
