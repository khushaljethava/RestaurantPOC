# Google Stitch Design Guide — ROS Mobile

> Copy-paste prompts for [stitch.withgoogle.com](https://stitch.withgoogle.com/)
> covering the 13 screens of the ROS Flutter app.
>
> Web/admin prompts live in `google_sitch_desing.md`. Screens are enumerated in
> `Mobile Screen list.md`; domain rules in `DESIGN.md`.

## How to use this

1. Start a **Mobile** project in Stitch. Keep it separate from the admin
   project — mixing phone and desktop in one project degrades both.
2. Paste **§1** as the first message. It sets the theme for everything after.
3. Paste **one** screen prompt per generation. One screen at a time beats a
   list of screens in a single prompt, every time.
4. Refine with short follow-ups ("make the pay button full width at the
   bottom", "use tabular numbers for the amount") rather than editing and
   resending the whole prompt.
5. Stitch emits React/HTML. This app is Flutter, so treat the output as a
   **visual reference to reimplement**, not code to paste. See §6.

Two rules that save the most time: give it the exact hex values (it invents its
own when you say "green"), and use realistic content — "Dosa × 2", "₹240.00",
"Token #14" — because real data changes the layout it chooses.

---

## 1. Global style prompt

Paste once, before any screen.

```
A point-of-sale app for Indian street-food stalls and food courts, used by
stall owners and cashiers during a busy service rush.

Design language: Google Material 3, clean and functional, no decoration.
Generous white space, strong hierarchy, content over chrome.

Colour palette (use these exact values):
- Primary: #156B54 (deep green)
- On primary: #FFFFFF
- Primary container: #A4F2D5
- Page background: #F5FBF6
- Card and sheet surface: #E9EFEB
- Body text: #171D1A
- Secondary text: #3F4944
- Borders and dividers: #BFC9C3
- Error / destructive: #BA1A1A
- Error background: #FFDAD6
- Paid or ready status: #1B6C3D
- Pending or held status: #8A5300 on #FFF0D4

Typography: Roboto. Screen titles 24px regular, section headers 16px medium,
body 16px regular, secondary text 14px, captions 11px medium. All money
amounts use tabular figures and are right-aligned.

Shape: 12px radius on cards and list rows, 8px on inputs and small buttons,
16px on bottom sheets, fully rounded chips. Flat surfaces with subtle tonal
elevation, not drop shadows.

Currency is Indian Rupees, always formatted like ₹1,240.00. Sentence case
everywhere, never all caps. Action labels are verbs: "Place order", not
"Submit".

This is a phone app used one-handed while standing, often in a hurry. Large
touch targets (minimum 48dp), the primary action anchored at the bottom of the
screen within thumb reach, 56dp tall and full width. Few elements per screen.
```

### Dark mode (optional second pass)

```
Now generate the dark theme of the same screens. Page background #0F1512,
card and sheet surface #1B211E, body text #DEE4DF, secondary text #BFC9C3,
primary #88D6BA with #00382A text on it, borders #3F4944, error #FFB4AB.
Paid or ready status #7ADBA0, pending or held #F5BE55. Surfaces lighten with
elevation — never pure black.
```

---

## 2. Reusable phrases

Drop these into any screen prompt; they fix what Stitch most often gets wrong
here.

| Need | Phrase to include |
|---|---|
| Money legibility | "amounts right-aligned with tabular figures" |
| Status | "status shown as a coloured pill with a word inside, never colour alone" |
| Primary action | "one filled primary button, everything else tonal or text" |
| Bottom action | "primary action fixed to the bottom edge, full width, 56dp tall" |
| Empty state | "empty state is one sentence plus the button that creates the first item, no illustration" |
| Offline | "a persistent amber banner across the top reading 'Offline — writes disabled'" |
| Destructive | "destructive action separated by a divider and large gap, never beside a common action" |
| No clutter | "no avatars, no charts, no gradients, no decorative icons" |

---

## 3. Screen prompts

Thirteen screens, matching the shipped routes exactly.

### Home — `/`

```
Home screen of the POS app. Top app bar with the title "ROS" and two icon
buttons on the right: a QR icon for joining with an invite code, and a sign-out
icon. Below it, the active stall name as a large heading with the user's role
and a short stall id underneath in secondary text. If the user belongs to
several stalls, an outlined dropdown labelled "Active stall" sits above the
heading. Then a vertical list of large navigation rows, each with a leading
icon, a label, and a trailing chevron: New order, Held orders, Stall order
screen, Item availability, Open tables, Today's orders, Today's settlement.
Rows are 72dp tall, comfortable to tap.
```

### New order (POS) — `/pos`

The busiest screen in the product. Generate this one first — it exposes whether
the style took.

```
Point-of-sale order entry screen, the busiest screen in the app. A horizontal
row of scrollable filter chips at the top for choosing which stall's menu to
browse, with the first chip selected. Below, a scrolling list of menu items:
each row has an optional 48x48 rounded thumbnail, the item name in 16px, the
price right-aligned with tabular figures, and a plus button to add. Sold-out
items appear greyed with a "Sold out" pill and cannot be tapped. An optional
text field for a table label sits above the list. A persistent cart summary
bar is docked at the bottom showing item count and total, expanding to reveal
cart lines with quantity steppers and a note icon per line. Two bottom actions:
a tonal "Hold" button and a filled "Place order" button, full width, side by
side.
```

Follow-up if the cart feels cramped:

```
Expand the cart into a draggable bottom sheet showing each line with the item
name, a minus/number/plus stepper at least 48dp per target, the line total
right-aligned, and a note icon that opens a small dialog.
```

### Held orders — `/held`

```
A list of held (parked) orders. Each card shows the table label or "No table",
the number of items, the total amount right-aligned, and how long ago it was
held in secondary text. A filled "Resume" button on each card. Empty state
reads "No held orders" with a button "Start a new order".
```

### Stall order screen — `/stall`

```
A live kitchen queue for one stall. Cards in a single column, newest first.
Each card shows a large token number like "Token #14" as the most prominent
element, the list of items with quantities, any line notes in an indented
italic style, and a status pill reading "Pending" in amber or "Ready" in green.
Each card has one action button: "Mark ready" for pending cards, "Mark
complete" for ready cards. New cards fade in when they arrive. Empty state
reads "No open orders".
```

### Item availability — `/stock`

```
A settings-style list of this stall's menu items, each row showing the item
name, its price in secondary text, and a Material switch on the right toggling
availability. Unavailable rows show the name in muted text. No search field.
A short header explains "Turn an item off when you run out. It disappears from
the order screen."
```

### Open tables — `/tables`

```
A grid of table cards, two per row on a phone. Each card shows the table label
large and centred, the number of unbilled orders beneath it, and the running
total in tabular figures. Tapping a card opens that table's bill. Empty state
reads "No open tables. Start an order with a table label to open one."
```

### Table bill — `/table/:label`

```
The bill for one table. Header shows the table label and the running total in
large text. Below, a grouped list of the orders on this table, each group
labelled with its token number and status pill, listing items with quantity and
line amount right-aligned. Two bottom actions: an outlined "Add items" button
and a filled "Settle" button.
```

### Today's orders — `/today`

```
Two sections in one scrolling screen. First, "Open bills": compact cards with
table label, amount due right-aligned, and a filled "Checkout" button. Second,
"Today's orders": a denser list of every order today with token number, item
count, status pill, and time. Cancelled orders are struck through in muted red.
Each non-cancelled order row has an overflow menu with "Cancel order", which
opens a dialog requiring a written reason before the destructive button
enables.
```

### Checkout — `/checkout/:billId`

```
Checkout screen for one bill. At the top, the table label and a status line.
Then an itemised summary grouped by token number, item names on the left with
quantity, amounts right-aligned in tabular figures. Below the divider, a
right-aligned block: Total, then Discount, then "Due" in large bold type. A
collapsed "Apply discount" section expands to reveal an amount field and a
required reason field. The bottom of the screen has one filled full-width
button reading "Take payment", 56dp tall.
```

### Payment sheet (opens from checkout)

The highest-stakes surface in the product. Worth two or three refinement
rounds.

```
A modal bottom sheet for taking payment, rounded 16px at the top. The amount
due is the largest element, 36px, centred at the top, like "₹240.00". Under it
a row of three quick buttons: "Full cash" and "Full UPI (QR)" as tonal buttons,
"Split" as outlined. In UPI mode a QR code is displayed on a white plate with
generous padding, with the payee name and UPI id centred beneath in small text,
and a caption "Ask the customer to scan, then confirm received". In cash or
split mode, three outlined numeric fields labelled Cash, UPI and Card, with a
live running line reading how much is still short, like "₹40.00 short", in
amber. One filled full-width confirm button at the bottom, 56dp tall.
```

### Receipt — `/receipt/:billId`

```
A digital receipt. A centred card styled like a paper receipt: stall name, bill
reference, date and time, then the itemised lines with amounts right-aligned,
a divider, the total in bold, and the payment methods used listed beneath.
Below the card, two side-by-side buttons: an outlined "Preview PDF" and a
filled "Share". Far below, separated by a large gap and a divider, a single
low-emphasis destructive text button "Refund this bill" in red, which opens a
confirmation dialog requiring a written reason.
```

### Settlement — `/settlement`

```
A simple settlement summary for a food court. A list of pair rows, each reading
like "Stall A owes Stall B" with the amount right-aligned in tabular figures,
amounts owed to you in green and amounts you owe in red. A summary card at the
top shows the net position in large type: "You are owed ₹1,240.00". Empty state
reads "Nothing to settle today".
```

### Login and Join — `/login`, `/join`

```
Login screen: centred column, app name as a heading, an email field and a
password field (outlined, 8px radius), a filled full-width "Sign in" button,
and a text button toggling to "Create an account". Errors appear as a red
message above the button, never as a popup.

Join screen: a single centred card with a heading "Enter your invite code", one
outlined text field in monospace for the code, and a filled "Join stall"
button.
```

---

## 4. Cross-cutting states

Generate these once and reuse the treatment everywhere.

```
Show the shared states for this app as one sheet: (1) an offline state — a
persistent amber banner pinned across the top reading "Offline — writes
disabled", with the primary button beneath it disabled and its reason shown on
the button itself; (2) a loading list — skeleton rows matching the real row
height, never a full-screen spinner; (3) an error state — a plain sentence, the
reason, and a "Retry" text button; (4) an empty list — one sentence plus the
button that creates the first item, no illustration.
```

---

## 5. What Stitch will get wrong

Correct these in follow-ups; they recur.

- **A payment gateway or card-reader flow.** There is none — cash, a UPI QR the
  staff confirms by hand, and a card amount typed in. Say "no card reader, no
  payment gateway, staff confirms manually".
- **GST or tax lines** on receipts and checkout. This product has no tax at all;
  the database has no such column. Say "there is no tax or GST, remove those
  rows".
- **Inventory counts** on the availability screen. It is one boolean toggle per
  item — no quantities, no low-stock warnings.
- **A kitchen display or printer screen.** Neither exists; receipts are digital
  PDF/share only.
- **Primary actions in the top app bar.** Move them to the bottom edge.
- **Colour-only status.** Always demand the word inside the pill.
- **Customer accounts, loyalty, ratings.** Out of scope permanently.

---

## 6. Turning the output into Flutter

The generated code is React; the app is Flutter. Reimplement, don't transpile.

- The Material roles in §1 are not invented — they are exactly what
  `ColorScheme.fromSeed(seedColor: Color(0xFF1B5E4B))` generates, which is
  already the theme in `mobile/lib/app.dart`. So anything Stitch draws with
  those hexes maps to `Theme.of(context).colorScheme` directly: `primary`,
  `primaryContainer`, `surface`, `surfaceContainer`, `outlineVariant`,
  `onSurface`, `onSurfaceVariant`, `error`.
- The four **status** colours (paid/ready, pending/held and their dark pairs)
  are the exception — M3 generates no role for them, so they are hand-picked to
  clear 4.5:1 on our surfaces. Put them in a `ThemeExtension` rather than
  scattering literals, which is the mistake the current code already makes.
- Money text needs `fontFeatures: [FontFeature.tabularFigures()]`; there is no
  CSS equivalent to copy across.
- Bottom-anchored actions belong in `Scaffold.bottomNavigationBar` or a
  `SafeArea`-wrapped bar, not a floating widget the keyboard will cover.
- Check every generated screen at `textScaleFactor: 2.0` before calling it
  done. The POS cart and the payment sheet are the two that will clip.

Three cleanups worth doing before layering any new design on top:

1. Raw `Colors.orange` and `Colors.red.shade700` in
   `mobile/lib/widgets/payment_sheet.dart` and several screens bypass the
   colour scheme entirely — they will not follow the theme or dark mode.
2. Seven screens render `e.toString()` straight into the UI (checkout, receipt,
   POS, held, join, stock, settlement). Map to human sentences first.
3. Icon-only buttons (the POS note icon, the Home app-bar actions) need
   tooltips and semantic labels.
