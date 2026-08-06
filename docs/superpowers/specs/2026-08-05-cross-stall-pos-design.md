# Cross-Stall POS & Settlement — Design Spec

**Date:** 2026-08-05
**Status:** Approved
**Supersedes:** the Phase 1 / DESIGN description of a single business owning many stalls, the Kitchen Display module, and waiter-owned tables.

---

## 1. Problem

A food court operates six stalls. Each has its own menu, its own item pricing, and its own owner.

During rush hours any counter collects payment for any stall's items, including one payment covering several stalls at once:

- Stall 2 takes payment for a Stall 4 item.
- Stall 1 takes a single payment covering Stall 4 and Stall 2.

Nobody can track what was sold, where it was collected, or who owes whom at close of day. Reconciliation is manual and unreliable.

**The system exists to make cross-stall sales trackable and close-of-day settlement automatic.**

---

## 2. Scope

### In scope (v1)

- Stall registration, standalone or as part of a food court group
- Menu, category, item, and price management per stall
- Staff invite codes and role assignment
- Order entry against any stall in the group
- Hold and resume orders
- Table label on orders (no table ownership or assignment)
- Bills grouping orders across stalls, with one payment
- Payment by cash, UPI, and split (Cash / UPI only)
- Digital receipt (PDF, shared via WhatsApp / SMS / email)
- Stall order screen with realtime updates and push notification
- Item availability toggles
- Settlement report per stall pair
- Sales reporting by stall, item, payment mode, and collector

### Explicitly out of scope

| Excluded | Reason |
|---|---|
| Kitchen Display System | Replaced by a single stall order screen. No stations, timers, or kitchen analytics. |
| Printer / ESC-POS integration | Receipts are digital only. No printer hardware or drivers. |
| Offline mode, local database, sync queue | Platform is online only. See §7. |
| Customer records, CRM, loyalty, wallet | Not part of the product. |
| Ingredient-level inventory | "Stock" means an availability toggle only. |
| AI, forecasting, assistants | Not part of the product. |
| Franchise / white-label SaaS | Not part of the product. |
| Table assignment, transfer, merge, waiter ownership | Tables are a label, not a managed resource. |
| Delivery, QR customer ordering, online ordering | Not part of the product. |

---

## 3. Tenancy model

**The stall is the tenant.** Each stall owner registers independently and owns their menu, prices, staff, orders, and revenue.

```
food_court (group)          invite code, group admin
     ▲  join request → approved by group admin
     │
   stall   ← THE TENANT. group_id is NULLABLE.
     │
   staff_membership   (user + stall + role)
```

A standalone single store is a stall with `group_id = NULL`. It is not a separate code path; every cross-stall feature disappears naturally because the group is empty.

A food court group is a **federation of independent owners**, not a parent company. The group owns nothing — no menus, no revenue, no staff.

### Join flows

1. **Staff joins a stall** — stall generates a code (e.g. `ABCD-4521`); staff installs the app, enters the code; stall owner approves and assigns a role.
2. **Stall joins a group** — the food court is created once and has its own invite code; a registered stall owner enters it; the group admin approves.

---

## 4. Domain model

```
stall
  ├ id, name, group_id (nullable), currency, timezone, is_open

menu_item
  ├ stall_id, category_id, name, description, image_url
  ├ price, is_available

order                        belongs to exactly ONE stall
  ├ stall_id                 whose food, whose revenue
  ├ recorded_by_stall_id     which stall's counter entered/collected it
  ├ recorded_by_user_id
  ├ bill_id (nullable)
  ├ table_label (nullable)   plain label; null for counter/takeaway
  ├ token_no
  ├ status                   pending → ready → completed | cancelled
  └ order_item[]
        └ menu_item_id, qty, unit_price, line_total, notes

bill                         the money. Groups 1..N orders across stalls.
  ├ collected_by_stall_id
  ├ collected_by_user_id
  ├ status                   open → paid | refunded
  ├ discount, total
  └ payment[]                method (cash|upi), amount
```

### Load-bearing rules

1. **An order belongs to one stall.** All cross-stall mixing happens at the bill level. There is no fan-out of items to stalls, and no per-line fulfilment status. Each stall's screen shows its own orders; the bill sits above them.

2. **`stall_id` and `recorded_by_stall_id` are independent.** They are equal for a normal same-stall sale and differ for a cross-stall sale. Both are indexed; visibility and settlement both read them.

3. **`unit_price` is copied onto the order line at entry time.** Never recalculated from the live menu. Six stalls change prices independently; recalculating would silently restate past money and corrupt historical settlement. There is no tax/GST in the system — prices are plain amounts.

4. **Fulfilment and payment are independent states.** An order may be prepared and handed to the customer before its bill is paid. This is what allows open table tabs without blocking a stall.

5. **A bill is created open and may accumulate orders** from any stall in the group until it is paid.

### Worked scenarios

| Real situation | Data |
|---|---|
| Stall 2 sells its own item | bill `collected_by = 2`; one order `stall_id = 2`, `recorded_by = 2` |
| Stall 2 takes payment for a Stall 4 item | bill `collected_by = 2`; one order `stall_id = 4`, `recorded_by = 2` |
| Stall 1 takes one payment for Stall 4 + Stall 2 | bill `collected_by = 1`; two orders, `stall_id = 4` and `stall_id = 2`, both `recorded_by = 1` |
| Table 7 accumulates all evening | one open bill; orders appended from any stall; single payment at the end |

---

## 5. Settlement

No separate bookkeeping. Settlement is derived:

- **Revenue** accrues to each order's `stall_id`.
- **Cash** accrues to the bill's `collected_by_stall_id`.

For a date range, for each ordered pair of stalls (A, B): the amount A collected on behalf of B, netted against the amount B collected on behalf of A. The result is the close-of-day sheet — who pays whom, and how much.

Refunds and cancellations reverse the corresponding lines and are included in the same derivation.

---

## 6. Roles and access

### Roles

| Role | Capability |
|---|---|
| **Owner** | Full control of their stall: menu, prices, staff, settings, reports, settlement |
| **Manager** | As owner, minus staff removal and stall/business settings |
| **Staff** | Create orders against any stall in the group, hold/resume, open bills, take payment, share receipts, toggle own stall's item availability, work the stall order screen |

Cashier and waiter are **one role**. Because any staff member serves any table and any counter may collect for any stall, they were never distinct permission sets — only different physical positions.

### Visibility

Within a group, members see each other's data in full — menus, prices, orders, sales. This was chosen deliberately for simplicity.

**Exception, and it is not optional:** `staff_membership`, invite codes, and stall settings are **stall-private**, group or not. Sharing revenue is a business decision; sharing the ability to add users to another owner's stall is an attack.

Read access summary:

| Data | Visible to |
|---|---|
| Menu, items, prices | own stall + any stall in group |
| Orders, bills, payments | own stall + any stall in group + anything `recorded_by` own stall |
| Settlement report | any pair involving own stall |
| Staff, invite codes, stall settings | **own stall only** |

### Enforcement

All rules live in **Postgres Row Level Security**, not application code. Both clients hit Supabase directly with the user's JWT, so identical rules apply to both, and a client bug cannot cross a tenant boundary.

Group resolution goes through a single SQL helper, `my_stall_ids()`, and group-read permission through one named policy, `group_member_can_read`. Narrowing transparency later (e.g. hiding revenue from competitors in the same court) is then a single-policy edit, not a migration.

---

## 7. Connectivity

The platform is **online only**. No local database, no sync queue, no offline mode.

- All reads and writes go directly to Supabase.
- Realtime subscriptions keep devices in sync.
- A connection indicator is always visible.
- While disconnected, write actions are **blocked with a clear error**, never silently queued.
- Realtime channels reconnect with backoff; in-flight writes are retried, with client-generated idempotency keys preventing duplicate orders.

Accepted trade-off: operations stop during an internet outage. The venue requires broadband plus a mobile-data fallback.

---

## 8. Architecture

| Layer | Choice |
|---|---|
| Mobile | Flutter — Riverpod, go_router, `supabase_flutter` |
| Admin web | Next.js App Router — Tailwind, shadcn/ui, TanStack Query/Table |
| Backend | Supabase — Postgres, Auth, Realtime, Storage, Edge Functions |
| Authorization | Postgres RLS + role checks |
| Push | Firebase Cloud Messaging |
| Receipts | PDF generation + `share_plus` (WhatsApp / SMS / email) |

There is **no custom API layer**. Clients use Supabase directly; RLS is the security boundary.

Edge Functions are used only for work that must not run client-side: payment webhooks, PDF receipt generation, WhatsApp/SMS dispatch, and scheduled report rollups.

Realtime: each device subscribes to `orders` filtered to `stall_id = me OR recorded_by_stall_id = me`, plus an FCM push on insert. This is the notification telling Stall 4 that Stall 1 just sold their item.

---

## 9. Applications

### Mobile (Flutter)

- **Order entry** — pick stall, search that stall's menu, cart, add/remove/edit quantity, notes
- **Hold / resume** — parked orders during rush
- **Table or counter** — enter a table label, or takeaway with token
- **Billing** — open a bill, attach orders from any stall, take payment (cash/UPI/split), share PDF receipt
- **Stall screen** — live incoming orders for your stall, push on new, Mark Complete on handover
- **Stock** — item availability toggles
- **Today** — your sales, open bills, open tables

### Admin web (Next.js)

- Stalls, menus, categories, items, prices
- Staff, invite codes, role assignment
- Group management and join approvals
- Live board — open orders and bills across the group
- **Settlement report** — per stall pair, exportable
- Sales reports — by stall, item, payment mode, collector

---

## 10. Error handling

- **Write failure or disconnection** — visible error, user retries. No partial order or payment is recorded.
- **Duplicate submission** — prevented by client-generated idempotency keys on order and payment creation.
- **Payment/order mismatch** — a bill cannot be marked paid unless payment amounts sum to its total.
- **Cancellation and refund** — never delete; write a reversing record with reason and actor, retained in the audit log.
- **Price change mid-order** — held orders keep their captured `unit_price`; the price is authoritative from entry time.
- **Device crash** — all state restored from the cloud on next launch, as nothing is held locally.

---

## 11. Testing

- **RLS policies** — the highest-risk surface. Automated tests per policy asserting a stall cannot read another stall's staff/settings, a non-group stall reads nothing, and a standalone stall (`group_id IS NULL`) is fully isolated.
- **Settlement derivation** — property tests over generated bills asserting that total revenue by `stall_id` equals total collected by `collected_by_stall_id`, and that every pairwise settlement nets to zero across the group.
- **Price capture** — a test asserting a menu price change does not alter any historical order total or settlement figure.
- **Order/bill state machine** — transition tests including pay-before-ready and ready-before-pay.
- **Flutter widget tests** on cart arithmetic (quantity, tax, discount, split payment).

---

## 12. Build sequence

Each milestone is independently usable.

**M1 — Foundation.** Supabase project, schema, RLS policies, `my_stall_ids()`. Auth, stall registration, both invite-code flows. Admin web shell with stall/menu/category/item/price CRUD.
*Outcome:* six stalls exist with real menus and prices; owners can log in.

**M2 — Single-stall ordering.** Mobile login, stall menu, cart, add/remove/edit, notes, hold/resume, token generation, order creation. Stall order screen with realtime + FCM, Mark Complete.
*Outcome:* one stall runs its own counter end to end. Testable before involving the other five.

**M3 — Cross-stall billing.** Bills grouping orders across stalls, `recorded_by_stall_id`, payment (cash/UPI/split), table labels, open tabs, digital receipt PDF + share.
*Outcome:* Stall 1 takes one payment covering Stalls 2 and 4, visible to everyone involved. **This is where the rush-hour problem stops.**

**M4 — Settlement and reporting.** Close-of-day sheet per stall pair. Sales by stall, item, payment mode, collector. Live board. Export.
*Outcome:* manual reconciliation eliminated.

**M5 — Operational polish.** Availability toggles, refunds, cancellations with reason and audit log, discounts, connection banner, role-based navigation, empty and error states.

M1–M4 is the product. M5 is what makes it survive daily use.

---

## 13. Success criteria

- A cashier at any stall can take a single payment covering items from several stalls, in under 30 seconds.
- The affected stall is notified and sees the order on its own screen within one second.
- At close of day, the settlement report states who owes whom, with no manual calculation.
- A stall owner sees every order for their stall and every order they recorded, and nothing outside their group.
- A standalone stall operates with no group and no cross-stall features visible.
- A menu price change never alters a historical total.
