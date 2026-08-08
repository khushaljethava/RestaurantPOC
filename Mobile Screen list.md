# Mobile Application — Screen List

# Restaurant Operating System (ROS)

> **Authoritative scope:** `docs/superpowers/specs/2026-08-05-cross-stall-pos-design.md`
>
> No inventory, CRM, loyalty, AI, franchise, printers, offline mode, or GST/tax.
> "Stock" = availability plus item add/edit — not quantities. Receipts are
> digital (PDF/share). Prices are plain amounts.

## Overview

The Mobile Application is the primary operational tool during service: order entry,
stall kitchen queue, tables, payment, and receipts.

Roles:

- Owner (stall tenant)
- Manager
- Staff (cashier and waiter are one role)

---

# Shipped screens (17 routes)

| Route | Screen | Status |
|-------|--------|--------|
| `/login` | Login / Sign up | Shipped |
| `/join` | Redeem stall invite code | Shipped |
| `/` | Home (role-aware tiles + stall switcher) | Shipped |
| `/pos` | New order (cross-stall menu, cart, notes, hold/place) | Shipped |
| `/held` | Held orders / resume | Shipped |
| `/stall` | Stall order screen (Realtime, ready/complete) | Shipped |
| `/stock` | Menu — availability, add/edit item, image upload | Shipped |
| `/tables` | Tables — registered + occupied | Shipped |
| `/manage/tables` | Manage tables (add/rename/deactivate) | Shipped |
| `/manage/stall` | Stall settings — name, open/closed, UPI VPA | Shipped |
| `/manage/group` | Food court — join, approve/reject, leave | Shipped |
| `/reports` | Sales by item / payment mode / collector / stall | Shipped |
| `/table/:label` | Table bill (add items / settle) | Shipped |
| `/today` | Open bills + today's orders / cancel | Shipped |
| `/settlement` | Settlement summary (owner/manager) | Shipped |
| `/checkout/:billId` | Discount + pay (cash / UPI QR / card / split) | Shipped |
| `/receipt/:billId` | Receipt, PDF share/preview, refund | Shipped |

---

# Module breakdown

## 1. Authentication

- Login
- Sign up
- Invite code (`/join`) — also reachable from the Home app bar
- Stall switcher on Home (when multiple memberships)
- Logout (Home app bar)

Not shipped: splash, OTP, forgot password, camera QR scan (code entry only).

---

## 2. Home / Today

- Home — shortcuts by role; active stall picker
- Today — open bills, today's orders, cancel with reason
- Connection banner when offline (writes blocked)
- Push registration — an FCM token is registered for the active stall on Home
  load and on stall switch; new-order pushes come from the `notify-new-order`
  Edge Function. Both no-op when Firebase/FCM is not configured, leaving
  Realtime as the delivery path.

Not shipped: in-app notification centre or history — a push opens the app, it
does not populate a list.

---

## 3. Order taking (POS)

- New order
- Stall chips (menus from peer stalls in same food court)
- Menu list with optional image thumbnails
- Add / quantity
- Line notes (note icon / long-press on cart line)
- Cart
- Hold (own-stall items only)
- Place → checkout (no table) or accumulate on table label
- Optional table label field

Not included: modifiers, favorites, coupons, customer lookup, merge/split, search UI.

---

## 4. Tables

- Registered tables (`restaurant_table`: label, seats, active) managed on
  `/manage/tables`, or on the web admin's Menu page
- `/tables` merges registered tables with any label currently holding unbilled
  orders — a free table opens the POS on that label, an occupied one opens its
  tab
- Table bill (orders on that label)
- Add more items → POS with `?table=`
- Settle → open bill → checkout

`orders.table_label` stays free text with no FK: a label typed ad-hoc still
works, and renaming or deleting a table never rewrites past receipts.

Not included: floor plan, reservations, waiter assignment, merge/split/transfer.

---

## 5. Stall order screen

- Incoming pending orders (own stall, Realtime)
- Mark Ready / Mark Complete
- Shows line notes when present

No Kitchen Display System, stations, timers, or printers.

---

## 6. Held / orders

- Held list + resume
- Today list + cancel (reason)
- Jump to checkout for open bills

---

## 7. Billing & payments

- Checkout — discount
- Cash
- UPI QR (from stall `upi_vpa` / payee; staff confirms received)
- Card amount entry (no terminal SDK)
- Split (amounts must sum to due)
- Receipt screen — PDF share / preview, refund

No payment gateway verification, no printers.

---

## 8. Menu

- Toggle `is_available` per menu item (own stall)
- Add / edit item: name, price, category, availability (owner/manager)
- Item photo: pick from gallery, uploaded to the `menu-images` bucket at
  `<stall_id>/<item_id>.<ext>` — the same object the web admin writes
- Items grouped under category headers; category chips filter the POS menu

Categories themselves are created and ordered on the web admin; mobile only
assigns an item to an existing one.

Not inventory: no quantities, recipes, purchases, low-stock alerts.

---

## 9. Settlement and reports

- Today's settlement pairs
- Reports (`/reports`): revenue and order count, top items, payment methods,
  collected-by, and by-stall, over today / 7 days / 30 days

The Home tile is shown only to owner/manager; the real boundary is the
`settlement_pairs` RPC, which returns pairs involving the caller's own stalls.

CSV export and long-range analysis stay on admin web.

---

# Role access

| Module | Owner | Manager | Staff |
|--------|:----:|:------:|:-----:|
| Home / POS / Tables / Stall screen | ✅ | ✅ | ✅ |
| Billing / receipts | ✅ | ✅ | ✅ |
| Item availability (own stall) | ✅ | ✅ | ✅ |
| Settlement / reports | ✅ | ✅ | ❌ |
| Menu editing, tables, stall + UPI settings | ✅ | ✅ | ❌ |
| Food court (join / approve / leave) | ✅ | ❌ | ❌ |
| Staff invites, categories, stall onboarding | ❌ (admin web) | ❌ (admin web) | ❌ |

---

# UI building blocks

- Category chips (POS) / stall chips
- Product tiles (optional image)
- Cart + note dialog
- Payment sheet
- Receipt / PDF preview
- Connection status banner
- Stall switcher dropdown
- Menu item sheet (name, price, category, photo)

Not included: barcode scanners, offline queue, printer drivers.

---

# Design goals

- One-handed, rush-hour speed (&lt;30s order)
- Always online — banner + blocked writes when disconnected
- Errors are mapped to plain language (`services/errors.dart`), never raw
  `PostgrestException` text
- Realtime stall queue
- Digital receipts only
- No GST/tax, inventory, CRM, AI, or franchise surfaces
