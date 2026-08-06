# Mobile Stitch UI Parity Design

**Date:** 2026-08-06  
**Source:** `stitch_indian_street_stall_pos/` + Efficient Vendor Service tokens  
**Scope:** Visual restyle of the Flutter mobile app (approach B). No backend or RPC changes.

## Goals

- Match stitch Material 3 green operational UI across all shipped routes.
- Add bottom navigation shell for Register / Orders / History / Reports.
- Split sign-up into `/signup`.
- Keep existing Riverpod providers, Supabase calls, and go_router business paths.

## Out of scope

- Dark theme
- Camera QR / OTP / splash
- New features beyond `/signup` and bottom nav
- Pixel-perfect HTML port (Flutter reimplementation of the look)

## Theme tokens

| Token | Hex |
|-------|-----|
| Primary | `#00513E` |
| Primary container | `#156B54` |
| Background / surface | `#F5FBF5` |
| Surface container | `#E9EFEA` |
| On surface | `#171D1A` |
| On surface variant | `#3F4944` |
| Outline | `#BEC9C3` |
| Error | `#BA1A1A` |
| Paid / ready | `#1B6C3D` |
| Pending / held | `#8A5300` on `#FFF0D4` |

Typography: Roboto (Material default). Titles 24, section 16 medium, body 16, secondary 14, caption 11. Money uses tabular figures, right-aligned.

Shapes: cards/rows 12px, inputs/small buttons 8px, sheets 16px top, chips fully rounded. Tonal elevation, no drop shadows. Primary CTA 56dp full width, bottom-anchored. Touch targets ≥48dp. Page margin 16px.

## Navigation

### Auth (no bottom nav)

- `/login` — branded sign in
- `/signup` — create account
- `/join` — invite code

### Shell tabs (`ShellRoute` + `NavigationBar`)

| Tab | Label | Route | Visibility |
|-----|--------|--------|------------|
| Register | Home hub | `/` | All |
| Orders | Today's orders | `/today` | All |
| History | Held orders | `/held` | All |
| Reports | Settlement | `/settlement` | Owner / manager only |

Staff who land on `/settlement` redirect to `/`.

### Full-screen push (no bottom nav)

`/pos`, `/stall`, `/stock`, `/tables`, `/table/:label`, `/checkout/:billId`, `/receipt/:billId`

## Screen layouts

- **Home:** Stall switcher, large stall name, role chip; bento New order / Held; grouped surface lists for Stall / Availability / Tables / Today / Settlement (role-gated).
- **POS:** Stall chips, optional table field, menu rows with thumb or icon, sticky Hold / Place cart bar.
- **Checkout + payment sheet:** Sticky Due + Pay; sheet with Cash / UPI / Split pills, QR when configured.
- **Held / Stall / Stock / Tables / Table bill / Today / Settlement / Receipt:** Surface cards, status chips, bottom primary CTAs where stitch shows them; open tables as large label tiles; settlement net hero; receipt paper-style card.
- **App states:** Shared loading / empty / error; existing offline banner restyled to error tokens.

## Shared components

`RosTheme`, `MoneyText`, `StatusChip`, `RosBottomCta`, `RosSurfaceCard`, `RosNavTile`, `ShellScaffold`, empty/loading helpers.

## Constraints

Visual/layout only. Stitch HTML is reference, not pasted code.
