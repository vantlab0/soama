-- ============================================================================
-- SOAMA MARKETPLACE: PRODUCTION DATABASE SCHEMA
-- Migration: 20261025000001_initial_schema.sql
-- Description: Core schema, enums, tables, constraints, foreign keys, and indexes.
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 2. ENUM TYPES
DO $$ BEGIN
    CREATE TYPE user_app_mode AS ENUM ('customer', 'provider');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE provider_verification_status AS ENUM (
        'incomplete',
        'pending_verification',
        'approved',
        'rejected',
        'suspended'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE service_delivery_mode AS ENUM (
        'at_customer_location',
        'at_provider_workshop',
        'remote_or_consultation'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE offer_sender_role AS ENUM ('customer', 'provider');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE offer_status AS ENUM (
        'pending',
        'countered',
        'accepted',
        'rejected',
        'expired',
        'withdrawn'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE negotiation_status AS ENUM (
        'draft',
        'submitted',
        'in_negotiation',
        'offer_accepted',
        'booked',
        'cancelled',
        'expired'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE booking_escrow_status AS ENUM (
        'awaiting_payment',
        'held_in_escrow',
        'released_to_provider',
        'refunded_to_customer',
        'disputed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE booking_job_status AS ENUM (
        'pending_confirmation',
        'confirmed',
        'in_progress',
        'completed',
        'cancelled_by_customer',
        'cancelled_by_provider',
        'disputed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_gateway_name AS ENUM ('paystack', 'flutterwave', 'stripe', 'manual_bank_transfer');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM (
        'pending',
        'authorized',
        'successful',
        'failed',
        'refunded'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payout_status AS ENUM (
        'pending',
        'processing',
        'completed',
        'failed',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE dispute_status AS ENUM (
        'opened',
        'under_review',
        'resolved_provider_payout',
        'resolved_customer_refund',
        'resolved_split',
        'dismissed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. TABLES

-- 3.1 PROFILES (Personal Identity tied 1:1 to Supabase Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL CHECK (char_length(trim(full_name)) >= 2),
    email TEXT UNIQUE NOT NULL CHECK (email ~* '^.+@.+\..+$'),
    phone TEXT,
    avatar_url TEXT,
    selected_app_mode user_app_mode NOT NULL DEFAULT 'customer',
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.2 SAVED ADDRESSES (Customer private address book)
CREATE TABLE IF NOT EXISTS public.saved_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    label TEXT NOT NULL DEFAULT 'Home',
    street_address TEXT NOT NULL,
    apartment_suite TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    postal_code TEXT,
    country_code TEXT NOT NULL DEFAULT 'NG',
    location geography(Point, 4326) NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.3 SERVICE CATEGORIES
CREATE TABLE IF NOT EXISTS public.service_categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon_name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.4 PROVIDER PROFILES (Professional identity tied 1:1 to Profiles)
CREATE TABLE IF NOT EXISTS public.provider_profiles (
    id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL CHECK (char_length(trim(business_name)) >= 2),
    bio TEXT,
    verification_status provider_verification_status NOT NULL DEFAULT 'incomplete',
    years_experience INT NOT NULL DEFAULT 0 CHECK (years_experience >= 0),
    is_accepting_jobs BOOLEAN NOT NULL DEFAULT TRUE,
    id_card_url TEXT,
    proof_of_address_url TEXT,
    trade_license_url TEXT,
    submitted_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,
    rating_avg NUMERIC(3, 2) NOT NULL DEFAULT 0.00 CHECK (rating_avg >= 0.00 AND rating_avg <= 5.00),
    rating_count INT NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
    completed_jobs_count INT NOT NULL DEFAULT 0 CHECK (completed_jobs_count >= 0),
    base_location geography(Point, 4326),
    service_radius_meters INT NOT NULL DEFAULT 15000 CHECK (service_radius_meters >= 500 AND service_radius_meters <= 100000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.5 PROVIDER SERVICE AREAS (Polygonal coverage or named zones)
CREATE TABLE IF NOT EXISTS public.provider_service_areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE CASCADE,
    area_name TEXT NOT NULL,
    boundary geography(Polygon, 4326),
    radius_meters INT,
    center_location geography(Point, 4326),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.6 PROVIDER SERVICES (Catalog of skills / pricing offered by provider)
CREATE TABLE IF NOT EXISTS public.provider_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE CASCADE,
    category_id TEXT NOT NULL REFERENCES public.service_categories(id) ON DELETE RESTRICT,
    title TEXT NOT NULL CHECK (char_length(trim(title)) >= 3),
    description TEXT,
    base_price_minor_units BIGINT NOT NULL CHECK (base_price_minor_units >= 0),
    currency TEXT NOT NULL DEFAULT 'NGN',
    pricing_type TEXT NOT NULL DEFAULT 'negotiable' CHECK (pricing_type IN ('fixed', 'hourly', 'negotiable')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.7 SERVICE REQUESTS (Customer requests for quote or service)
CREATE TABLE IF NOT EXISTS public.service_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category_id TEXT NOT NULL REFERENCES public.service_categories(id) ON DELETE RESTRICT,
    title TEXT NOT NULL CHECK (char_length(trim(title)) >= 4),
    description TEXT NOT NULL CHECK (char_length(trim(description)) >= 10),
    urgency TEXT NOT NULL DEFAULT 'standard' CHECK (urgency IN ('flexible', 'standard', 'urgent', 'emergency')),
    delivery_mode service_delivery_mode NOT NULL DEFAULT 'at_customer_location',
    location_area TEXT NOT NULL, -- Public city/neighborhood label (e.g. "Airport Road, Effurun")
    exact_address TEXT,          -- Private address (disclosed only on confirmed booking)
    location geography(Point, 4326) NOT NULL,
    preferred_schedule_start TIMESTAMPTZ NOT NULL,
    preferred_schedule_end TIMESTAMPTZ,
    budget_minor_units BIGINT CHECK (budget_minor_units IS NULL OR budget_minor_units >= 0),
    currency TEXT NOT NULL DEFAULT 'NGN',
    negotiation_status negotiation_status NOT NULL DEFAULT 'submitted',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.8 REQUEST RECIPIENTS (Providers targeted or invited for a request)
CREATE TABLE IF NOT EXISTS public.request_recipients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'dispatched' CHECK (status IN ('dispatched', 'viewed', 'declined', 'offered')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE(request_id, provider_id)
);

-- 3.9 PRICE OFFERS (Immutable negotiation audit trail)
CREATE TABLE IF NOT EXISTS public.price_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    sender_role offer_sender_role NOT NULL,
    amount_minor_units BIGINT NOT NULL CHECK (amount_minor_units > 0),
    currency TEXT NOT NULL DEFAULT 'NGN',
    message TEXT,
    status offer_status NOT NULL DEFAULT 'pending',
    valid_until TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc', now()) + INTERVAL '72 hours'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.10 BOOKINGS (Crystallized agreement from an accepted offer)
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_reference TEXT UNIQUE NOT NULL,
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE RESTRICT,
    accepted_offer_id UUID UNIQUE NOT NULL REFERENCES public.price_offers(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE RESTRICT,
    service_title TEXT NOT NULL,
    agreed_price_minor_units BIGINT NOT NULL CHECK (agreed_price_minor_units > 0),
    currency TEXT NOT NULL DEFAULT 'NGN',
    scheduled_start TIMESTAMPTZ NOT NULL,
    scheduled_end TIMESTAMPTZ,
    job_location geography(Point, 4326) NOT NULL,
    job_address TEXT NOT NULL,
    job_status booking_job_status NOT NULL DEFAULT 'pending_confirmation',
    escrow_status booking_escrow_status NOT NULL DEFAULT 'awaiting_payment',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.11 CONVERSATIONS (Communication channels tied to requests/bookings)
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID REFERENCES public.service_requests(id) ON DELETE SET NULL,
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE RESTRICT,
    last_message_preview TEXT,
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    customer_unread_count INT NOT NULL DEFAULT 0 CHECK (customer_unread_count >= 0),
    provider_unread_count INT NOT NULL DEFAULT 0 CHECK (provider_unread_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE(request_id, customer_id, provider_id)
);

-- 3.12 MESSAGES (Direct messages between customer & provider)
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    content TEXT NOT NULL CHECK (char_length(trim(content)) >= 1),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    attachment_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.13 REVIEWS (Ratings & feedback for completed bookings)
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID UNIQUE NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE RESTRICT,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.14 NOTIFICATIONS (In-app notifications for users)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL CHECK (notification_type IN (
        'service_request_received',
        'price_offer_received',
        'offer_countered',
        'offer_accepted',
        'booking_confirmed',
        'job_started',
        'job_completed',
        'payment_received',
        'escrow_released',
        'new_chat_message',
        'review_received',
        'dispute_opened'
    )),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    reference_id UUID,
    reference_type TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.15 PAYMENTS (Transaction records for escrow deposits)
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    gateway payment_gateway_name NOT NULL,
    gateway_reference TEXT UNIQUE NOT NULL,
    amount_minor_units BIGINT NOT NULL CHECK (amount_minor_units > 0),
    fee_minor_units BIGINT NOT NULL DEFAULT 0 CHECK (fee_minor_units >= 0),
    currency TEXT NOT NULL DEFAULT 'NGN',
    payment_status payment_status NOT NULL DEFAULT 'pending',
    gateway_metadata JSONB,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.16 PAYOUTS (Disbursements to provider bank accounts)
CREATE TABLE IF NOT EXISTS public.payouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE RESTRICT,
    payout_reference TEXT UNIQUE NOT NULL,
    gross_amount_minor_units BIGINT NOT NULL CHECK (gross_amount_minor_units > 0),
    platform_commission_minor_units BIGINT NOT NULL DEFAULT 0 CHECK (platform_commission_minor_units >= 0),
    net_payout_minor_units BIGINT NOT NULL CHECK (net_payout_minor_units > 0),
    currency TEXT NOT NULL DEFAULT 'NGN',
    bank_name TEXT NOT NULL,
    account_number_last4 TEXT NOT NULL,
    payout_status payout_status NOT NULL DEFAULT 'pending',
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3.17 DISPUTES (Complaints & resolutions)
CREATE TABLE IF NOT EXISTS public.disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID UNIQUE NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
    raised_by_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    reason TEXT NOT NULL CHECK (char_length(trim(reason)) >= 10),
    evidence_urls TEXT[],
    dispute_status dispute_status NOT NULL DEFAULT 'opened',
    resolution_notes TEXT,
    resolved_by UUID REFERENCES auth.users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 4. PERFORMANCE AND SPATIAL INDEXES
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_saved_addresses_user ON public.saved_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_addresses_location ON public.saved_addresses USING GIST(location);

CREATE INDEX IF NOT EXISTS idx_provider_profiles_status ON public.provider_profiles(verification_status, is_accepting_jobs);
CREATE INDEX IF NOT EXISTS idx_provider_profiles_rating ON public.provider_profiles(rating_avg DESC);
CREATE INDEX IF NOT EXISTS idx_provider_profiles_location ON public.provider_profiles USING GIST(base_location);

CREATE INDEX IF NOT EXISTS idx_provider_service_areas_boundary ON public.provider_service_areas USING GIST(boundary);
CREATE INDEX IF NOT EXISTS idx_provider_service_areas_center ON public.provider_service_areas USING GIST(center_location);

CREATE INDEX IF NOT EXISTS idx_provider_services_category ON public.provider_services(category_id, is_active);
CREATE INDEX IF NOT EXISTS idx_provider_services_provider ON public.provider_services(provider_id);

CREATE INDEX IF NOT EXISTS idx_service_requests_customer ON public.service_requests(customer_id, negotiation_status);
CREATE INDEX IF NOT EXISTS idx_service_requests_category ON public.service_requests(category_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_location ON public.service_requests USING GIST(location);

CREATE INDEX IF NOT EXISTS idx_request_recipients_provider ON public.request_recipients(provider_id, status);
CREATE INDEX IF NOT EXISTS idx_price_offers_request ON public.price_offers(request_id, status);
CREATE INDEX IF NOT EXISTS idx_price_offers_sender ON public.price_offers(sender_id);

CREATE INDEX IF NOT EXISTS idx_bookings_customer ON public.bookings(customer_id, job_status);
CREATE INDEX IF NOT EXISTS idx_bookings_provider ON public.bookings(provider_id, job_status);
CREATE INDEX IF NOT EXISTS idx_bookings_location ON public.bookings USING GIST(job_location);

CREATE INDEX IF NOT EXISTS idx_conversations_customer ON public.conversations(customer_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_provider ON public.conversations(provider_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(conversation_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_reviews_provider ON public.reviews(provider_id, rating);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_booking ON public.payments(booking_id, payment_status);
CREATE INDEX IF NOT EXISTS idx_payouts_provider ON public.payouts(provider_id, payout_status);
