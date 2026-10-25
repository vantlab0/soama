-- ============================================================================
-- SOAMA MARKETPLACE: SERVICE REQUESTS & PRICE NEGOTIATION WORKFLOW
-- Migration: 20261025000005_service_requests_and_negotiation.sql
-- Description: Atomic procedures and RLS policies for service requests,
--              provider dispatching, and price negotiation offers.
-- ============================================================================

-- 1. RLS POLICIES FOR REQUEST RECIPIENTS (INSERT)
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'request_recipients' 
          AND policyname = 'Customers can dispatch request recipients'
    ) THEN
        CREATE POLICY "Customers can dispatch request recipients"
        ON public.request_recipients FOR INSERT
        TO authenticated
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM public.service_requests sr
                WHERE sr.id = request_recipients.request_id
                AND sr.customer_id = auth.uid()
            )
        );
    END IF;
END $$;

-- 2. ATOMIC REQUEST CREATION WITH RECIPIENT DISPATCH
CREATE OR REPLACE FUNCTION public.create_service_request_with_recipient(
    p_category_id TEXT,
    p_title TEXT,
    p_description TEXT,
    p_urgency TEXT,
    p_delivery_mode public.service_delivery_mode,
    p_location_area TEXT,
    p_exact_address TEXT,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_preferred_schedule_start TIMESTAMPTZ,
    p_preferred_schedule_end TIMESTAMPTZ,
    p_budget_minor_units BIGINT,
    p_currency TEXT,
    p_target_provider_id UUID DEFAULT NULL,
    p_initial_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_customer_id UUID;
    v_request_id UUID;
    v_location geography(Point, 4326);
BEGIN
    v_customer_id := auth.uid();
    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to create a service request.';
    END IF;

    -- Validate description & title length
    IF char_length(trim(p_title)) < 4 THEN
        RAISE EXCEPTION 'Title must be at least 4 characters long.';
    END IF;
    IF char_length(trim(p_description)) < 10 THEN
        RAISE EXCEPTION 'Description must be at least 10 characters long.';
    END IF;

    -- Default location to Warri City center (5.75, 5.52) if not specified
    IF p_latitude IS NULL OR p_longitude IS NULL THEN
        v_location := ST_SetSRID(ST_MakePoint(5.75, 5.52), 4326)::geography;
    ELSE
        v_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;
    END IF;

    -- 1. Insert service request
    INSERT INTO public.service_requests (
        customer_id,
        category_id,
        title,
        description,
        urgency,
        delivery_mode,
        location_area,
        exact_address,
        location,
        preferred_schedule_start,
        preferred_schedule_end,
        budget_minor_units,
        currency,
        negotiation_status
    ) VALUES (
        v_customer_id,
        p_category_id,
        trim(p_title),
        trim(p_description),
        COALESCE(p_urgency, 'standard'),
        p_delivery_mode,
        p_location_area,
        p_exact_address,
        v_location,
        p_preferred_schedule_start,
        p_preferred_schedule_end,
        p_budget_minor_units,
        COALESCE(p_currency, 'NGN'),
        CASE WHEN p_budget_minor_units IS NOT NULL AND p_budget_minor_units > 0 
             THEN 'submitted'::public.negotiation_status 
             ELSE 'draft'::public.negotiation_status 
        END
    )
    RETURNING id INTO v_request_id;

    -- 2. Dispatch to target provider if specified
    IF p_target_provider_id IS NOT NULL THEN
        INSERT INTO public.request_recipients (
            request_id,
            provider_id,
            status
        ) VALUES (
            v_request_id,
            p_target_provider_id,
            'dispatched'
        )
        ON CONFLICT (request_id, provider_id) DO NOTHING;
    END IF;

    -- 3. Create initial customer price offer if budget specified
    IF p_budget_minor_units IS NOT NULL AND p_budget_minor_units > 0 THEN
        INSERT INTO public.price_offers (
            request_id,
            sender_id,
            sender_role,
            amount_minor_units,
            currency,
            message,
            status
        ) VALUES (
            v_request_id,
            v_customer_id,
            'customer'::public.offer_sender_role,
            p_budget_minor_units,
            COALESCE(p_currency, 'NGN'),
            COALESCE(p_initial_message, 'Initial service request budget.'),
            'pending'::public.offer_status
        );
    END IF;

    RETURN v_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. SUBMIT PRICE OFFER / COUNTEROFFER
CREATE OR REPLACE FUNCTION public.submit_price_offer(
    p_request_id UUID,
    p_amount_minor_units BIGINT,
    p_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_caller_id UUID;
    v_request RECORD;
    v_role public.offer_sender_role;
    v_offer_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to submit an offer.';
    END IF;

    IF p_amount_minor_units <= 0 THEN
        RAISE EXCEPTION 'Offer amount must be greater than zero.';
    END IF;

    -- Inspect service request
    SELECT * INTO v_request
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found.';
    END IF;

    IF v_request.negotiation_status IN ('booked', 'cancelled', 'expired') THEN
        RAISE EXCEPTION 'Negotiation is closed for this request (current status: %).', v_request.negotiation_status;
    END IF;

    -- Determine role
    IF v_request.customer_id = v_caller_id THEN
        v_role := 'customer'::public.offer_sender_role;
    ELSIF EXISTS (
        SELECT 1 FROM public.request_recipients rr
        WHERE rr.request_id = p_request_id AND rr.provider_id = v_caller_id
    ) THEN
        v_role := 'provider'::public.offer_sender_role;
    ELSE
        RAISE EXCEPTION 'Caller is not authorized to submit offers for this request.';
    END IF;

    -- Mark previous pending offers from this sender as countered/superseded
    UPDATE public.price_offers
    SET status = 'countered', updated_at = timezone('utc', now())
    WHERE request_id = p_request_id 
      AND sender_id = v_caller_id 
      AND status = 'pending';

    -- Insert new offer
    INSERT INTO public.price_offers (
        request_id,
        sender_id,
        sender_role,
        amount_minor_units,
        currency,
        message,
        status
    ) VALUES (
        p_request_id,
        v_caller_id,
        v_role,
        p_amount_minor_units,
        v_request.currency,
        trim(p_message),
        'pending'::public.offer_status
    )
    RETURNING id INTO v_offer_id;

    -- Update request status to in_negotiation
    UPDATE public.service_requests
    SET negotiation_status = 'in_negotiation', updated_at = timezone('utc', now())
    WHERE id = p_request_id;

    -- If provider submitted, update recipient status to 'offered'
    IF v_role = 'provider' THEN
        UPDATE public.request_recipients
        SET status = 'offered'
        WHERE request_id = p_request_id AND provider_id = v_caller_id;
    END IF;

    RETURN v_offer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. REJECT PRICE OFFER
CREATE OR REPLACE FUNCTION public.reject_price_offer(
    p_offer_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_offer RECORD;
    v_request RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to reject an offer.';
    END IF;

    SELECT * INTO v_offer FROM public.price_offers WHERE id = p_offer_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Price offer not found.';
    END IF;

    IF v_offer.status != 'pending' THEN
        RAISE EXCEPTION 'Only pending offers can be rejected (current status: %).', v_offer.status;
    END IF;

    SELECT * INTO v_request FROM public.service_requests WHERE id = v_offer.request_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Associated request not found.';
    END IF;

    -- Caller must be recipient of the offer
    IF v_offer.sender_role = 'provider' AND v_request.customer_id != v_caller_id THEN
        RAISE EXCEPTION 'Only the customer can reject a provider offer.';
    ELSIF v_offer.sender_role = 'customer' AND NOT EXISTS (
        SELECT 1 FROM public.request_recipients rr
        WHERE rr.request_id = v_request.id AND rr.provider_id = v_caller_id
    ) THEN
        RAISE EXCEPTION 'Only an invited provider can reject this customer offer.';
    END IF;

    UPDATE public.price_offers
    SET status = 'rejected', updated_at = timezone('utc', now())
    WHERE id = p_offer_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. CANCEL SERVICE REQUEST
CREATE OR REPLACE FUNCTION public.cancel_service_request(
    p_request_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_request RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to cancel a request.';
    END IF;

    SELECT * INTO v_request FROM public.service_requests WHERE id = p_request_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found.';
    END IF;

    IF v_request.customer_id != v_caller_id THEN
        RAISE EXCEPTION 'Only the request creator can cancel this request.';
    END IF;

    IF v_request.negotiation_status = 'booked' THEN
        RAISE EXCEPTION 'Cannot cancel a request that has already been booked.';
    END IF;

    -- Mark request cancelled
    UPDATE public.service_requests
    SET negotiation_status = 'cancelled', updated_at = timezone('utc', now())
    WHERE id = p_request_id;

    -- Withdraw any pending offers
    UPDATE public.price_offers
    SET status = 'withdrawn', updated_at = timezone('utc', now())
    WHERE request_id = p_request_id AND status = 'pending';

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
