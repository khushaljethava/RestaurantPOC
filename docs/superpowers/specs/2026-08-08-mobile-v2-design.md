# ROS Mobile Application v2 — Design Spec

**Date:** 2026-08-08  
**Status:** Approved (via Full Build Plan)  
**Extends:** `2026-08-05-cross-stall-pos-design.md`  
**Scope:** Flutter mobile (Android + iOS) + Supabase migrations/RPCs the app depends on. Thin admin only where mobile needs config/reports.

## 1. Problem

The shipped 13 routes cover a single happy-path transaction. Missing: shift/cash session, pickup handover, order amend, POS speed, payment integrity, discount/refund governance, shared-device PIN identity, and Realtime failure modes.

## 2. Fences (unchanged)

No KDS, printers/ESC-POS, offline DB/sync queue, inventory, CRM/loyalty, AI, franchise/white-label, customer-facing app, tax engine. Tables remain plain labels. Cart drafts on device are allowed (not business state). Variants are priced child items, not a modifier engine.

## 3. Locked product defaults

| Decision | Lock |
|---|---|
| Variants | Priced child `menu_item` via `parent_id` |
| Packaging charge | Plain amount for takeaway/parcel |
| Cart draft | `shared_preferences`, never a sync queue |
| Tokens | Bill-level customer token for pickup; keep order `token_no` for stall cards until cutover |
| Shift reports | Mobile first; thin admin in M4 |
| Card | Manual tender + last-4 + terminal label |
| Rounding | Per-stall none / ₹1 / ₹5; default ₹1 |
| Idle lock | 3 minutes |
| Languages | EN through M4; EN+HI+GU in M5 |
| Stall UI | Phone-first; 2-col on tablet width |

## 4. Architecture

```
UI → Riverpod notifiers → repositories (lib/data only knows Supabase) → services
```

- Client money math: int **paise**; DB stays `numeric(12,2)`; convert at repository boundary.
- Money writes carry client UUID idempotency keys.
- Incremental folder migration: new code in `features/` + `data/`; hot paths first.

## 5. Milestones

### M1 — Money control
- Tables: `shifts`, `cash_movements`; `staff_membership.pin_hash`; `shift_id` / `acting_staff_id` on bills/payments.
- RPCs: open/close shift, cash in/out, verify/set PIN, amend qty, void line, discount caps + approver, partial refund, rounding line.
- Mobile: `/shift`, `/shift/close`, `/lock`, `/order/:id`; shift gate on Place; change calculator; UPI UTR; PIN lock.

### M2 — Speed & handover
- `bill.token_no`, `order_type`, packaging config, `quick_code`, search/recents RPCs, pickup status, variants `parent_id`.
- Mobile: `/pickup`, `/pos/search`; POS speed layer; stall ack/alarm/keep-awake; closed-stall cart checks.

### M3 — Reliability
- Realtime channel manager + heartbeat drift; FCM lifecycle; `/notifications`; forced-update gate; telemetry hooks.

### M4 — Day close
- `/day`, `/mysales`, two-sided settlement, UPI verify list, `/audit/:billId`, thin admin shift/UPI views.

### M5 — Polish
- Receipt channels + customer QR; tables grid/merge; held policy; settings/device mode; auth completeness; l10n; shell nav.

## 6. Route target (27)

Keep existing 13 (upgraded) + add: `/lock`, `/pos/search`, `/order/:id`, `/pickup`, `/shift`, `/shift/close`, `/day`, `/mysales`, `/notifications`, `/settings`, `/settings/device`, `/audit/:billId`, `/onboarding`, `/help`.

## 7. Risks

- Bill-level token vs existing order tokens — mint bill token on `open_bill`; dual-read during transition.
- Partial refund must not delete payment history.
- PIN fast-switch stamps `acting_staff_id` without full re-auth.
- Paise on client only in M1; no DB currency type rewrite.

## 8. Acceptance (global)

Cash reconcilable per shift; wrong line voidable in ≤3 taps; pickup answers “is #N ready?”; Realtime drops visible and self-heal; day close + settlement on mobile.
