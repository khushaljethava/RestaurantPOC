# Admin Web Portal — Screen List

# Restaurant Operating System (ROS)

> **Authoritative scope:** `docs/superpowers/specs/2026-08-05-cross-stall-pos-design.md`
>
> Permanently out of scope: inventory, CRM/loyalty, AI, franchise/white-label,
> printers, offline mode, Kitchen Display System, GST/tax.
>
> Prices are plain amounts. Receipts are digital only.

## Overview

The Admin Web Portal is the **setup and truth** surface. It is not used during service —
the mobile app handles ordering and payment.

Used by:

- Stall Owner
- Manager
- Food Court Group Admin (join approvals)

---

# Shipped screens (10 routes + shell)

| Route | Screen | Status |
|-------|--------|--------|
| `/login` | Login / Sign up | Shipped |
| `/onboarding` | Register stall (name only) | Shipped |
| `/` | Dashboard (today revenue, open bills, settlement owed) | Shipped |
| `/live` | Live board (open bills + pending/ready orders, Realtime) | Shipped |
| `/settlement` | Settlement pairs + drill-down + CSV export | Shipped |
| `/reports` | Sales by stall / item / payment mode / collector + CSV | Shipped |
| `/menu` | Categories, items, images, availability, peer menus | Shipped |
| `/staff` | Invite codes, members, roles, redeem invite | Shipped |
| `/group` | Create/join food court, invites, approve/reject, leave | Shipped |
| `/settings` | Stall profile, open/closed, UPI VPA (owner only) | Shipped |
| Shell | Sidebar + **stall switcher** (multi-membership) | Shipped |

No separate OTP, forgot-password, alerts, activity feed, order browser, or bill browser routes.

---

# Module breakdown (what each screen covers)

## 1. Authentication & Onboarding

- Login (email/password)
- Sign up
- Register stall (creates the tenant)

Not shipped: OTP/phone, forgot/reset password.

---

## 2. Dashboard & Live

- Home — today's sales, open-bill count, net owed
- Live board — open bills and active orders across the group (Realtime)

Not shipped: alerts center, activity feed.

---

## 3. Stall & Food Court

- Stall switcher (cookie `active_stall_id`)
- Food court create / join / leave
- Group invite codes (generate)
- Join requests (approve / reject)
- Settings — name, currency, timezone, open/closed, UPI VPA + payee

Not shipped: logo upload, stall list/detail as separate pages, revoke group invite UI.

---

## 4. Menu

- Category list / add / rename / reorder
- Item add / edit / delete / duplicate
- Image upload / clear (`menu-images` storage)
- Availability toggle (per item)
- Peer food-court menus (read-only)

Not shipped: search/filter, SKU/barcode UI, bulk price, CSV import/export, category delete.

Prices are edited only here. `unit_price` is snapshotted on order lines — no tax/GST fields.

---

## 5. Staff

- Staff list for active stall
- Invite code (generate, revoke)
- Redeem invite code (join another stall)
- Change role / remove member (owner)

Not shipped: staff detail page, per-staff activity log.

**Stall-private.** Group members cannot see another stall's staff or invites.

---

## 6. Settlement

- Summary (who owes whom, date range)
- Detail drill-down (bills/orders behind a pair)
- CSV export

Windows are keyed on `bill.paid_at` / `bill.refunded_at`, so a past period's
numbers stay put when a bill is refunded later; the refund books as a negative
in the period it happened.

Not shipped: PDF/Excel, mark-settled ledger, separate history page.

---

## 7. Reports

- Sales by stall
- Sales by item
- Sales by payment mode
- Sales by collector
- CSV export per section

Not shipped: charts, cancellations/refunds report, staff performance report.

---

# Intentionally not on admin (mobile owns these)

- Taking orders / holding / stall kitchen queue
- Taking payment / refunds / discounts / receipts
- Table labels / open tabs

---

# Role access

| Module | Owner | Manager | Staff |
|--------|:----:|:------:|:-----:|
| Dashboard / Live / Reports / Settlement | ✅ | ✅ | ✅ (read; settlement useful for managers) |
| Menu | ✅ | ✅ | ❌ (RLS; no admin UX for staff) |
| Staff list | ✅ | View | View |
| Staff invites / role changes / remove | ✅ | ❌ | ❌ |
| Food court create / leave / approve | ✅ | ❌ | ❌ |
| Settings | ✅ | ❌ | ❌ |

The sidebar hides **Settings** for non-owners; every other link is shown to all
members and the data itself is bounded by RLS. Invite generation, role changes
and member removal are owner-only controls inside `/staff`, and redeeming an
invite code is available to anyone.

---

# UI building blocks in use

- App shell (sidebar + stall switcher)
- Forms and simple tables
- Date range on settlement/reports — day boundaries follow the active stall's
  `timezone`, not the server's, so "today" matches the token counter
- Image uploader (menu items)
- CSV download
- Realtime live board

Not in product: charts library, printers, offline indicator on web.

---

# Relationship to mobile

| Concern | Web | Mobile |
|---------|:---:|:------:|
| Take an order / payment | ❌ | ✅ |
| Mark ready / complete | ❌ | ✅ |
| Menu & prices | ✅ | ❌ |
| Staff & invites | ✅ | Redeem only |
| Food court | ✅ | ❌ |
| Settlement | ✅ (full + CSV) | Summary |
| Reports | ✅ | Today list only |

---

# Design goals

- Data density over visual flourish
- Settlement drills to source bills
- Realtime on live board
- Digital receipts only (no printers)
- No GST/tax, inventory, CRM, AI, or franchise surfaces
