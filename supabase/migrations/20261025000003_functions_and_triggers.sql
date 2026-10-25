-- ============================================================================
-- SOAMA MARKETPLACE: STORED PROCEDURES, TRIGGERS & SPATIAL FUNCTIONS
-- Migration: 20261025000003_functions_and_triggers.sql
-- Description: Atomic state transition functions, PostGIS queries, and maintenance triggers.
-- ============================================================================

-- 1. AUTOMATIC TIMESTAMPS TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
DROP TRIGGER IF EXISTS trigger_profiles_updated_at ON public.profiles;
CREATE TRIGGER trigger_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_saved_addresses_updated_at ON public.saved_addresses;
CREATE TRIGGER trigger_saved_addresses_updated_at BEFORE UPDATE ON public.saved_addresses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_provider_profiles_updated_at ON public.provider_profiles;
CREATE TRIGGER trigger_provider_profiles_updated_at BEFORE UPDATE ON public.provider_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_provider_services_updated_at ON public.provider_services;
CREATE TRIGGER trigger_provider_services_updated_at BEFORE UPDATE ON public.provider_services FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_service_requests_updated_at ON public.service_requests;
CREATE TRIGGER trigger_service_requests_updated_at BEFORE UPDATE ON public.service_requests FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_price_offers_updated_at ON public.price_offers;
CREATE TRIGGER trigger_price_offers_updated_at BEFORE UPDATE ON public.price_offers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_bookings_updated_at ON public.bookings;
CREATE TRIGGER trigger_bookings_updated_at BEFORE UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_conversations_updated_at ON public.conversations;
CREATE TRIGGER trigger_conversations_updated_at BEFORE UPDATE ON public.conversations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_payments_updated_at ON public.payments;
CREATE TRIGGER trigger_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_payouts_updated_at ON public.payouts;
CREATE TRIGGER trigger_payouts_updated_at BEFORE UPDATE ON public.payouts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_disputes_updated_at ON public.disputes;
CREATE TRIGGER trigger_disputes_updated_at BEFORE UPDATE ON public.disputes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 2. NEW USER INITIALIZATION TRIGGER
-- Automatically creates a public profile row when auth.users is populated
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        NEW.email,
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. ATOMIC STATE TRANSITION: ACCEPT OFFER & CREATE BOOKING
CREATE OR REPLACE FUNCTION public.accept_price_offer_and_create_booking(
    p_offer_id UUID,
    p_caller_id UUID
)
RETURNS UUID AS $$
DECLARE
    v_offer RECORD;
    v_request RECORD;
    v_provider_id UUID;
    v_booking_id UUID;
    v_booking_ref TEXT;
BEGIN
    -- 1. Lock offer and inspect state
    SELECT * INTO v_offer
    FROM public.price_offers
    WHERE id = p_offer_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Price offer not found.';
    END IF;

    IF v_offer.status != 'pending' THEN
        RAISE EXCEPTION 'Offer is no longer active (current status: %).', v_offer.status;
    END IF;

    IF v_offer.valid_until < timezone('utc', now()) THEN
        UPDATE public.price_offers SET status = 'expired' WHERE id = p_offer_id;
        RAISE EXCEPTION 'Offer has expired.';
    END IF;

    -- 2. Lock service request
    SELECT * INTO v_request
    FROM public.service_requests
    WHERE id = v_offer.request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Associated service request not found.';
    END IF;

    -- 3. Determine provider and verify authorization
    IF v_offer.sender_role = 'provider' THEN
        v_provider_id := v_offer.sender_id;
        -- Customer must accept provider's offer
        IF v_request.customer_id != p_caller_id THEN
            RAISE EXCEPTION 'Only the customer who created the request can accept this offer.';
        END IF;
    ELSE
        -- Customer made the offer; recipient provider must accept
        IF v_offer.sender_id != v_request.customer_id THEN
            RAISE EXCEPTION 'Invalid sender credentials for offer.';
        END IF;
        
        -- Identify provider recipient
        SELECT provider_id INTO v_provider_id
        FROM public.request_recipients
        WHERE request_id = v_request.id AND provider_id = p_caller_id;

        IF v_provider_id IS NULL THEN
            RAISE EXCEPTION 'Caller is not a designated recipient provider for this request.';
        END IF;
    END IF;

    -- 4. Mark accepted offer
    UPDATE public.price_offers
    SET status = 'accepted', updated_at = timezone('utc', now())
    WHERE id = p_offer_id;

    -- 5. Mark other pending offers for this request as countered/withdrawn
    UPDATE public.price_offers
    SET status = 'countered', updated_at = timezone('utc', now())
    WHERE request_id = v_request.id AND id != p_offer_id AND status = 'pending';

    -- 6. Update service request negotiation status
    UPDATE public.service_requests
    SET negotiation_status = 'offer_accepted', updated_at = timezone('utc', now())
    WHERE id = v_request.id;

    -- 7. Generate readable booking reference: BK-YYYYMMDD-XXXX
    v_booking_ref := 'BK-' || to_char(timezone('utc', now()), 'YYYYMMDD') || '-' || upper(substring(md5(random()::text) from 1 for 5));

    -- 8. Create booking record
    INSERT INTO public.bookings (
        booking_reference,
        request_id,
        accepted_offer_id,
        customer_id,
        provider_id,
        service_title,
        agreed_price_minor_units,
        currency,
        scheduled_start,
        scheduled_end,
        job_location,
        job_address,
        job_status,
        escrow_status
    ) VALUES (
        v_booking_ref,
        v_request.id,
        v_offer.id,
        v_request.customer_id,
        v_provider_id,
        v_request.title,
        v_offer.amount_minor_units,
        v_offer.currency,
        v_request.preferred_schedule_start,
        v_request.preferred_schedule_end,
        v_request.location,
        COALESCE(v_request.exact_address, v_request.location_area),
        'pending_confirmation',
        'awaiting_payment'
    )
    RETURNING id INTO v_booking_id;

    -- 9. Create or update conversation association
    UPDATE public.conversations
    SET booking_id = v_booking_id, updated_at = timezone('utc', now())
    WHERE request_id = v_request.id
      AND customer_id = v_request.customer_id
      AND provider_id = v_provider_id;

    -- 10. Create in-app notifications for both parties
    INSERT INTO public.notifications (recipient_id, notification_type, title, body, reference_id, reference_type)
    VALUES 
        (
            v_request.customer_id,
            'offer_accepted',
            'Booking Created (' || v_booking_ref || ')',
            'Offer of ' || (v_offer.amount_minor_units / 100)::text || ' ' || v_offer.currency || ' has been confirmed. Please fund escrow to begin.',
            v_booking_id,
            'booking'
        ),
        (
            v_provider_id,
            'offer_accepted',
            'New Booking Confirmed (' || v_booking_ref || ')',
            'Your offer for "' || v_request.title || '" was accepted. Stand by for customer escrow deposit.',
            v_booking_id,
            'booking'
        );

    RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. POSTGIS SPATIAL SEARCH: FIND NEARBY PROVIDERS
CREATE OR REPLACE FUNCTION public.find_nearby_providers(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_radius_meters INT DEFAULT 25000,
    p_category_id TEXT DEFAULT NULL,
    p_limit INT DEFAULT 30
)
RETURNS TABLE (
    provider_id UUID,
    business_name TEXT,
    bio TEXT,
    rating_avg NUMERIC(3, 2),
    rating_count INT,
    completed_jobs_count INT,
    avatar_url TEXT,
    distance_meters DOUBLE PRECISION,
    matching_services JSONB
) AS $$
DECLARE
    v_user_location geography;
BEGIN
    v_user_location := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;

    RETURN QUERY
    SELECT 
        pp.id AS provider_id,
        pp.business_name,
        pp.bio,
        pp.rating_avg,
        pp.rating_count,
        pp.completed_jobs_count,
        p.avatar_url,
        ST_Distance(pp.base_location, v_user_location) AS distance_meters,
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', ps.id,
                        'title', ps.title,
                        'category_id', ps.category_id,
                        'base_price', ps.base_price_minor_units,
                        'currency', ps.currency,
                        'pricing_type', ps.pricing_type
                    )
                )
                FROM public.provider_services ps
                WHERE ps.provider_id = pp.id 
                  AND ps.is_active = TRUE
                  AND (p_category_id IS NULL OR ps.category_id = p_category_id)
            ),
            '[]'::jsonb
        ) AS matching_services
    FROM public.provider_profiles pp
    JOIN public.profiles p ON p.id = pp.id
    WHERE pp.verification_status = 'approved'
      AND pp.is_accepting_jobs = TRUE
      AND (
          -- Provider base location is within query radius and provider's own service radius
          ST_DWithin(pp.base_location, v_user_location, LEAST(p_radius_meters, pp.service_radius_meters))
          OR EXISTS (
              SELECT 1 FROM public.provider_service_areas psa
              WHERE psa.provider_id = pp.id
                AND psa.is_active = TRUE
                AND (
                    (psa.boundary IS NOT NULL AND ST_Contains(psa.boundary::geometry, v_user_location::geometry))
                    OR (psa.center_location IS NOT NULL AND ST_DWithin(psa.center_location, v_user_location, psa.radius_meters))
                )
          )
      )
      AND (
          p_category_id IS NULL 
          OR EXISTS (
              SELECT 1 FROM public.provider_services ps2
              WHERE ps2.provider_id = pp.id 
                AND ps2.category_id = p_category_id
                AND ps2.is_active = TRUE
          )
      )
    ORDER BY pp.rating_avg DESC, distance_meters ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 5. RATING AGGREGATION TRIGGER ON REVIEWS
CREATE OR REPLACE FUNCTION public.update_provider_rating_aggregate()
RETURNS TRIGGER AS $$
DECLARE
    v_provider_id UUID;
    v_avg NUMERIC(3, 2);
    v_count INT;
BEGIN
    v_provider_id := NEW.provider_id;

    SELECT 
        ROUND(COALESCE(AVG(rating), 0)::numeric, 2),
        COUNT(*)
    INTO v_avg, v_count
    FROM public.reviews
    WHERE provider_id = v_provider_id;

    UPDATE public.provider_profiles
    SET 
        rating_avg = v_avg,
        rating_count = v_count,
        updated_at = timezone('utc', now())
    WHERE id = v_provider_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_reviews_recalculate_rating ON public.reviews;
CREATE TRIGGER trigger_reviews_recalculate_rating
    AFTER INSERT OR UPDATE OR DELETE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.update_provider_rating_aggregate();
