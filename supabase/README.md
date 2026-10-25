# Soama Marketplace — Backend & Database Guide

This directory contains the production-grade PostgreSQL / PostGIS database migrations, Row-Level Security (RLS) policies, stored procedures, and Supabase CLI configuration for the **Soama** dual-role services marketplace.

---

## 1. Directory Structure

```text
supabase/
├── config.toml                              # Local Supabase CLI configuration
├── README.md                                # Setup & testing manual
└── migrations/
    ├── 20261025000001_initial_schema.sql     # Enums, normalized tables, PostGIS geography, constraints & indexes
    ├── 20261025000002_row_level_security.sql # Explicit RLS policies on all 17 tables
    ├── 20261025000003_functions_and_triggers.sql # Atomic booking sproc, spatial search & rating triggers
    └── 20261025000004_seed_data.sql          # Seed categories & Supabase Storage bucket rules
```

---

## 2. Prerequisites & Local Setup

### Install Supabase CLI
```bash
# Via Scoop (Windows)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Or via npm
npm install -g supabase
```

### Start Local Supabase Instance
From the root of the project:
```bash
supabase start
```
This boots up:
- PostgreSQL 15 with **PostGIS** on `localhost:54322`
- PostgREST API on `http://127.0.0.1:54321`
- Supabase Studio Web UI on `http://127.0.0.1:54324`
- Realtime engine on `ws://127.0.0.1:54323`

### Apply Migrations
```bash
supabase db reset
```
This idempotently runs all four migration scripts in sequential order.

---

## 3. Database Invariants & Architecture Summary

| Area | Implementation Guarantee |
| :--- | :--- |
| **Dual-Role Account** | Single `auth.users` identity. One `profiles` record. Linked 1:1 `provider_profiles` record. Selected app mode is a UI preference, not an auth grant. |
| **Monetary Storage** | Strict integer minor units (`BIGINT` in kobo, e.g. ₦1,500 = `150000`) and currency `TEXT NOT NULL DEFAULT 'NGN'`. No floats. |
| **Location & Privacy** | Exact address and coordinates in `service_requests` are disclosed to providers **only** after booking confirmation. PostGIS `geography(Point, 4326)` for geodesic accuracy. |
| **Offer Acceptance** | Transactional stored function `accept_price_offer_and_create_booking()` uses `SELECT ... FOR UPDATE` to atomically prevent race conditions or duplicate bookings. |
| **Security (RLS)** | Enabled on **all 17 tables**. Private addresses, financial payments, and payout records cannot be tampered with by clients. |

---

## 4. Verification & Testing Instructions

### A. Testing Spatial Nearby Search
Execute this SQL in Supabase Studio SQL Editor (`http://127.0.0.1:54324`):
```sql
-- Search for approved providers within 25km of Effurun Roundabout (Lat: 5.556, Lng: 5.783)
SELECT * FROM public.find_nearby_providers(
    p_lat := 5.5562,
    p_lng := 5.7831,
    p_radius_meters := 25000,
    p_category_id := 'plumbing'
);
```

### B. Testing Atomic Offer Acceptance
```sql
-- Accepts offer and generates confirmed booking with reference BK-YYYYMMDD-XXXX
SELECT public.accept_price_offer_and_create_booking(
    p_offer_id := '<VALID_OFFER_UUID>',
    p_caller_id := '<CUSTOMER_OR_PROVIDER_UUID>'
);
```

### C. Testing Row-Level Security
Simulate customer query:
```sql
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" TO '<CUSTOMER_UUID>';
SET LOCAL "request.jwt.claim.role" TO 'authenticated';

-- This returns only the customer's own saved addresses:
SELECT * FROM public.saved_addresses;
```
