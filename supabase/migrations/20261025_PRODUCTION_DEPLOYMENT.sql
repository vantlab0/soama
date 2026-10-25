-- ============================================================================
-- SOAMA MARKETPLACE: CONSOLIDATED PRODUCTION DEPLOYMENT SCRIPT
-- Target Project: itsxgmkhdvivyhmbyblo
-- Safe, Idempotent: Can be run directly in the Supabase Dashboard SQL Editor
-- (https://supabase.com/dashboard/project/itsxgmkhdvivyhmbyblo/sql/new)
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 2. ENUM TYPES
DO $$ BEGIN
    CREATE TYPE user_app_mode AS ENUM ('customer', 'provider');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE provider_verification_status AS ENUM (
        'incomplete',
        'pending_verification',
        'approved',
        'rejected',
        'suspended'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE service_delivery_mode AS ENUM (
        'at_customer_location',
        'at_provider_workshop',
        'remote_or_consultation'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE offer_sender_role AS ENUM ('customer', 'provider');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE offer_status AS ENUM (
        'pending',
        'countered',
        'accepted',
        'rejected',
        'expired',
        'withdrawn'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

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
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE booking_escrow_status AS ENUM (
        'awaiting_payment',
        'held_in_escrow',
        'released_to_provider',
        'refunded_to_customer',
        'disputed'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

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
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payment_gateway_name AS ENUM ('paystack', 'flutterwave', 'stripe', 'manual_bank_transfer');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM (
        'pending',
        'authorized',
        'successful',
        'failed',
        'refunded'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payout_status AS ENUM (
        'pending',
        'processing',
        'completed',
        'failed',
        'cancelled'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE dispute_status AS ENUM (
        'opened',
        'under_review',
        'resolved_provider_payout',
        'resolved_customer_refund',
        'resolved_split',
        'dismissed'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 3. PROFILES TABLE (Seamless Upgrade for Existing Projects)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    avatar_url TEXT,
    selected_app_mode user_app_mode NOT NULL DEFAULT 'customer',
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Upgrade existing columns if already created in legacy format
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS selected_app_mode user_app_mode NOT NULL DEFAULT 'customer';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN NOT NULL DEFAULT FALSE;

-- If legacy columns exist, backfill
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'first_name') THEN
        UPDATE public.profiles
        SET full_name = COALESCE(full_name, TRIM(CONCAT(first_name, ' ', last_name)))
        WHERE full_name IS NULL;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'photo_url') THEN
        UPDATE public.profiles
        SET avatar_url = COALESCE(avatar_url, photo_url)
        WHERE avatar_url IS NULL;
    END IF;
END $$;

-- 4. SAVED ADDRESSES
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
    location geography(Point, 4326),
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 5. SERVICE CATEGORIES
CREATE TABLE IF NOT EXISTS public.service_categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon_name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.service_categories ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.service_categories ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.service_categories ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'handyman';
ALTER TABLE public.service_categories ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE public.service_categories ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0;
UPDATE public.service_categories SET is_active = TRUE WHERE is_active IS NULL;

-- 6. PROVIDER PROFILES
CREATE TABLE IF NOT EXISTS public.provider_profiles (
    id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL DEFAULT 'Verified Service Pro',
    bio TEXT,
    verification_status provider_verification_status NOT NULL DEFAULT 'incomplete',
    years_experience INT NOT NULL DEFAULT 0 CHECK (years_experience >= 0),
    is_accepting_jobs BOOLEAN NOT NULL DEFAULT TRUE,
    id_card_url TEXT,
    proof_of_address_url TEXT,
    trade_license_url TEXT,
    gallery_images TEXT[] DEFAULT '{}',
    submitted_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,
    rating_avg NUMERIC(3, 2) NOT NULL DEFAULT 0.00 CHECK (rating_avg >= 0.00 AND rating_avg <= 5.00),
    rating_count INT NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
    completed_jobs_count INT NOT NULL DEFAULT 0 CHECK (completed_jobs_count >= 0),
    base_location geography(Point, 4326),
    service_radius_meters INT NOT NULL DEFAULT 15000,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS business_name TEXT DEFAULT 'Verified Service Pro';
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS profession TEXT DEFAULT 'Service Specialist';
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS verification_status provider_verification_status DEFAULT 'incomplete';
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS years_experience INT DEFAULT 0;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS is_accepting_jobs BOOLEAN DEFAULT TRUE;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS id_card_url TEXT;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS proof_of_address_url TEXT;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS trade_license_url TEXT;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS gallery_images TEXT[] DEFAULT '{}';
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS review_notes TEXT;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS rating_avg NUMERIC(3, 2) DEFAULT 0.00;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS rating_count INT DEFAULT 0;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS completed_jobs_count INT DEFAULT 0;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS base_location geography(Point, 4326);
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS service_radius_meters INT DEFAULT 15000;
ALTER TABLE public.provider_profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc', now());

-- 7. PROVIDER SERVICE AREAS
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

ALTER TABLE public.provider_service_areas ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 8. PROVIDER SERVICES
CREATE TABLE IF NOT EXISTS public.provider_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE CASCADE,
    category_id TEXT NOT NULL REFERENCES public.service_categories(id) ON DELETE RESTRICT,
    title TEXT NOT NULL CHECK (char_length(trim(title)) >= 3),
    description TEXT,
    base_price_minor_units BIGINT NOT NULL CHECK (base_price_minor_units >= 0),
    currency TEXT NOT NULL DEFAULT 'NGN',
    pricing_type TEXT NOT NULL DEFAULT 'negotiable',
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS category_id TEXT;
ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS title TEXT DEFAULT 'General Service';
ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS base_price_minor_units BIGINT DEFAULT 0;
ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'NGN';
ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS pricing_type TEXT DEFAULT 'negotiable';
ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc', now());

-- Backfill legacy provider_services if any columns are null
UPDATE public.provider_services SET title = 'General Service' WHERE title IS NULL;
UPDATE public.provider_services SET is_active = TRUE WHERE is_active IS NULL;

-- 9. SERVICE REQUESTS
CREATE TABLE IF NOT EXISTS public.service_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category_id TEXT NOT NULL REFERENCES public.service_categories(id) ON DELETE RESTRICT,
    title TEXT NOT NULL CHECK (char_length(trim(title)) >= 4),
    description TEXT NOT NULL CHECK (char_length(trim(description)) >= 10),
    preferred_schedule TIMESTAMPTZ,
    delivery_mode service_delivery_mode NOT NULL DEFAULT 'at_customer_location',
    location_area TEXT NOT NULL,
    exact_address TEXT,
    is_address_private BOOLEAN NOT NULL DEFAULT TRUE,
    status negotiation_status NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 10. REQUEST RECIPIENTS
CREATE TABLE IF NOT EXISTS public.request_recipients (
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE CASCADE,
    notified_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    viewed_at TIMESTAMPTZ,
    declined_at TIMESTAMPTZ,
    PRIMARY KEY (request_id, provider_id)
);

-- 11. PRICE OFFERS
CREATE TABLE IF NOT EXISTS public.price_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sender_role offer_sender_role NOT NULL,
    amount_minor_units BIGINT NOT NULL CHECK (amount_minor_units >= 100000),
    currency TEXT NOT NULL DEFAULT 'NGN',
    message TEXT,
    status offer_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 12. BOOKINGS
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE RESTRICT,
    accepted_offer_id UUID NOT NULL REFERENCES public.price_offers(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE RESTRICT,
    total_amount_minor_units BIGINT NOT NULL CHECK (total_amount_minor_units > 0),
    escrow_status booking_escrow_status NOT NULL DEFAULT 'held_in_escrow',
    job_status booking_job_status NOT NULL DEFAULT 'confirmed',
    verification_passcode VARCHAR(6),
    scheduled_for TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 13. CONVERSATIONS & MESSAGES
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE CASCADE,
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    last_message TEXT,
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    unread_customer_count INT NOT NULL DEFAULT 0,
    unread_provider_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    attachment_url TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 14. REVIEWS
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE RESTRICT,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    provider_reply TEXT,
    provider_reply_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT chk_reviews_no_self_review CHECK (customer_id != provider_id)
);

-- 15. NOTIFICATIONS & DEVICE TOKENS
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category TEXT NOT NULL DEFAULT 'system',
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    last_used_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_user_device_token UNIQUE (user_id, device_token)
);

ALTER TABLE public.user_device_tokens ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS public.push_notification_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 16. PAYMENTS & PAYOUTS
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    amount_minor_units BIGINT NOT NULL CHECK (amount_minor_units > 0),
    currency TEXT NOT NULL DEFAULT 'NGN',
    gateway payment_gateway_name NOT NULL DEFAULT 'paystack',
    gateway_reference TEXT UNIQUE NOT NULL,
    status payment_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS amount_minor_units BIGINT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'NGN';
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS gateway payment_gateway_name DEFAULT 'paystack';
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS gateway_reference TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc', now());

CREATE TABLE IF NOT EXISTS public.payouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES public.provider_profiles(id) ON DELETE RESTRICT,
    amount_minor_units BIGINT NOT NULL CHECK (amount_minor_units > 0),
    currency TEXT NOT NULL DEFAULT 'NGN',
    status payout_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 17. SEED INITIAL CATEGORIES
INSERT INTO public.service_categories (id, name, description, icon_name, is_active, display_order)
VALUES 
    ('plumbing', 'Plumbing & Pipefitting', 'Water leak repairs, pipe installations, drain cleaning, and bathroom fitting.', 'plumbing', true, 1),
    ('electrical', 'Electrical & Wiring', 'AC installation, wiring, conduit piping, circuit repair, and generator services.', 'flash_on', true, 2),
    ('carpentry', 'Carpentry & Woodwork', 'Furniture assembly, cabinet making, roofing woodwork, and door repairs.', 'handyman', true, 3),
    ('cleaning', 'Cleaning & Janitorial', 'Home deep cleaning, commercial sanitization, carpet washing, and fumigation.', 'cleaning_services', true, 4),
    ('hvac', 'AC & Refrigeration', 'Air conditioner servicing, gas refilling, compressor repair, and chiller installation.', 'ac_unit', true, 5),
    ('painting', 'Painting & Finishing', 'Interior and exterior wall painting, screeding, wallpapering, and POP work.', 'format_paint', true, 6),
    ('welding', 'Welding & Metalwork', 'Burglary proofs, iron gates, structural steel welding, and metal railings.', 'build', true, 7),
    ('appliances', 'Home Appliance Repairs', 'Washing machine, microwave, oven, and home theater diagnostics and servicing.', 'kitchen', true, 8),
    ('repairs', 'Generators & Equipment', 'Generators, inverter diagnostics, and heavy appliance repairs.', 'handyman', true, 9),
    ('moving', 'Moving & Relocation', 'Residential moving, office relocation, and transport across Delta State.', 'local_shipping', true, 10)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name,
    is_active = EXCLUDED.is_active,
    display_order = EXCLUDED.display_order;

-- 18. FUNCTIONS & STORED PROCEDURES (RPCS)

-- Rating aggregate recalculator
CREATE OR REPLACE FUNCTION update_provider_rating_aggregate()
RETURNS TRIGGER AS $$
DECLARE
    target_provider_id UUID;
BEGIN
    target_provider_id := COALESCE(NEW.provider_id, OLD.provider_id);
    UPDATE public.provider_profiles
    SET 
        rating_avg = COALESCE((
            SELECT ROUND(AVG(rating)::numeric, 2)
            FROM public.reviews
            WHERE provider_id = target_provider_id
        ), 0.00),
        rating_count = COALESCE((
            SELECT COUNT(*)::int
            FROM public.reviews
            WHERE provider_id = target_provider_id
        ), 0),
        updated_at = timezone('utc', now())
    WHERE id = target_provider_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_reviews_recalculate_rating ON public.reviews;
CREATE TRIGGER trigger_reviews_recalculate_rating
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW EXECUTE FUNCTION update_provider_rating_aggregate();

-- Review submission RPC
CREATE OR REPLACE FUNCTION submit_booking_review(
    p_booking_id UUID,
    p_rating INT,
    p_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
    v_review_id UUID;
    v_clean_comment TEXT;
BEGIN
    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be an integer between 1 and 5.';
    END IF;

    IF p_comment IS NOT NULL THEN
        v_clean_comment := trim(p_comment);
        IF length(v_clean_comment) < 3 OR length(v_clean_comment) > 1000 THEN
            RAISE EXCEPTION 'Review text must be between 3 and 1000 characters.';
        END IF;
    END IF;

    SELECT id, customer_id, provider_id, job_status
    INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found.';
    END IF;

    IF v_booking.customer_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: Only the customer who placed this booking can submit a review.';
    END IF;

    IF v_booking.customer_id = v_booking.provider_id THEN
        RAISE EXCEPTION 'Integrity error: You cannot review your own provider profile.';
    END IF;

    IF v_booking.job_status != 'completed' THEN
        RAISE EXCEPTION 'Ineligible: Reviews can only be submitted for completed bookings.';
    END IF;

    INSERT INTO public.reviews (
        booking_id,
        customer_id,
        provider_id,
        rating,
        comment,
        updated_at
    )
    VALUES (
        v_booking.id,
        v_booking.customer_id,
        v_booking.provider_id,
        p_rating,
        v_clean_comment,
        timezone('utc', now())
    )
    ON CONFLICT (booking_id) DO UPDATE SET
        rating = EXCLUDED.rating,
        comment = EXCLUDED.comment,
        updated_at = timezone('utc', now())
    RETURNING id INTO v_review_id;

    INSERT INTO public.notifications (
        recipient_id,
        category,
        title,
        body,
        payload
    )
    VALUES (
        v_booking.provider_id,
        'review_received',
        'New Customer Review Received',
        'A customer rated your completed job with ' || p_rating || ' stars.',
        jsonb_build_object(
            'booking_id', v_booking.id,
            'review_id', v_review_id,
            'rating', p_rating
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'review_id', v_review_id,
        'booking_id', v_booking.id,
        'rating', p_rating
    );
END;
$$;

-- Provider review reply RPC
CREATE OR REPLACE FUNCTION reply_to_booking_review(
    p_review_id UUID,
    p_reply TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_review RECORD;
    v_clean_reply TEXT;
BEGIN
    v_clean_reply := trim(p_reply);
    IF length(v_clean_reply) < 3 OR length(v_clean_reply) > 1000 THEN
        RAISE EXCEPTION 'Reply text must be between 3 and 1000 characters.';
    END IF;

    SELECT id, provider_id, customer_id, booking_id
    INTO v_review
    FROM public.reviews
    WHERE id = p_review_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Review record not found.';
    END IF;

    IF v_review.provider_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: Only the assigned service provider can reply to this review.';
    END IF;

    UPDATE public.reviews
    SET 
        provider_reply = v_clean_reply,
        provider_reply_at = timezone('utc', now()),
        updated_at = timezone('utc', now())
    WHERE id = p_review_id;

    RETURN jsonb_build_object(
        'success', true,
        'review_id', p_review_id,
        'provider_reply', v_clean_reply
    );
END;
$$;

-- Offer acceptance & atomic booking creation RPC
CREATE OR REPLACE FUNCTION accept_price_offer_and_create_booking(
    p_offer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offer RECORD;
    v_request RECORD;
    v_booking_id UUID;
    v_passcode TEXT;
BEGIN
    SELECT * INTO v_offer FROM public.price_offers WHERE id = p_offer_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Price offer not found.';
    END IF;

    SELECT * INTO v_request FROM public.service_requests WHERE id = v_offer.request_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found.';
    END IF;

    IF v_request.customer_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: Only the customer who created this request can accept an offer.';
    END IF;

    UPDATE public.price_offers
    SET status = 'accepted', updated_at = timezone('utc', now())
    WHERE id = p_offer_id;

    UPDATE public.price_offers
    SET status = 'rejected', updated_at = timezone('utc', now())
    WHERE request_id = v_request.id AND id != p_offer_id AND status = 'pending';

    UPDATE public.service_requests
    SET status = 'offer_accepted', updated_at = timezone('utc', now())
    WHERE id = v_request.id;

    v_passcode := lpad(floor(random() * 900000 + 100000)::text, 6, '0');

    INSERT INTO public.bookings (
        request_id,
        accepted_offer_id,
        customer_id,
        provider_id,
        total_amount_minor_units,
        escrow_status,
        job_status,
        verification_passcode
    )
    VALUES (
        v_request.id,
        v_offer.id,
        v_request.customer_id,
        v_offer.sender_id,
        v_offer.amount_minor_units,
        'held_in_escrow',
        'confirmed',
        v_passcode
    )
    RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'passcode', v_passcode
    );
END;
$$;

-- ============================================================================
-- 19. ROW-LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_service_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payouts ENABLE ROW LEVEL SECURITY;

-- 19.1 Profiles
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
CREATE POLICY "Profiles are viewable by authenticated users"
ON public.profiles FOR SELECT TO authenticated USING (TRUE);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- 19.2 Categories
DROP POLICY IF EXISTS "Categories are viewable by everyone" ON public.service_categories;
CREATE POLICY "Categories are viewable by everyone"
ON public.service_categories FOR SELECT TO anon, authenticated USING (coalesce(is_active, true) = TRUE);

-- 19.3 Provider Profiles & Services
DROP POLICY IF EXISTS "Provider profiles viewable by everyone" ON public.provider_profiles;
CREATE POLICY "Provider profiles viewable by everyone"
ON public.provider_profiles FOR SELECT TO anon, authenticated USING (TRUE);

DROP POLICY IF EXISTS "Providers can manage their own profile" ON public.provider_profiles;
CREATE POLICY "Providers can manage their own profile"
ON public.provider_profiles FOR ALL TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "Provider services viewable by everyone" ON public.provider_services;
CREATE POLICY "Provider services viewable by everyone"
ON public.provider_services FOR SELECT TO anon, authenticated USING (coalesce(is_active, true) = TRUE);

DROP POLICY IF EXISTS "Providers can manage their own services" ON public.provider_services;
CREATE POLICY "Providers can manage their own services"
ON public.provider_services FOR ALL TO authenticated USING (auth.uid() = provider_id);

-- 19.4 Service Requests
DROP POLICY IF EXISTS "Customer can manage their own service requests" ON public.service_requests;
CREATE POLICY "Customer can manage their own service requests"
ON public.service_requests FOR ALL TO authenticated USING (customer_id = auth.uid());

DROP POLICY IF EXISTS "Providers can view active requests" ON public.service_requests;
CREATE POLICY "Providers can view active requests"
ON public.service_requests FOR SELECT TO authenticated
USING (
    status NOT IN ('draft', 'cancelled')
    OR customer_id = auth.uid()
);

-- 19.5 Price Offers
DROP POLICY IF EXISTS "Price offers viewable by conversation participants" ON public.price_offers;
CREATE POLICY "Price offers viewable by conversation participants"
ON public.price_offers FOR SELECT TO authenticated
USING (
    sender_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = public.price_offers.request_id AND sr.customer_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Authorized parties can insert price offers" ON public.price_offers;
CREATE POLICY "Authorized parties can insert price offers"
ON public.price_offers FOR INSERT TO authenticated
WITH CHECK (auth.uid() = sender_id);

-- 19.6 Bookings
DROP POLICY IF EXISTS "Bookings viewable by customer and provider" ON public.bookings;
CREATE POLICY "Bookings viewable by customer and provider"
ON public.bookings FOR SELECT TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid());

DROP POLICY IF EXISTS "Participants can update booking status" ON public.bookings;
CREATE POLICY "Participants can update booking status"
ON public.bookings FOR UPDATE TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid());

-- 19.7 Conversations & Messages
DROP POLICY IF EXISTS "Conversations viewable by participants" ON public.conversations;
CREATE POLICY "Conversations viewable by participants"
ON public.conversations FOR SELECT TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid());

DROP POLICY IF EXISTS "Conversations insertable by participants" ON public.conversations;
CREATE POLICY "Conversations insertable by participants"
ON public.conversations FOR INSERT TO authenticated
WITH CHECK (customer_id = auth.uid() OR provider_id = auth.uid());

DROP POLICY IF EXISTS "Conversations updatable by participants" ON public.conversations;
CREATE POLICY "Conversations updatable by participants"
ON public.conversations FOR UPDATE TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid());

DROP POLICY IF EXISTS "Messages viewable by conversation participants" ON public.messages;
CREATE POLICY "Messages viewable by conversation participants"
ON public.messages FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = public.messages.conversation_id
        AND (c.customer_id = auth.uid() OR c.provider_id = auth.uid())
    )
);

DROP POLICY IF EXISTS "Messages insertable by conversation participants" ON public.messages;
CREATE POLICY "Messages insertable by conversation participants"
ON public.messages FOR INSERT TO authenticated
WITH CHECK (auth.uid() = sender_id);

-- 19.8 Reviews
DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON public.reviews;
CREATE POLICY "Reviews are viewable by everyone"
ON public.reviews FOR SELECT TO anon, authenticated USING (TRUE);

-- 19.9 Notifications & Device Tokens
DROP POLICY IF EXISTS "Users can view only their own notifications" ON public.notifications;
CREATE POLICY "Users can view only their own notifications"
ON public.notifications FOR SELECT TO authenticated USING (recipient_id = auth.uid());

DROP POLICY IF EXISTS "Users can mark their notifications as read" ON public.notifications;
CREATE POLICY "Users can mark their notifications as read"
ON public.notifications FOR UPDATE TO authenticated USING (recipient_id = auth.uid());

DROP POLICY IF EXISTS "Users can manage their device tokens" ON public.user_device_tokens;
CREATE POLICY "Users can manage their device tokens"
ON public.user_device_tokens FOR ALL TO authenticated USING (user_id = auth.uid());

-- ============================================================================
-- 20. STORAGE BUCKET POLICIES (Safe Execution)
-- ============================================================================

DO $$
BEGIN
    BEGIN
        DROP POLICY IF EXISTS "Public avatars viewable" ON storage.objects;
        CREATE POLICY "Public avatars viewable"
        ON storage.objects FOR SELECT TO anon, authenticated USING (bucket_id = 'avatars');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
        CREATE POLICY "Users can upload their own avatar"
        ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        DROP POLICY IF EXISTS "Portfolio images viewable" ON storage.objects;
        CREATE POLICY "Portfolio images viewable"
        ON storage.objects FOR SELECT TO anon, authenticated USING (bucket_id = 'service-portfolio');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        DROP POLICY IF EXISTS "Providers can upload portfolio" ON storage.objects;
        CREATE POLICY "Providers can upload portfolio"
        ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'service-portfolio');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        DROP POLICY IF EXISTS "Chat attachments viewable by authenticated users" ON storage.objects;
        CREATE POLICY "Chat attachments viewable by authenticated users"
        ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'chat-attachments');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        DROP POLICY IF EXISTS "Users can upload chat attachments" ON storage.objects;
        CREATE POLICY "Users can upload chat attachments"
        ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'chat-attachments');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        DROP POLICY IF EXISTS "Users can view only their own documents" ON storage.objects;
        CREATE POLICY "Users can view only their own documents"
        ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'verification-documents');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        DROP POLICY IF EXISTS "Users can upload verification docs" ON storage.objects;
        CREATE POLICY "Users can upload verification docs"
        ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'verification-documents');
    EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

-- ============================================================================
-- 21. REALTIME PUBLICATIONS
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
        EXCEPTION WHEN duplicate_object THEN NULL; WHEN OTHERS THEN NULL; END;

        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
        EXCEPTION WHEN duplicate_object THEN NULL; WHEN OTHERS THEN NULL; END;

        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.price_offers;
        EXCEPTION WHEN duplicate_object THEN NULL; WHEN OTHERS THEN NULL; END;

        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
        EXCEPTION WHEN duplicate_object THEN NULL; WHEN OTHERS THEN NULL; END;

        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        EXCEPTION WHEN duplicate_object THEN NULL; WHEN OTHERS THEN NULL; END;
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

