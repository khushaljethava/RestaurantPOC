# Google Stitch Design Guide — ROS

> Copy-paste prompts for [stitch.withgoogle.com](https://stitch.withgoogle.com/)
> to generate the UI for the ROS mobile app and admin web portal.
>
> Screens are enumerated in `Mobile Screen list.md` (13 routes) and
> `Web App screen list.md` (10 routes). Domain rules live in `DESIGN.md`.
> This file is the bridge: what to type into Stitch so the output matches the
> product we already built.

## How to use this

1. Start a new Stitch project. Pick **Mobile** for the app, **Web** for admin —
   they are separate projects, do not mix them in one.
2. Paste **§1 Global style** as the first message. It sets the theme for
   everything that follows in that project.
3. Paste one screen prompt from §3 or §4 per generation. One screen at a time
   produces far better output than a list of screens in one prompt.
4. Refine with short follow-ups ("make the pay button bottom-anchored and
   full-width", "use tabular numbers in the amount column") rather than
   re-writing the whole prompt.
5. Export to Figma or copy the code as a **starting point**. The generated code
   is React/HTML; our mobile app is Flutter, so mobile output is a visual
   reference to reimplement, not code to paste.

**Two rules that save the most time.** Give Stitch the exact hex values — it
respects explicit colours and invents its own when you say "green". And
describe the data on screen ("₹240.00", "Token #14", "Dosa × 2") instead of
placeholder words, because realistic content changes the layout it picks.

---

## 1. Global style prompt

Paste this once per Stitch project, before any screen.

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
```

For the **admin web** project, append:

```
This is the desktop admin portal, not the phone app. Optimise for data
density: compact 44px table rows, sticky table headers, many rows visible at
once, a fixed 224px left sidebar for navigation. Seated desk use, keyboard
driven, visible focus rings.
```

For the **mobile** project, append:

```
This is a phone app used one-handed while standing, often in a hurry. Large
touch targets (minimum 48dp), the primary action anchored at the bottom of the
screen within thumb reach, 56dp tall and full width. Few elements per screen.
```

---

## 2. Reusable phrases

Drop these into any screen prompt; they fix the things Stitch most often gets
wrong for this product.

| Need | Phrase to include |
|---|---|
| Money legibility | "amounts right-aligned with tabular figures" |
| Status | "status shown as a coloured pill with a word inside, never colour alone" |
| Primary action | "one filled primary button, everything else tonal or text" |
| Bottom action (mobile) | "primary action fixed to the bottom edge, full width, 56dp tall" |
| Empty state | "empty state is one sentence plus the button that creates the first item, no illustration" |
| Offline | "a persistent amber banner across the top reading 'Offline — writes disabled'" |
| No clutter | "no icons in table cells, no avatars, no charts, no gradients" |

---

## 3. Mobile screen prompts

Thirteen screens matching the shipped routes.

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
availability. Unavailable rows show the name in muted text. A search field is
not needed. Header explains "Turn an item off when you run out. It disappears
from the order screen."
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
quantity, amounts right-aligned in tabular figures. Below the divider, a right-
aligned block: Total, then Discount, then "Due" in large bold type. A collapsed
"Apply discount" section expands to reveal an amount field and a required
reason field. The bottom of the screen has one filled full-width button reading
"Take payment", 56dp tall.
```

### Payment sheet (opens from checkout)

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
positive amounts in green and amounts you owe in red. A summary card at the top
shows the net position in large type: "You are owed ₹1,240.00". Empty state
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

## 4. Admin web screen prompts

Ten screens. Start each with the shell so navigation stays consistent.

### Shell (include in every admin prompt)

```
Desktop admin layout: a fixed 224px left sidebar on a white surface with a
stall switcher dropdown at the top, then text navigation links reading
Dashboard, Live, Settlement, Reports, Menu, Staff, Food Court, Settings. The
active link is bold with a green left indicator. The main content area has 32px
padding and a page title at the top.
```

### Dashboard — `/`

```
[shell] Admin dashboard. Three stat cards across the top in a row: "Today's
sales" showing ₹12,480.00, "Open bills" showing a count, and "Net owed" showing
an amount with a link to settlement. Numbers are the largest element on each
card, tabular figures. Below the cards, nothing else — this page is
deliberately sparse.
```

### Live board — `/live`

```
[shell] A live operations board that updates in real time. Two columns: the
left lists open bills as compact cards with table label, amount and collector;
the right lists active orders grouped by status with token number, stall name,
items and a status pill. A small "Live" indicator with a pulsing green dot sits
next to the page title.
```

### Settlement — `/settlement`

```
[shell] Settlement page. A date range picker with From and To date inputs and
an "Export CSV" outlined button aligned right. Below, a table of settlement
pairs: columns for Stall A, Stall B, and Amount owed, amounts right-aligned in
tabular figures. Clicking a row expands a drill-down table beneath it showing
the individual bills and orders behind that number, with token numbers, stall
names and amounts.
```

### Reports — `/reports`

```
[shell] Reports page with a date range picker at the top and four separate
data tables stacked vertically, each with its own section header and its own
"Export CSV" button aligned to the right of the header: Sales by stall, Sales
by item, Sales by payment mode, Sales by collector. Compact 44px rows, sticky
header row on a light green-grey background, all numeric columns right-aligned
with tabular figures. No charts.
```

### Menu — `/menu`

```
[shell] Menu management. The left two-thirds is a list of categories, each
category a section header with up/down reorder arrows and a rename control,
containing its items. Each item row shows a 40x40 thumbnail, name, description
in secondary text, price right-aligned, an availability switch, and an overflow
menu with Edit, Duplicate, Upload image, Remove image, Delete. The right third
is a sticky panel with an "Add item" form: name, description, price, category
select. Below the main list, a collapsed read-only section titled "Peer stall
menus" showing other food-court stalls' items greyed out.
```

### Staff — `/staff`

```
[shell] Staff management. A card at the top titled "Redeem an invite code" with
a single monospace field and a button. Below, a section "Invite codes" listing
active codes in monospace with their role and a "Revoke" text button, plus a
"Generate invite" control with a role select. Below that, a "Members" table
with columns for member, role and actions; the role cell is a select dropdown
for owners and plain text otherwise, with a "Remove" destructive text button in
the last column.
```

### Food court — `/group`

```
[shell] Food court page. If the stall is in a group: the group name as a
heading, a list of member stalls, a monospace group invite code with a
"Generate new code" button, a "Pending join requests" table with Approve and
Reject buttons per row, and a low-emphasis "Leave food court" destructive
button at the bottom. If not in a group: two cards side by side, "Create a food
court" with a name field, and "Join with a code" with a code field.
```

### Settings — `/settings`

```
[shell] Stall settings form, single column, max 640px wide. Fields: stall name,
currency select, timezone select, an "Accepting orders" switch, then a section
divider labelled "UPI collection" with a UPI VPA field (helper text: "From
Paytm Business or any UPI app, e.g. merchant@paytm") and a payee name field. A
filled "Save changes" button at the bottom left of the form.
```

### Login and Onboarding — `/login`, `/onboarding`

```
Login: a centred card on a plain background, app name heading, email and
password fields, a filled full-width "Sign in" button and a text toggle to sign
up. No sidebar.

Onboarding: a centred card headed "Name your stall" with one text field and a
filled "Create stall" button, plus a line of helper text explaining this
creates the account's first stall. No sidebar.
```

---

## 5. What Stitch will get wrong

Known failure modes for this product; correct them in follow-ups or in code.

- **Invents a payment gateway UI.** There is none — cash, a UPI QR the staff
  confirms by hand, and a card amount entry. Say "no card reader, no payment
  gateway, staff confirms manually" if it drifts.
- **Adds tax or GST lines** to receipts and checkout. This product has no tax.
  Remove them; the schema has no such column.
- **Adds inventory counts** to the availability screen. It is a boolean toggle,
  nothing more.
- **Adds charts** to reports. Deliberately absent — tables and CSV only.
- **Puts primary actions in a top app bar** on mobile. Move them to the bottom.
- **Uses colour alone for status.** Always demand the word in the pill.
- **Generates a printer or KDS screen.** Neither exists.

---

## 6. From Stitch output to our code

- **Admin web**: the generated HTML/React is close to usable. Keep the layout
  and spacing, replace the styling with Tailwind classes, and wire the existing
  server actions in `admin/src/app/(app)/*/actions.ts`. Do not adopt any
  component library it pulls in — the portal has none today and does not need
  one.
- **Mobile**: treat the output as a picture. Reimplement in Flutter with
  `ColorScheme.fromSeed(seedColor: Color(0xFF1B5E4B))`, which generates exactly
  the palette in §1 — that is where those hex values came from.

Three cleanups worth doing before importing anything, because they are what
currently makes the app look unfinished:

1. `admin/src/app/globals.css` forces `font-family: Arial` on `body`,
   overriding the fonts the layout loads. `admin/src/app/layout.tsx` still has
   `title: "Create Next App"`.
2. Raw `Colors.orange` and `Colors.red.shade700` appear in
   `mobile/lib/widgets/payment_sheet.dart` and several screens, bypassing the
   colour scheme entirely.
3. Seven mobile screens render `e.toString()` directly into the UI — checkout,
   receipt, POS, held, join, stock and settlement. Map these to human sentences
   before any design work lands on top of them.
