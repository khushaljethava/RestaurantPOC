# Phase 1 - Restaurant Operating System (MVP)

> **Authoritative spec:** `docs/superpowers/specs/2026-08-05-cross-stall-pos-design.md`
>
> That document supersedes this one wherever they disagree. In particular it replaces the
> "one business owns many stalls" model with **stall-as-tenant**. Permanently out of
> scope: Kitchen Display System, printers, offline mode, inventory, CRM/loyalty, AI,
> and franchise/white-label. Tables are a plain label.

> **Goal**
>
> Build a cloud-based Restaurant Operating System (ROS) that enables multiple food stalls to operate under one platform with centralized order management, cross-stall billing, automatic settlement between stall owners, and mobile-first operations.

---

# 1. Objectives

Phase 1 focuses on solving the biggest operational problems during busy hours:

- One customer can order from multiple stalls.
- Payment can be collected at any counter.
- Orders automatically reach the correct stall.
- Every stall receives only its own items.
- Owner gets one centralized dashboard.
- Staff can work using Android/iOS mobile devices.
- No manual calculations for cross-stall sales.

---

# 2. System Architecture

```
                     Cloud Backend
                          │
          ┌───────────────┼────────────────┐
          │               │                │

     Admin Web App   Mobile Application   Stall Order Screen

          │               │                │
          └───────────────┼────────────────┘
                  Real-Time Synchronization
                    (WebSocket/Firebase)
```

---

# 3. Platform Components

## 3.1 Admin Web Portal

Used by:

- Stall Owner
- Manager
- Food Court Group Admin

Purpose:

Manage a stall's menu, staff, reports, and cross-stall settlement.

---

## 3.2 Mobile Application

Used by:

- Owner
- Manager
- Staff (cashier / waiter)

The mobile app automatically changes based on user permissions.

---

## 3.3 Backend API

Responsible for

- Authentication
- Orders
- Payments
- Stall Routing
- Reports
- Synchronization

---

# 4. User Roles

## Owner

Full system access.

Permissions

- Manage own stall
- View Reports
- Join / leave a food court group
- Manage Staff
- Menu Management
- Settlement Report
- Billing Reports

---

## Manager

Permissions

- View Orders
- Edit Menu
- Assign Staff
- Reports
- Stall Order Monitoring

---

## Staff (Cashier / Waiter — one role)

Permissions

- Create Orders against any stall in the group
- Edit Orders
- Hold / Resume Orders
- Table Orders (any table — tables are not assigned)
- Billing
- Payments
- Share Receipts

---

## Stall Staff

Permissions

- View own stall's incoming orders
- Mark Ready
- Mark Complete
- Toggle own stall's item availability

Note: Cashier and Waiter are a single role. Any staff member may serve any table and
collect for any stall, so they were never distinct permission sets.

---

# 5. Stall Registration (the tenant)

**The stall is the tenant.** Each stall owner registers independently and owns their
own menu, prices, staff, orders, and revenue.

## Features

- Register Stall
- Stall Profile
- GST Details
- Currency
- Timezone
- Stall Logo
- Stall Settings

---

# 6. Food Court Group

A stall may operate standalone (`group_id = NULL`) or join a food court group.

Features

- Create Food Court
- Group Invite Code
- Request to Join
- Approve / Reject Join Request
- Leave Group

A group is a federation of independent owners, not a parent company. It owns no menus,
no revenue, and no staff.

---

# 7. Staff Management

## Invite Code System

There are two invite codes: one for staff joining a stall, one for a stall joining a
food court group.

Every stall has a staff Invite Code.

Example

```
Restaurant

ABCD-4521
```

Employee

```
Join Business

Enter Invite Code
```

The mobile app automatically connects to the restaurant.

Alternative

- QR Code Invitation

---

# 8. Role & Permission Management

Permissions include

- Create Orders
- Edit Orders
- Cancel Orders
- Refund
- View Reports
- Menu Management
- Stall Order Screen Access
- Staff Management

---

# 9. Stall Management

Features

- Create Stall
- Edit Stall
- Delete Stall
- Open/Close Stall
- Stall Order Screen Assignment

Example

```
Stall 1

Pizza
Burger
```

```
Stall 2

Coffee
Tea
```

Each stall owns its own menu while all menus remain searchable from every POS device. :contentReference[oaicite:0]{index=0}

---

# 10. Menu Management

Each Stall manages

Categories

- Pizza
- Drinks
- Desserts

Item Features

- Name
- Description
- Image
- Price
- GST
- SKU
- Barcode
- Availability

Operations

- Add Item
- Edit Item
- Delete Item
- Duplicate Item
- Enable / Disable
- Out of Stock

---

# 11. Mobile Ordering System

Supports

- Counter Orders
- Table Orders
- Takeaway Orders
- Cross-Stall Orders

Future

- Delivery

---

# 12. Tables

A table is a **label on an order**, not a managed resource. Tables are not assigned to
waiters — any staff member may take an order from any table.

Status

- Free (no unpaid bill)
- Open (has an unpaid bill)

Operations

- Attach order to a table label
- View a table's open bill
- Add more items to an open bill
- Close table (settle the bill)

Not included: floor layout, guest counts, waiter assignment, transfer, merge, split,
reservations, waitlist, cleaning status.

---

# 13. Order Management

Create Order

Supports

- Search Menu
- Categories

Not included: favorites, modifiers, coupons, customer lookup, inventory deduction.

Operations

- Add Item
- Remove Item
- Edit Quantity
- Add Notes

Example

```
Pizza

x2

Notes: less spicy
```

---

# 14. Hold Orders

Staff can

- Hold Order
- Resume Order
- Delete Hold

Useful during rush hours.

---

# 15. Cross-Stall Ordering

Example

Customer orders

```
Pizza

Coffee

Ice Cream
```

Payment taken at

```
Juice Counter
```

Backend

```
Pizza

→ Stall 4

Coffee

→ Stall 2

Ice Cream

→ Stall 5
```

Every stall receives only its own items while billing remains unified. :contentReference[oaicite:2]{index=2}

---

# 16. Stall Order Screen

There is **no Kitchen Display System**. Each stall gets one screen showing its own incoming orders.

The stall sees

```
Order #1024

Pizza x2

Extra Cheese
```

Actions

- Mark Ready
- Mark Complete (on handover to customer)

No stations, no timers, no priority engine, no kitchen analytics.

A push notification fires on the stall's device whenever any counter records an order for that stall.

---

# 17. Live Order Tracking

Status

```
Pending

↓

Ready

↓

Completed
```

Updates are synchronized instantly across

- The stall that owns the order
- The stall that recorded it
- Owner / Manager

---

# 18. Billing

Supports

- Cash
- UPI
- Split Payment (Cash / UPI)
- Discount
- Refund

Payment methods are Cash and UPI only.

Generate

- GST Invoice (PDF)
- Digital Receipt (on-screen + shareable link/PDF)

---

# 19. Receipt

Single Receipt

Example

```
Pizza

Coffee

Ice Cream

Total

₹860
```

Regardless of how many stalls contributed.

---

# 20. Cross-Stall Settlement

Backend automatically records

Collected By

```
Stall 1
```

Revenue Distribution

```
Stall 2

₹180
```

```
Stall 4

₹420
```

```
Stall 5

₹260
```

Owner no longer performs manual settlement.

---

# 21. Dashboard

Widgets

- Today's Sales
- Active Orders
- Pending Orders
- Ready Orders
- Completed Orders
- Revenue
- Orders by Stall

---

# 22. Reports

Daily Sales

Orders

Revenue

Payment Modes

Cross-Stall Sales

Best Selling Items

Cancelled Orders

Refund Report

Cash Reconciliation

---

# 23. Notifications

Push Notifications

- New Order
- Order Ready
- Order Cancelled
- Stall Closed
- Low Stock (Future)

---

# 24. Connectivity Model

The platform is **online only**. There is no offline mode, local database, or sync queue in Phase 1.

Behaviour

- All reads and writes go directly to the cloud backend
- Realtime subscriptions keep every device in sync
- A connection indicator is always visible
- While disconnected, write actions are blocked with a clear error rather than queued
- Realtime channels reconnect automatically with backoff

Requirement

- The venue must have reliable internet (broadband with a mobile-data fallback). Operations stop during an outage — this is an accepted, explicit trade-off in favour of a single source of truth and a much simpler system.

---

# 25. Security

Authentication

- JWT
- Refresh Tokens

Authorization

- Role Based Access Control

Encryption

- HTTPS
- Secure Password Hashing

Audit Logs

---

# 26. Technology Stack

See `TECH_STACK.md` for the full detail. Summary:

## Frontend

- Flutter (mobile app, Android + iOS)
- Next.js App Router (admin web portal)

---

## Backend

- Supabase (Postgres, Auth, Realtime, Storage, Edge Functions)

---

## Database

- PostgreSQL with Row Level Security for tenant isolation

---

## Real-Time

- Supabase Realtime (WebSockets)

---

## Storage

- Supabase Storage (images, PDF invoices)

---

## Notifications

- Firebase Cloud Messaging

---

## Receipts

- Digital only — PDF generation and share. No printer integration.

---

# 27. Deliverables

At the end of Phase 1 the platform will provide:

- Cloud-based Restaurant Operating System
- Admin Web Portal
- Mobile App for Staff
- Invite Code Staff Onboarding
- Role-Based Access Control
- Stall Management
- Menu Management
- Table Management
- Counter Ordering
- Table Ordering
- Cross-Stall Ordering
- Cross-Stall Billing
- Stall Order Screen
- Real-Time Order Tracking
- Hold & Resume Orders
- Unified Billing
- GST Digital Receipts
- Daily Reports
- Dashboard
- Push Notifications

---

# Success Criteria

- Staff can process orders from any mobile device.
- Customers receive one consolidated bill for items from multiple stalls.
- Orders are automatically routed to the correct stall.
- Stall staff receive only their own items.
- Owners can monitor all stalls from a centralized dashboard.
- Cross-stall revenue settlement is fully automated.
- Every device reflects the same state in under a second via realtime updates.