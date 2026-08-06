# DESIGN.md

> **Authoritative spec for v1:** `docs/superpowers/specs/2026-08-05-cross-stall-pos-design.md`
>
> That document supersedes this one wherever they disagree — stall-as-tenant instead of
> one business owning many stalls. Permanently out of scope: Kitchen Display System,
> printers, offline mode, inventory, CRM/loyalty, AI, and franchise/white-label.
> Tables are a plain label.

# Restaurant Operating System (ROS)
### System Design & Technical Architecture

**Version:** 1.0

---

# Overview

Restaurant Operating System (ROS) is a **cloud-native**, **mobile-first**, **multi-tenant** platform for food courts and independent stalls.

Unlike traditional POS systems where each counter operates independently, ROS enables **cross-stall ordering**, **centralized billing**, and **automatic settlement between stall owners** from a single platform.

The system follows an **always-online, cloud-backed** architecture. Every device talks directly to the cloud backend and reflects a single shared state in real time. A working internet connection is a hard requirement for operation.

---

# Design Principles

## 1. Mobile First

Every operational task should be possible from a mobile device.

Examples

- Table Orders
- Billing
- Payments (Cash / UPI only)
- Stall Orders
- Reports

Desktop is primarily used for administration.

---

## 2. Always Online

The platform is fully online. There is no local database, no sync queue, and no offline mode.

Every device

- Reads and writes directly against the cloud backend
- Subscribes to realtime updates for shared state
- Shows a clear connection indicator
- Blocks write operations while disconnected, with an explicit error

This keeps a single source of truth in the cloud and removes an entire class of sync and conflict bugs. The trade-off is explicit: **operations stop when the internet does**, so the venue needs reliable connectivity (broadband plus a mobile-data fallback).

---

## 3. Cloud Native

The backend is fully cloud-hosted.

Benefits

- No local server
- Automatic backups
- Remote monitoring
- Multi-branch support
- High availability
- Auto Scaling

---

## 4. Multi Tenant

**The stall is the tenant.** One platform supports thousands of independent stall owners.

```
Platform

│

├── Stall A  (standalone)

├── Stall B  ─┐

├── Stall C  ─┼── Food Court Group (federation of independent owners)

└── Stall D  ─┘
```

Each stall has complete data isolation. A food court group shares menus and orders
between members but never staff, invite codes, or stall settings.

---

## 5. Real-Time First

Every update is immediately synchronized.

Examples

- New Order
- Order Status
- Payment
- Table Status
- Stock Changes

Real-time synchronization between counters and stall devices reduces order delays and conflicts. :contentReference[oaicite:2]{index=2}

---

# High Level Architecture

```
                  Internet

                      │

                API Gateway

                      │

        ┌─────────────┼─────────────┐

        │             │             │

 Authentication   REST API    WebSocket

        │             │             │

        └─────────────┼─────────────┘

                Business Services

        │

────────────────────────────────────────────

Order Service

Billing Service

Stall Order Service

Staff Service

Report Service

Notification Service

────────────────────────────────────────────

                PostgreSQL

              Object Storage
```

---

# Client Applications

## 1. Admin Web

Used by

- Owner
- Admin
- Manager

Responsibilities

- Stall configuration
- Reports and settlement
- Staff and invite codes
- Menu and prices

---

## 2. Mobile Application

Used by

- Owner
- Manager
- Staff (cashier / waiter — one role)

Capabilities

- Billing
- Orders
- Stall Order Screen
- Tables (label only)
- Payments (Cash / UPI only)

There is no customer-facing app.

---

# Backend Services

## Authentication Service

Responsibilities

- Login
- JWT
- Refresh Tokens
- Invite Codes
- QR Join
- Password Reset

---

## Order Service

Responsible for

- Orders
- Tables
- Hold Orders
- Order History
- Cross Stall Routing

---

## Billing Service

Responsible for

- Payments (Cash / UPI only)
- Discounts
- Refunds
- Receipts

---

## Stall Order Service

Responsible for

- Per-stall order queue
- Ready / Complete transitions
- Push notification on new order

---

## Notification Service

Responsible for

- Push Notifications
- SMS
- Email
- WhatsApp

Item availability (`is_available`) is a menu flag, not an inventory service.

---

# Mobile Architecture

```
Presentation Layer

↓

Business Logic Layer

↓

Repository Layer

↓

API Layer

↓

Backend
```

The cloud database is the single source of truth. Clients hold only an in-memory cache for the current session.

---

# Write Flow

```
User Creates Order

↓

Write to Backend

↓

Backend Confirms

↓

Realtime Broadcast

↓

All Devices Updated
```

If the write fails or the device is offline, the action is rejected with a visible error and the user retries. Nothing is silently queued.

---

# Database Design

## Core Entities

Food Court Group (optional)

↓

Stall  (THE TENANT)

↓

Category

↓

Menu Item

↓

Order

↓

Order Item

↓

Bill  (groups orders across stalls)

↓

Payment

↓

Employee

↓

Role

↓

Permission

---

# Order Lifecycle

```
New Order

↓

Pending  (visible on the owning stall's screen)

↓

Ready

↓

Completed  (handed to customer)
```

---

# Cross Stall Workflow

```
Customer orders Pizza, Coffee, Ice Cream at the Juice Counter (Stall 1)

↓

One order per stall is created

↓

order(stall_id=4)   Pizza      recorded_by_stall = 1

order(stall_id=2)   Coffee     recorded_by_stall = 1

order(stall_id=5)   Ice Cream  recorded_by_stall = 1

↓

All three attach to ONE bill, collected_by_stall = 1

↓

Customer pays once. Each stall sees only its own order on its screen.
```

Revenue accrues to each order's `stall_id`; cash accrues to the bill's
`collected_by_stall_id`. The difference, netted per stall pair over a day, is the
settlement sheet — no manual reconciliation.

---

# Technology Stack

## Mobile

Flutter

---

## Web

Next.js (App Router)

---

## Backend

Supabase (Postgres, Auth, Realtime, Storage, Edge Functions)

---

## Database

PostgreSQL with Row Level Security

---

## Storage

Supabase Storage

---

## Real-Time

Supabase Realtime (WebSockets)

---

## Push Notifications

Firebase Cloud Messaging

---

## Authentication

JWT

Refresh Tokens

---

## Search

PostgreSQL Full Text Search

---

## Receipts

Digital only — on-screen receipt plus generated PDF, shared via WhatsApp, SMS, or email. No printer hardware or driver integration.

---

# Security Design

Authentication

- JWT
- Refresh Token
- Device Sessions

Authorization

- RBAC

Encryption

- HTTPS
- TLS
- Password Hashing

Audit

- Activity Logs
- Login History
- Data Changes

---

# Performance Goals

Order Creation

< 300 ms

Stall Routing

< 500 ms

Table Updates

Real Time

Receipt Generation

< 2 Seconds

API Response

< 300 ms

Dashboard Loading

< 2 Seconds

---

# Scalability

Supports

- Many independent stalls (tenants)
- Food court groups
- Unlimited staff per stall
- Unlimited orders and menu items

Horizontal scaling is achieved by Supabase-hosted Postgres, Realtime, and Edge Functions.

---

# Failure Recovery

If internet fails

- Writes are blocked and the device shows a clear offline banner
- Realtime subscriptions reconnect automatically with backoff
- In-flight requests are retried; duplicates are prevented by client-generated idempotency keys

If a write fails

- The user sees the error and can retry
- No partial order or payment is recorded

If a mobile device crashes

- All state is restored from the cloud on next launch

---

# Deployment Architecture

```
Flutter Mobile / Next.js Admin

↓

Supabase (Auth, API, Realtime, Storage, Edge Functions)

↓

PostgreSQL + Object Storage
```

---

# Explicitly not in this design

- Inventory (quantity, recipes, purchases, suppliers)
- CRM, loyalty, wallet
- AI / forecasting / assistants
- Franchise or white-label SaaS
- Printers / ESC-POS
- Offline mode or local database
- Kitchen Display System
- Customer-facing ordering apps

---

# Design Goals

- Mobile-first operations
- Cloud-native, always-online
- Stall-as-tenant multi-tenancy
- Real-time synchronization
- Cross-stall billing and settlement
- Secure by default (RLS)
- Digital receipts only

---

# Final Vision

ROS replaces disconnected food-court POS and manual settlement with one cloud system:

- Mobile-first counter and stall operations
- Cross-stall order routing and revenue allocation
- Automatic close-of-day settlement between stall owners
- Realtime sync from a single cloud source of truth
- Admin portal for menu, staff, reports, and settings

Scope stops there. See the authoritative design spec for M1–M5.