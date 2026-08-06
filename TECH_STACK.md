# TECH_STACK.md

# Restaurant Operating System (ROS)
## Recommended Technology Stack

**Version:** 1.0

---

# Overview

The Restaurant Operating System is designed as a **cloud-native**, **always-online**, **real-time**, and **multi-tenant** platform.

The chosen technology stack prioritizes:

- Cross-platform development
- Rapid development
- Low operational cost
- Real-time synchronization
- Always-online cloud backend (no offline stack)

The stack is centered around **Flutter**, **Next.js**, and **Supabase**, allowing a small development team to build and scale quickly while leveraging PostgreSQL, Realtime, Authentication, Storage, and Edge Functions from a unified backend platform. Supabase provides a PostgreSQL-based architecture with integrated Auth, Realtime, Storage, API generation, and Edge Functions behind a shared API gateway. :contentReference[oaicite:0]{index=0}

---

# Architecture Overview

```text
                    Users

          Mobile App (Flutter)

                    │

          Admin Web (Next.js)

                    │

──────────────────────────────────────

            Supabase Platform

──────────────────────────────────────

Authentication

PostgreSQL

Realtime

Storage

Edge Functions

Row Level Security

──────────────────────────────────────

        External Integrations

WhatsApp

SMS

Email
```

---

# Frontend

## Mobile Application

### Framework

**Flutter**

### Why Flutter?

- Single codebase
- Android
- iOS
- Excellent performance
- Large ecosystem
- Native feeling UI
- Strong realtime and WebSocket support

### Packages

State Management

- flutter_riverpod

Navigation

- go_router

Networking

- dio

Secure Storage

- flutter_secure_storage

Authentication

- supabase_flutter

Realtime

- Supabase Realtime

Push Notifications

- firebase_messaging

Image Loading

- cached_network_image

Barcode / QR

- mobile_scanner

PDF & Sharing

- pdf
- share_plus

Utilities

- intl
- uuid
- connectivity_plus
- package_info_plus

---

# Admin Portal

### Framework

**Next.js**

Recommended Version

- Next.js (App Router)

### UI

- Tailwind CSS
- shadcn/ui

Charts

- Recharts

Tables

- TanStack Table

Forms

- React Hook Form
- Zod

Icons

- Lucide

Authentication

- Supabase Auth

Data Fetching

- TanStack Query

---

# Backend Platform

## Supabase

Core Services

- PostgreSQL
- Authentication
- Realtime
- Storage
- Edge Functions
- Database Triggers
- Row Level Security (RLS)

Supabase automatically exposes REST/GraphQL-compatible APIs over PostgreSQL, integrates JWT-based authentication with Row Level Security, supports Realtime subscriptions, object storage, and globally distributed Edge Functions. :contentReference[oaicite:1]{index=1}

---

# Database

## PostgreSQL

Why PostgreSQL?

- ACID Transactions
- JSON Support
- Full Text Search
- Extensions
- Reliability
- Excellent Reporting
- Scalable

Extensions

- pgcrypto
- pg_trgm
- uuid-ossp

---

# Authentication

Supabase Auth

Supports

- Email Login
- Phone Login
- OTP
- Magic Links
- Google
- Apple
- Invite Codes
- JWT
- Refresh Tokens

Authorization

- Row Level Security
- Role-Based Access Control
- Stall Isolation (the stall is the tenant)
- Food Court Group membership

Supabase Auth issues JWTs and integrates directly with PostgreSQL Row Level Security, allowing authorization rules to be enforced at the database layer. :contentReference[oaicite:2]{index=2}

---

# Realtime

Supabase Realtime

Used For

- New Orders
- Stall Order Updates
- Table Status
- Payment Status
- Notifications

Communication

- WebSockets

---

# Client State

There is **no local database**. The platform is online only.

Flutter

- Riverpod in-memory state
- Short-lived caches for menu and reference data within a session

```
Device

↓

Supabase (source of truth)

↓

Realtime broadcast to all devices
```

`connectivity_plus` drives a persistent connection indicator; while offline, write actions are disabled rather than queued.

---

# File Storage

Supabase Storage

Used For

- Product Images
- Business Logos
- PDF Invoices
- Reports
- Attachments

---

# Edge Functions

Supabase Edge Functions

Use Cases

- FCM push dispatch
- WhatsApp Notifications
- Email Sending
- SMS Delivery
- Receipt Generation
- Scheduled Jobs

Edge Functions run globally using a Deno-compatible runtime and are designed for webhook handling, integrations, and low-latency server-side logic. :contentReference[oaicite:3]{index=3}

---

# Push Notifications

Firebase Cloud Messaging

Notifications

- New Orders
- Order Ready
- Refund Alerts

No inventory, reservation, CRM, or AI notification types.

---

# Payment Integration

Supported

- Cash
- UPI (via Razorpay)

Payment methods are Cash and UPI only.

Future

- Stripe
- Google Pay
- Apple Pay

---

# Communication

SMS

- Twilio
- MSG91

WhatsApp

- Meta WhatsApp Cloud API

Email

- Resend
- SendGrid

---

# Reporting

Generate

- PDF
- Excel
- CSV

Libraries

Flutter

- pdf
- share_plus

Next.js

- exceljs
- pdf-lib

---

# Monitoring

Frontend

- Firebase Crashlytics
- Sentry

Backend

- Supabase Logs
- Sentry

Analytics

- Google Analytics
- PostHog

---

# CI/CD

Source Control

- GitHub

Mobile

- Codemagic
- GitHub Actions

Web

- Vercel

Backend

- Supabase CLI
- GitHub Actions

---

# Deployment

## Mobile

- Google Play Store
- Apple App Store

---

## Web

- Vercel

---

## Backend

- Supabase Cloud

---

# Security

Authentication

- JWT
- Refresh Tokens

Authorization

- Row Level Security
- RBAC

Encryption

- HTTPS
- TLS

Secrets

- Supabase Secrets
- GitHub Secrets

Audit

- Activity Logs
- Login History

---

# Performance Targets

App Startup

< 2 Seconds

Order Creation

< 300 ms

Stall Routing

< 500 ms

Realtime Sync

< 1 Second

Receipt Generation

< 2 Seconds

Dashboard Loading

< 2 Seconds

---

# Future Infrastructure

As the platform scales:

- Docker where useful for local tooling
- CDN for static assets
- Multi-Region Deployment (Supabase / Vercel)
- Observability Stack (Sentry, Crashlytics)

Not planned: Redis offline/cache layers for POS, dedicated AI service, franchise infra.

---

# Recommended Development Stack

| Layer | Technology |
|--------|------------|
| Mobile App | Flutter |
| Web Admin | Next.js |
| UI Framework | Tailwind CSS + shadcn/ui |
| State Management | Riverpod (Flutter), TanStack Query (Next.js) |
| Backend | Supabase |
| Database | PostgreSQL |
| Authentication | Supabase Auth |
| Authorization | Row Level Security (RLS) + RBAC |
| Realtime | Supabase Realtime |
| Object Storage | Supabase Storage |
| Serverless | Supabase Edge Functions |
| Push Notifications | Firebase Cloud Messaging |
| Monitoring | Sentry + Firebase Crashlytics |
| Analytics | PostHog + Google Analytics |
| CI/CD | GitHub Actions + Codemagic + Vercel |
| Deployment | Supabase Cloud + Vercel |

---

# Why This Stack?

This technology stack provides:

- One codebase for Android and iOS
- Modern React-based admin portal
- PostgreSQL with RLS as the security boundary
- Built-in authentication and authorization
- Real-time synchronization
- Single cloud source of truth (no offline sync)
- Digital receipts only (no printers)
- Easy scaling across food-court stalls

It is suited for a cross-stall POS with settlement — not for inventory, CRM, AI, or franchise platforms. Supabase's integrated architecture—PostgreSQL, Auth, Realtime, Storage, Edge Functions, and RLS—reduces infrastructure complexity while remaining based on open technologies. :contentReference[oaicite:4]{index=4}