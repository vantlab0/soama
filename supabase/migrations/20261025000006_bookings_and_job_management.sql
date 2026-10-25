-- ============================================================================
-- SOAMA MARKETPLACE: BOOKINGS & JOB LIFECYCLE MANAGEMENT
-- Migration: 20261025000006_bookings_and_job_management.sql
-- Description: Atomic procedures, state transition machine, and RLS policies
--              for customer bookings and provider job execution.
-- ============================================================================

-- 1. RLS POLICIES FOR BOOKINGS TABLE
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'bookings' 
          AND policyname = 'Bookings viewable by customer and provider'
    ) THEN
        CREATE POLICY "Bookings viewable by customer and provider"
        ON public.bookings FOR SELECT
        TO authenticated
        USING (customer_id = auth.uid() OR provider_id = auth.uid());
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'bookings' 
          AND policyname = 'Participants can update booking status within allowed states'
    ) THEN
        CREATE POLICY "Participants can update booking status within allowed states"
        ON public.bookings FOR UPDATE
        TO authenticated
        USING (customer_id = auth.uid() OR provider_id = auth.uid())
        WITH CHECK (
            customer_id = (SELECT b.customer_id FROM public.bookings b WHERE b.id = id)
            AND provider_id = (SELECT b.provider_id FROM public.bookings b WHERE b.id = id)
            AND agreed_price_minor_units = (SELECT b.agreed_price_minor_units FROM public.bookings b WHERE b.id = id)
            AND escrow_status = (SELECT b.escrow_status FROM public.bookings b WHERE b.id = id)
        );
    END IF;
END $$;

-- 2. IDEMPOTENT ATOMIC OFFER ACCEPTANCE & BOOKING CREATION
CREATE OR REPLACE FUNCTION public.accept_price_offer_and_create_booking(
    p_offer_id UUID,
    p_caller_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_caller_id UUID;
    v_offer RECORD;
    v_request RECORD;
    v_provider_id UUID;
    v_booking_id UUID;
    v_booking_ref TEXT;
BEGIN
    -- Determine authenticated or explicit caller
    v_caller_id := COALESCE(auth.uid(), p_caller_id);
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Caller identity required to accept price offer.';
    END IF;

    -- 1. Idempotency check: If booking already exists for this accepted offer, return it
    SELECT id INTO v_booking_id
    FROM public.bookings
    WHERE accepted_offer_id = p_offer_id;

    IF v_booking_id IS NOT NULL THEN
        RETURN v_booking_id;
    END IF;

    -- 2. Lock offer and inspect state
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

    -- 3. Lock service request
    SELECT * INTO v_request
    FROM public.service_requests
    WHERE id = v_offer.request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Associated service request not found.';
    END IF;

    -- 4. Determine provider and verify authorization
    IF v_offer.sender_role = 'provider' THEN
        v_provider_id := v_offer.sender_id;
        -- Customer must accept provider's offer
        IF v_request.customer_id != v_caller_id THEN
            RAISE EXCEPTION 'Only the customer who created the request can accept this offer.';
        END IF;
    ELSE
        -- Customer made the offer; designated provider must accept
        IF v_offer.sender_id != v_request.customer_id THEN
            RAISE EXCEPTION 'Invalid sender credentials for offer.';
        END IF;
        
        -- Identify provider recipient
        SELECT provider_id INTO v_provider_id
        FROM public.request_recipients
        WHERE request_id = v_request.id AND provider_id = v_caller_id;

        IF v_provider_id IS NULL THEN
            RAISE EXCEPTION 'Caller is not a designated recipient provider for this request.';
        END IF;
    END IF;

    -- 5. Mark accepted offer
    UPDATE public.price_offers
    SET status = 'accepted', updated_at = timezone('utc', now())
    WHERE id = p_offer_id;

    -- 6. Mark other pending offers for this request as countered
    UPDATE public.price_offers
    SET status = 'countered', updated_at = timezone('utc', now())
    WHERE request_id = v_request.id AND id != p_offer_id AND status = 'pending';

    -- 7. Update service request negotiation status
    UPDATE public.service_requests
    SET negotiation_status = 'offer_accepted',
        status = 'Confirmed Appointment',
        updated_at = timezone('utc', now())
    WHERE id = v_request.id;

    -- 8. Generate readable unique booking reference: BK-YYYYMMDD-XXXXX
    v_booking_ref := 'BK-' || to_char(timezone('utc', now()), 'YYYYMMDD') || '-' || upper(substring(md5(random()::text) from 1 for 5));

    -- 9. Create booking record with initial confirmed status
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
        COALESCE(v_request.preferred_schedule_start, timezone('utc', now())),
        v_request.preferred_schedule_end,
        COALESCE(v_request.location, ST_SetSRID(ST_MakePoint(5.75, 5.52), 4326)::geography),
        COALESCE(v_request.exact_address, v_request.location_area),
        'confirmed',
        'awaiting_payment'
    )
    RETURNING id INTO v_booking_id;

    RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. ATOMIC BOOKING LIFECYCLE TRANSITION MACHINE
CREATE OR REPLACE FUNCTION public.update_booking_job_status(
    p_booking_id UUID,
    p_new_status public.booking_job_status,
    p_reason TEXT DEFAULT NULL,
    p_caller_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_booking RECORD;
    v_started_at TIMESTAMPTZ;
    v_completed_at TIMESTAMPTZ;
    v_cancelled_at TIMESTAMPTZ;
BEGIN
    v_caller_id := COALESCE(auth.uid(), p_caller_id);
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Caller identity required to update booking status.';
    END IF;

    -- Lock booking row
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking % not found.', p_booking_id;
    END IF;

    -- Verify caller is a booking participant
    IF v_booking.customer_id != v_caller_id AND v_booking.provider_id != v_caller_id THEN
        RAISE EXCEPTION 'Unauthorized: Caller is neither the customer nor the assigned provider.';
    END IF;

    -- Validate state transitions
    CASE p_new_status
        WHEN 'confirmed' THEN
            IF v_booking.job_status != 'pending_confirmation' THEN
                RAISE EXCEPTION 'Booking cannot be confirmed from current status (%).', v_booking.job_status;
            END IF;

        WHEN 'in_progress' THEN
            -- Only assigned provider can start the work
            IF v_caller_id != v_booking.provider_id THEN
                RAISE EXCEPTION 'Only the assigned provider can start the job.';
            END IF;
            IF v_booking.job_status NOT IN ('pending_confirmation', 'confirmed') THEN
                RAISE EXCEPTION 'Job cannot be started from current status (%).', v_booking.job_status;
            END IF;
            v_started_at := timezone('utc', now());

        WHEN 'completed' THEN
            -- Either provider or customer can confirm completion of in-progress job
            IF v_booking.job_status != 'in_progress' AND v_booking.job_status != 'confirmed' THEN
                RAISE EXCEPTION 'Only an ongoing job can be marked as completed (current status: %).', v_booking.job_status;
            END IF;
            v_completed_at := timezone('utc', now());

        WHEN 'cancelled_by_customer' THEN
            -- Only customer can cancel
            IF v_caller_id != v_booking.customer_id THEN
                RAISE EXCEPTION 'Only the customer can record customer cancellation.';
            END IF;
            -- Cannot cancel once job is in progress or completed
            IF v_booking.job_status IN ('in_progress', 'completed', 'cancelled_by_customer', 'cancelled_by_provider') THEN
                RAISE EXCEPTION 'Job cannot be cancelled in status (%).', v_booking.job_status;
            END IF;
            v_cancelled_at := timezone('utc', now());

        WHEN 'cancelled_by_provider' THEN
            -- Only provider can cancel
            IF v_caller_id != v_booking.provider_id THEN
                RAISE EXCEPTION 'Only the assigned provider can record provider cancellation.';
            END IF;
            -- Cannot cancel once job is in progress or completed
            IF v_booking.job_status IN ('in_progress', 'completed', 'cancelled_by_customer', 'cancelled_by_provider') THEN
                RAISE EXCEPTION 'Job cannot be cancelled in status (%).', v_booking.job_status;
            END IF;
            v_cancelled_at := timezone('utc', now());

        ELSE
            RAISE EXCEPTION 'Unsupported status transition to %.', p_new_status;
    END CASE;

    -- Perform atomic update
    UPDATE public.bookings
    SET job_status = p_new_status,
        started_at = COALESCE(v_started_at, started_at),
        completed_at = COALESCE(v_completed_at, completed_at),
        cancelled_at = COALESCE(v_cancelled_at, cancelled_at),
        cancellation_reason = COALESCE(p_reason, cancellation_reason),
        updated_at = timezone('utc', now())
    WHERE id = p_booking_id;

    -- Synchronize associated service request status
    IF p_new_status = 'completed' THEN
        UPDATE public.service_requests
        SET status = 'Completed', updated_at = timezone('utc', now())
        WHERE id = v_booking.request_id;
    ELSIF p_new_status IN ('cancelled_by_customer', 'cancelled_by_provider') THEN
        UPDATE public.service_requests
        SET status = 'Request Cancelled',
            negotiation_status = 'request_cancelled',
            updated_at = timezone('utc', now())
        WHERE id = v_booking.request_id;
    ELSIF p_new_status = 'in_progress' THEN
        UPDATE public.service_requests
        SET status = 'In Progress', updated_at = timezone('utc', now())
        WHERE id = v_booking.request_id;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
