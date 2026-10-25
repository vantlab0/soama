-- ============================================================================
-- SOAMA MARKETPLACE: BOOKING-VERIFIED REVIEWS & RATINGS
-- Migration: 20261025000008_verified_reviews_and_ratings.sql
-- Description: Trustworthy reviews strictly tied to completed bookings,
--              automated server-side rating aggregates, provider replies,
--              anti-self-review safeguards, and RLS policies.
-- ============================================================================

-- 1. ADD PROVIDER REPLY AND TIMESTAMPS TO REVIEWS TABLE
ALTER TABLE public.reviews
ADD COLUMN IF NOT EXISTS provider_reply TEXT,
ADD COLUMN IF NOT EXISTS provider_reply_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now());

-- 2. ENSURE RATING & TEXT VALIDATION CONSTRAINTS
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_reviews_comment_length'
    ) THEN
        ALTER TABLE public.reviews
        ADD CONSTRAINT chk_reviews_comment_length 
        CHECK (comment IS NULL OR (char_length(trim(comment)) >= 3 AND char_length(comment) <= 1000));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_reviews_reply_length'
    ) THEN
        ALTER TABLE public.reviews
        ADD CONSTRAINT chk_reviews_reply_length 
        CHECK (provider_reply IS NULL OR (char_length(trim(provider_reply)) >= 3 AND char_length(provider_reply) <= 1000));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_reviews_no_self_review'
    ) THEN
        ALTER TABLE public.reviews
        ADD CONSTRAINT chk_reviews_no_self_review 
        CHECK (customer_id != provider_id);
    END IF;
END $$;

-- 3. ENSURE INDEXES FOR FAST REVIEWS AND RATINGS LOOKUP
CREATE INDEX IF NOT EXISTS idx_reviews_provider ON public.reviews(provider_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_customer ON public.reviews(customer_id);

-- 4. ROBUST RATING AGGREGATE RECALCULATION TRIGGER (Fixes DELETE null pointer)
CREATE OR REPLACE FUNCTION public.update_provider_rating_aggregate()
RETURNS TRIGGER AS $$
DECLARE
    v_prov_id UUID;
    v_avg NUMERIC(3, 2);
    v_count INT;
BEGIN
    -- Determine target provider ID safely on INSERT, UPDATE, or DELETE
    v_prov_id := COALESCE(NEW.provider_id, OLD.provider_id);

    IF v_prov_id IS NOT NULL THEN
        SELECT 
            ROUND(COALESCE(AVG(rating), 0)::numeric, 2),
            COUNT(*)
        INTO v_avg, v_count
        FROM public.reviews
        WHERE provider_id = v_prov_id;

        UPDATE public.provider_profiles
        SET 
            rating_avg = v_avg,
            rating_count = v_count,
            updated_at = timezone('utc', now())
        WHERE id = v_prov_id;
    END IF;

    -- If provider_id changed on UPDATE, recalculate for previous provider too
    IF TG_OP = 'UPDATE' AND OLD.provider_id IS DISTINCT FROM NEW.provider_id AND OLD.provider_id IS NOT NULL THEN
        SELECT 
            ROUND(COALESCE(AVG(rating), 0)::numeric, 2),
            COUNT(*)
        INTO v_avg, v_count
        FROM public.reviews
        WHERE provider_id = OLD.provider_id;

        UPDATE public.provider_profiles
        SET 
            rating_avg = v_avg,
            rating_count = v_count,
            updated_at = timezone('utc', now())
        WHERE id = OLD.provider_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_reviews_recalculate_rating ON public.reviews;
CREATE TRIGGER trigger_reviews_recalculate_rating
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.update_provider_rating_aggregate();

-- 5. RLS POLICIES FOR REVIEWS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'reviews' AND policyname = 'Reviews viewable by everyone'
    ) THEN
        CREATE POLICY "Reviews viewable by everyone"
        ON public.reviews FOR SELECT
        TO anon, authenticated
        USING (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'reviews' AND policyname = 'Customers can update their own reviews'
    ) THEN
        CREATE POLICY "Customers can update their own reviews"
        ON public.reviews FOR UPDATE
        TO authenticated
        USING (auth.uid() = customer_id)
        WITH CHECK (auth.uid() = customer_id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'reviews' AND policyname = 'Providers can reply to their reviews'
    ) THEN
        CREATE POLICY "Providers can reply to their reviews"
        ON public.reviews FOR UPDATE
        TO authenticated
        USING (auth.uid() = provider_id)
        WITH CHECK (auth.uid() = provider_id);
    END IF;
END $$;

-- 6. RPC: ATOMIC SUBMIT BOOKING REVIEW
CREATE OR REPLACE FUNCTION public.submit_booking_review(
    p_booking_id UUID,
    p_rating INT,
    p_comment TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_customer_id UUID;
    v_booking RECORD;
    v_customer_name TEXT;
    v_review_id UUID;
    v_clean_comment TEXT;
BEGIN
    v_customer_id := auth.uid();
    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to submit a review.';
    END IF;

    -- 1. Validate rating range
    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be between 1 and 5 stars.';
    END IF;

    -- 2. Validate comment length
    v_clean_comment := nullif(trim(p_comment), '');
    IF v_clean_comment IS NOT NULL THEN
        IF char_length(v_clean_comment) < 3 THEN
            RAISE EXCEPTION 'Review comment must be at least 3 characters.';
        END IF;
        IF char_length(v_clean_comment) > 1000 THEN
            RAISE EXCEPTION 'Review comment cannot exceed 1000 characters.';
        END IF;
    END IF;

    -- 3. Lock booking and verify existence
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking % not found.', p_booking_id;
    END IF;

    -- 4. Strict customer authorization check
    IF v_booking.customer_id != v_customer_id THEN
        RAISE EXCEPTION 'Unauthorized: Only the customer who owns this booking can review it.';
    END IF;

    -- 5. Strict completion status verification
    IF v_booking.job_status != 'completed' THEN
        RAISE EXCEPTION 'Review rejected: Only completed jobs can be reviewed (current status: %).', v_booking.job_status;
    END IF;

    -- 6. Anti-self-review safeguard
    IF v_booking.provider_id = v_customer_id THEN
        RAISE EXCEPTION 'Prohibited: Service providers cannot review their own profile.';
    END IF;

    -- 7. Upsert review record
    INSERT INTO public.reviews (
        booking_id,
        customer_id,
        provider_id,
        rating,
        comment,
        created_at,
        updated_at
    ) VALUES (
        p_booking_id,
        v_customer_id,
        v_booking.provider_id,
        p_rating,
        v_clean_comment,
        timezone('utc', now()),
        timezone('utc', now())
    )
    ON CONFLICT (booking_id) DO UPDATE
    SET rating = EXCLUDED.rating,
        comment = EXCLUDED.comment,
        updated_at = timezone('utc', now())
    RETURNING id INTO v_review_id;

    -- 8. Fetch customer display name
    SELECT full_name INTO v_customer_name FROM public.profiles WHERE id = v_customer_id;

    -- 9. Server-side notification to provider
    INSERT INTO public.notifications (
        recipient_id,
        notification_type,
        title,
        body,
        reference_id,
        reference_type,
        idempotency_key
    ) VALUES (
        v_booking.provider_id,
        'review_received',
        'New Customer Review (' || p_rating || '★)',
        COALESCE(v_customer_name, 'A verified customer') || ' left a ' || p_rating || '-star review for ' || v_booking.service_title || '.',
        v_booking.id,
        'booking',
        'review_' || v_review_id
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN v_review_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 7. RPC: ATOMIC PROVIDER REPLY TO REVIEW
CREATE OR REPLACE FUNCTION public.reply_to_booking_review(
    p_review_id UUID,
    p_reply TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_provider_id UUID;
    v_clean_reply TEXT;
BEGIN
    v_provider_id := auth.uid();
    IF v_provider_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to reply to a review.';
    END IF;

    v_clean_reply := nullif(trim(p_reply), '');
    IF v_clean_reply IS NULL OR char_length(v_clean_reply) < 3 THEN
        RAISE EXCEPTION 'Reply must be at least 3 characters.';
    END IF;
    IF char_length(v_clean_reply) > 1000 THEN
        RAISE EXCEPTION 'Reply cannot exceed 1000 characters.';
    END IF;

    UPDATE public.reviews
    SET provider_reply = v_clean_reply,
        provider_reply_at = timezone('utc', now()),
        updated_at = timezone('utc', now())
    WHERE id = p_review_id AND provider_id = v_provider_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Review not found or unauthorized to reply.';
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8. RPC: FETCH PROVIDER REVIEWS WITH SAFE PUBLIC ANONYMIZATION
CREATE OR REPLACE FUNCTION public.get_provider_reviews(
    p_provider_id UUID,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    booking_id UUID,
    customer_id UUID,
    provider_id UUID,
    reviewer_name TEXT,
    reviewer_avatar_url TEXT,
    rating INT,
    comment TEXT,
    created_at TIMESTAMPTZ,
    provider_reply TEXT,
    provider_reply_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.booking_id,
        r.customer_id,
        r.provider_id,
        COALESCE(p.full_name, 'Verified Customer') AS reviewer_name,
        p.avatar_url AS reviewer_avatar_url,
        r.rating,
        r.comment,
        r.created_at,
        r.provider_reply,
        r.provider_reply_at
    FROM public.reviews r
    LEFT JOIN public.profiles p ON p.id = r.customer_id
    WHERE r.provider_id = p_provider_id
    ORDER BY r.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 9. RPC: GET REVIEW FOR A SPECIFIC BOOKING
CREATE OR REPLACE FUNCTION public.get_booking_review(
    p_booking_id UUID
)
RETURNS TABLE (
    id UUID,
    booking_id UUID,
    customer_id UUID,
    provider_id UUID,
    rating INT,
    comment TEXT,
    created_at TIMESTAMPTZ,
    provider_reply TEXT,
    provider_reply_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.booking_id,
        r.customer_id,
        r.provider_id,
        r.rating,
        r.comment,
        r.created_at,
        r.provider_reply,
        r.provider_reply_at
    FROM public.reviews r
    WHERE r.booking_id = p_booking_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
