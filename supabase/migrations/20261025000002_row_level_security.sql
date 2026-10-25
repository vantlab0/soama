-- ============================================================================
-- SOAMA MARKETPLACE: ROW-LEVEL SECURITY (RLS) POLICIES
-- Migration: 20261025000002_row_level_security.sql
-- Description: Complete RLS enablement and explicit security policies for all tables.
-- ============================================================================

-- 1. ENABLE ROW LEVEL SECURITY ACROSS ALL TABLES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_addresses ENABLE ROW LEVEL SECURITY;
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
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;

-- 2. HELPER FUNCTIONS FOR SECURITY CHECKS
CREATE OR REPLACE FUNCTION public.is_service_role()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. PROFILES POLICIES
-- Public profiles viewable by authenticated users for marketplace directory/names
CREATE POLICY "Profiles are viewable by authenticated users"
ON public.profiles FOR SELECT
TO authenticated
USING (TRUE);

-- Users can only insert their own profile during signup
CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Users can only update their own non-sensitive profile columns
CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (
    auth.uid() = id 
    AND is_suspended IS NOT DISTINCT FROM (SELECT is_suspended FROM public.profiles WHERE id = auth.uid())
);

-- 4. SAVED ADDRESSES POLICIES (Customer Private Address Book)
CREATE POLICY "Users can view only their own saved addresses"
ON public.saved_addresses FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own saved addresses"
ON public.saved_addresses FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own saved addresses"
ON public.saved_addresses FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own saved addresses"
ON public.saved_addresses FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- 5. SERVICE CATEGORIES POLICIES
-- Anyone can view categories
CREATE POLICY "Service categories are publicly viewable"
ON public.service_categories FOR SELECT
TO anon, authenticated
USING (is_active = TRUE);

-- Modifications restricted to service_role (admins)
CREATE POLICY "Service categories modifiable only by service role"
ON public.service_categories FOR ALL
TO authenticated
USING (public.is_service_role())
WITH CHECK (public.is_service_role());

-- 6. PROVIDER PROFILES POLICIES
-- Approved providers are publicly visible to all marketplace users
CREATE POLICY "Approved providers viewable by all"
ON public.provider_profiles FOR SELECT
TO anon, authenticated
USING (verification_status = 'approved' OR auth.uid() = id);

-- Users can create a provider profile for themselves
CREATE POLICY "Users can create their own provider profile"
ON public.provider_profiles FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = id 
    AND verification_status = 'incomplete'
    AND rating_avg = 0.00
    AND rating_count = 0
    AND completed_jobs_count = 0
);

-- Providers can edit their business details, but CANNOT tamper with verification status or rating
CREATE POLICY "Providers can update their own profile details"
ON public.provider_profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (
    auth.uid() = id
    -- Ensure client cannot self-approve or manipulate verified metrics
    AND verification_status IS NOT DISTINCT FROM (SELECT verification_status FROM public.provider_profiles WHERE id = auth.uid())
    AND rating_avg IS NOT DISTINCT FROM (SELECT rating_avg FROM public.provider_profiles WHERE id = auth.uid())
    AND rating_count IS NOT DISTINCT FROM (SELECT rating_count FROM public.provider_profiles WHERE id = auth.uid())
    AND completed_jobs_count IS NOT DISTINCT FROM (SELECT completed_jobs_count FROM public.provider_profiles WHERE id = auth.uid())
);

-- 7. PROVIDER SERVICE AREAS POLICIES
CREATE POLICY "Active service areas are viewable by all"
ON public.provider_service_areas FOR SELECT
TO anon, authenticated
USING (is_active = TRUE);

CREATE POLICY "Providers can manage their own service areas"
ON public.provider_service_areas FOR ALL
TO authenticated
USING (auth.uid() = provider_id)
WITH CHECK (auth.uid() = provider_id);

-- 8. PROVIDER SERVICES POLICIES
CREATE POLICY "Active provider services are viewable by all"
ON public.provider_services FOR SELECT
TO anon, authenticated
USING (is_active = TRUE);

CREATE POLICY "Providers can manage their own services"
ON public.provider_services FOR ALL
TO authenticated
USING (auth.uid() = provider_id)
WITH CHECK (auth.uid() = provider_id);

-- 9. SERVICE REQUESTS POLICIES
-- Customers can view their own requests
-- Providers can only view requests if they were targeted in request_recipients OR if they have an active booking
CREATE POLICY "Users can view relevant service requests"
ON public.service_requests FOR SELECT
TO authenticated
USING (
    customer_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.request_recipients rr
        WHERE rr.request_id = public.service_requests.id
        AND rr.provider_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.request_id = public.service_requests.id
        AND b.provider_id = auth.uid()
    )
);

-- Customers can insert new requests
CREATE POLICY "Customers can create service requests"
ON public.service_requests FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = customer_id);

-- Customers can update their active requests (e.g. cancel or modify notes before booking)
CREATE POLICY "Customers can update their own service requests"
ON public.service_requests FOR UPDATE
TO authenticated
USING (auth.uid() = customer_id)
WITH CHECK (auth.uid() = customer_id);

-- 10. REQUEST RECIPIENTS POLICIES
CREATE POLICY "Recipients viewable by request customer or invited provider"
ON public.request_recipients FOR SELECT
TO authenticated
USING (
    provider_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = public.request_recipients.request_id
        AND sr.customer_id = auth.uid()
    )
);

CREATE POLICY "Providers can update recipient status"
ON public.request_recipients FOR UPDATE
TO authenticated
USING (provider_id = auth.uid())
WITH CHECK (provider_id = auth.uid());

-- 11. PRICE OFFERS POLICIES
-- Offers viewable by either the request customer or the provider
CREATE POLICY "Price offers viewable by conversation participants"
ON public.price_offers FOR SELECT
TO authenticated
USING (
    sender_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = public.price_offers.request_id
        AND sr.customer_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.request_recipients rr
        WHERE rr.request_id = public.price_offers.request_id
        AND rr.provider_id = auth.uid()
    )
);

-- Authorized parties can propose offers
CREATE POLICY "Authorized parties can insert price offers"
ON public.price_offers FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = request_id
        AND (
            sr.customer_id = auth.uid()
            OR EXISTS (
                SELECT 1 FROM public.request_recipients rr
                WHERE rr.request_id = sr.id AND rr.provider_id = auth.uid()
            )
        )
    )
);

-- Offer status transitions handled via procedure or restricted update
CREATE POLICY "Offer sender can cancel/withdraw offer"
ON public.price_offers FOR UPDATE
TO authenticated
USING (sender_id = auth.uid() AND status = 'pending')
WITH CHECK (sender_id = auth.uid() AND status = 'withdrawn');

-- 12. BOOKINGS POLICIES
-- Customer and Provider can view their bookings
CREATE POLICY "Bookings viewable by customer and provider"
ON public.bookings FOR SELECT
TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid());

-- Status updates (job progress) by customer or provider
CREATE POLICY "Participants can update booking status within allowed states"
ON public.bookings FOR UPDATE
TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid())
WITH CHECK (
    customer_id = (SELECT b.customer_id FROM public.bookings b WHERE b.id = id)
    AND provider_id = (SELECT b.provider_id FROM public.bookings b WHERE b.id = id)
    AND agreed_price_minor_units = (SELECT b.agreed_price_minor_units FROM public.bookings b WHERE b.id = id)
    AND escrow_status = (SELECT b.escrow_status FROM public.bookings b WHERE b.id = id) -- Escrow only modifiable by server
);

-- 13. CONVERSATIONS POLICIES
CREATE POLICY "Conversations viewable by participants"
ON public.conversations FOR SELECT
TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid());

CREATE POLICY "Conversations insertable by participants"
ON public.conversations FOR INSERT
TO authenticated
WITH CHECK (customer_id = auth.uid() OR provider_id = auth.uid());

CREATE POLICY "Conversations updatable by participants"
ON public.conversations FOR UPDATE
TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid())
WITH CHECK (customer_id = auth.uid() OR provider_id = auth.uid());

-- 14. MESSAGES POLICIES
CREATE POLICY "Messages viewable by conversation participants"
ON public.messages FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = public.messages.conversation_id
        AND (c.customer_id = auth.uid() OR c.provider_id = auth.uid())
    )
);

CREATE POLICY "Messages insertable by conversation participants"
ON public.messages FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = conversation_id
        AND (c.customer_id = auth.uid() OR c.provider_id = auth.uid())
    )
);

CREATE POLICY "Messages updatable by recipient for read receipts"
ON public.messages FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = public.messages.conversation_id
        AND (
            (c.customer_id = auth.uid() AND public.messages.sender_id != auth.uid())
            OR (c.provider_id = auth.uid() AND public.messages.sender_id != auth.uid())
        )
    )
)
WITH CHECK (
    is_read = TRUE
);

-- 15. REVIEWS POLICIES
CREATE POLICY "Reviews viewable by everyone"
ON public.reviews FOR SELECT
TO anon, authenticated
USING (TRUE);

CREATE POLICY "Customer can create review for completed booking"
ON public.reviews FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = customer_id
    AND EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = booking_id
        AND b.customer_id = auth.uid()
        AND b.job_status = 'completed'
    )
);

-- 16. NOTIFICATIONS POLICIES
CREATE POLICY "Users can view only their own notifications"
ON public.notifications FOR SELECT
TO authenticated
USING (recipient_id = auth.uid());

CREATE POLICY "Users can mark their own notifications as read"
ON public.notifications FOR UPDATE
TO authenticated
USING (recipient_id = auth.uid())
WITH CHECK (recipient_id = auth.uid());

-- 17. PAYMENTS POLICIES (Client-side writes strictly blocked)
CREATE POLICY "Users can view payments for their bookings"
ON public.payments FOR SELECT
TO authenticated
USING (
    customer_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = public.payments.booking_id
        AND b.provider_id = auth.uid()
    )
);

-- Direct client INSERT/UPDATE on payments is disallowed; handled by service_role (Edge Functions)
CREATE POLICY "Payments modifiable only by service role"
ON public.payments FOR ALL
TO authenticated
USING (public.is_service_role())
WITH CHECK (public.is_service_role());

-- 18. PAYOUTS POLICIES
CREATE POLICY "Providers can view their own payout records"
ON public.payouts FOR SELECT
TO authenticated
USING (provider_id = auth.uid());

CREATE POLICY "Payouts modifiable only by service role"
ON public.payouts FOR ALL
TO authenticated
USING (public.is_service_role())
WITH CHECK (public.is_service_role());

-- 19. DISPUTES POLICIES
CREATE POLICY "Disputes viewable by booking participants"
ON public.disputes FOR SELECT
TO authenticated
USING (
    raised_by_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = public.disputes.booking_id
        AND (b.customer_id = auth.uid() OR b.provider_id = auth.uid())
    )
);

CREATE POLICY "Booking participants can raise disputes"
ON public.disputes FOR INSERT
TO authenticated
WITH CHECK (
    raised_by_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = booking_id
        AND (b.customer_id = auth.uid() OR b.provider_id = auth.uid())
    )
);
