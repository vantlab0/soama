-- ============================================================================
-- SOAMA MARKETPLACE: NOTIFICATIONS, DEVICE TOKENS & PUSH DELIVERY
-- Migration: 20261025000007_notifications_and_device_tokens.sql
-- Description: Persistent in-app notifications with idempotency keys,
--              server-side event triggers, user device tokens table,
--              push notification queue, and atomic RPC procedures.
-- ============================================================================

-- 1. ADD IDEMPOTENCY KEY TO NOTIFICATIONS TABLE
ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_idempotency_key 
ON public.notifications(idempotency_key) 
WHERE idempotency_key IS NOT NULL;

-- 2. ENABLE REALTIME PUBLICATION FOR NOTIFICATIONS
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Ignore in local/mock environments where supabase_realtime publication is not configured
    NULL;
END $$;

-- 3. USER DEVICE TOKENS TABLE (FCM / APNs)
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'macos', 'windows', 'linux')),
    device_info JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_user_device_token UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_user_device_tokens_user ON public.user_device_tokens(user_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_device_tokens_token ON public.user_device_tokens(token);

-- 4. ROW LEVEL SECURITY FOR DEVICE TOKENS
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_device_tokens' 
          AND policyname = 'Users can view and manage their own device tokens'
    ) THEN
        CREATE POLICY "Users can view and manage their own device tokens"
        ON public.user_device_tokens FOR ALL
        TO authenticated
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

-- 5. PUSH NOTIFICATION QUEUE (Server-side push dispatch staging)
CREATE TABLE IF NOT EXISTS public.push_notification_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
    error_message TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    processed_at TIMESTAMPTZ
);

ALTER TABLE public.push_notification_queue ENABLE ROW LEVEL SECURITY;

-- 6. RPC: REGISTER DEVICE TOKEN
CREATE OR REPLACE FUNCTION public.register_device_token(
    p_token TEXT,
    p_platform TEXT,
    p_device_info JSONB DEFAULT '{}'::jsonb
)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to register device token.';
    END IF;

    -- Deactivate token if it previously belonged to a different user on this hardware
    UPDATE public.user_device_tokens
    SET is_active = FALSE, updated_at = timezone('utc', now())
    WHERE token = p_token AND user_id != v_user_id;

    -- Upsert token for current user
    INSERT INTO public.user_device_tokens (
        user_id,
        token,
        platform,
        device_info,
        is_active,
        last_seen_at,
        updated_at
    ) VALUES (
        v_user_id,
        trim(p_token),
        p_platform,
        p_device_info,
        TRUE,
        timezone('utc', now()),
        timezone('utc', now())
    )
    ON CONFLICT (user_id, token) DO UPDATE
    SET is_active = TRUE,
        platform = EXCLUDED.platform,
        device_info = EXCLUDED.device_info,
        last_seen_at = timezone('utc', now()),
        updated_at = timezone('utc', now());

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 7. RPC: UNREGISTER DEVICE TOKEN
CREATE OR REPLACE FUNCTION public.unregister_device_token(p_token TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.user_device_tokens
    SET is_active = FALSE, updated_at = timezone('utc', now())
    WHERE token = trim(p_token) AND (user_id = auth.uid() OR auth.uid() IS NULL);
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8. RPC: MARK NOTIFICATION READ
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.notifications
    SET is_read = TRUE
    WHERE id = p_notification_id AND recipient_id = auth.uid();
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 9. RPC: MARK ALL NOTIFICATIONS READ
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS INT AS $$
DECLARE
    v_updated_count INT;
BEGIN
    UPDATE public.notifications
    SET is_read = TRUE
    WHERE recipient_id = auth.uid() AND is_read = FALSE;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 10. SERVER-SIDE EVENT TRIGGER: SERVICE REQUEST DISPATCHED TO PROVIDER
CREATE OR REPLACE FUNCTION public.trg_notify_service_request_received()
RETURNS TRIGGER AS $$
DECLARE
    v_request RECORD;
    v_customer_name TEXT;
    v_idem_key TEXT;
BEGIN
    SELECT * INTO v_request FROM public.service_requests WHERE id = NEW.request_id;
    IF NOT FOUND THEN RETURN NEW; END IF;

    SELECT full_name INTO v_customer_name FROM public.profiles WHERE id = v_request.customer_id;

    v_idem_key := 'req_recip_' || NEW.request_id || '_' || NEW.provider_id;

    INSERT INTO public.notifications (
        recipient_id,
        notification_type,
        title,
        body,
        reference_id,
        reference_type,
        idempotency_key
    ) VALUES (
        NEW.provider_id,
        'service_request_received',
        'New Service Request: ' || v_request.title,
        COALESCE(v_customer_name, 'A customer') || ' in ' || COALESCE(v_request.location_area, 'Warri') || ' requested your service.',
        v_request.id,
        'service_request',
        v_idem_key
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_request_recipients_notify ON public.request_recipients;
CREATE TRIGGER trg_request_recipients_notify
AFTER INSERT ON public.request_recipients
FOR EACH ROW EXECUTE FUNCTION public.trg_notify_service_request_received();

-- 11. SERVER-SIDE EVENT TRIGGER: PRICE OFFER / COUNTEROFFER
CREATE OR REPLACE FUNCTION public.trg_notify_price_offer_event()
RETURNS TRIGGER AS $$
DECLARE
    v_request RECORD;
    v_recipient_id UUID;
    v_sender_name TEXT;
    v_notif_type TEXT;
    v_title TEXT;
    v_body TEXT;
    v_formatted_amount TEXT;
    v_idem_key TEXT;
BEGIN
    SELECT * INTO v_request FROM public.service_requests WHERE id = NEW.request_id;
    IF NOT FOUND THEN RETURN NEW; END IF;

    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;
    v_formatted_amount := '₦' || to_char((NEW.amount_minor_units / 100), 'FM999,999,999');

    IF NEW.sender_role = 'provider' THEN
        -- Provider sent offer -> notify customer
        v_recipient_id := v_request.customer_id;
        v_notif_type := 'price_offer_received';
        v_title := 'New Offer: ' || v_formatted_amount;
        v_body := COALESCE(v_sender_name, 'Specialist') || ' offered ' || v_formatted_amount || ' for ' || v_request.title || '.';
    ELSE
        -- Customer sent counteroffer -> notify provider
        SELECT provider_id INTO v_recipient_id 
        FROM public.request_recipients 
        WHERE request_id = NEW.request_id 
        LIMIT 1;

        IF v_recipient_id IS NULL THEN RETURN NEW; END IF;

        v_notif_type := 'offer_countered';
        v_title := 'Counteroffer: ' || v_formatted_amount;
        v_body := COALESCE(v_sender_name, 'Customer') || ' countered with ' || v_formatted_amount || ' for ' || v_request.title || '.';
    END IF;

    v_idem_key := 'offer_' || NEW.id;

    INSERT INTO public.notifications (
        recipient_id,
        notification_type,
        title,
        body,
        reference_id,
        reference_type,
        idempotency_key
    ) VALUES (
        v_recipient_id,
        v_notif_type,
        v_title,
        v_body,
        NEW.request_id,
        'price_offer',
        v_idem_key
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_price_offers_notify ON public.price_offers;
CREATE TRIGGER trg_price_offers_notify
AFTER INSERT ON public.price_offers
FOR EACH ROW EXECUTE FUNCTION public.trg_notify_price_offer_event();

-- 12. SERVER-SIDE EVENT TRIGGER: BOOKING CREATED AND STATUS UPDATED
CREATE OR REPLACE FUNCTION public.trg_notify_booking_lifecycle_event()
RETURNS TRIGGER AS $$
DECLARE
    v_idem_key TEXT;
    v_ref TEXT;
BEGIN
    v_ref := COALESCE(NEW.booking_reference, 'BK');

    IF TG_OP = 'INSERT' THEN
        -- 1. Notify Provider of Accepted Offer & Booking Confirmation
        v_idem_key := 'booking_prov_conf_' || NEW.id;
        INSERT INTO public.notifications (
            recipient_id,
            notification_type,
            title,
            body,
            reference_id,
            reference_type,
            idempotency_key
        ) VALUES (
            NEW.provider_id,
            'offer_accepted',
            'Booking Confirmed (' || v_ref || ')',
            'Your offer was accepted for ' || NEW.service_title || '. View job details in your provider dashboard.',
            NEW.id,
            'booking',
            v_idem_key
        )
        ON CONFLICT (idempotency_key) DO NOTHING;

        -- 2. Notify Customer of Confirmed Booking
        v_idem_key := 'booking_cust_conf_' || NEW.id;
        INSERT INTO public.notifications (
            recipient_id,
            notification_type,
            title,
            body,
            reference_id,
            reference_type,
            idempotency_key
        ) VALUES (
            NEW.customer_id,
            'booking_confirmed',
            'Appointment Confirmed (' || v_ref || ')',
            'Your appointment for ' || NEW.service_title || ' has been confirmed with your specialist.',
            NEW.id,
            'booking',
            v_idem_key
        )
        ON CONFLICT (idempotency_key) DO NOTHING;

    ELSIF TG_OP = 'UPDATE' AND OLD.job_status IS DISTINCT FROM NEW.job_status THEN
        -- Status transition notifications
        IF NEW.job_status = 'in_progress' THEN
            v_idem_key := 'booking_started_' || NEW.id;
            INSERT INTO public.notifications (
                recipient_id,
                notification_type,
                title,
                body,
                reference_id,
                reference_type,
                idempotency_key
            ) VALUES (
                NEW.customer_id,
                'job_started',
                'Job In Progress (' || v_ref || ')',
                'The specialist has started work on ' || NEW.service_title || '.',
                NEW.id,
                'booking',
                v_idem_key
            )
            ON CONFLICT (idempotency_key) DO NOTHING;

        ELSIF NEW.job_status = 'completed' THEN
            v_idem_key := 'booking_completed_cust_' || NEW.id;
            INSERT INTO public.notifications (
                recipient_id,
                notification_type,
                title,
                body,
                reference_id,
                reference_type,
                idempotency_key
            ) VALUES (
                NEW.customer_id,
                'job_completed',
                'Job Completed (' || v_ref || ')',
                NEW.service_title || ' has been marked as completed. Please review your specialist.',
                NEW.id,
                'booking',
                v_idem_key
            )
            ON CONFLICT (idempotency_key) DO NOTHING;

        ELSIF NEW.job_status = 'cancelled_by_customer' THEN
            v_idem_key := 'booking_cancelled_prov_' || NEW.id;
            INSERT INTO public.notifications (
                recipient_id,
                notification_type,
                title,
                body,
                reference_id,
                reference_type,
                idempotency_key
            ) VALUES (
                NEW.provider_id,
                'booking_confirmed',
                'Booking Cancelled (' || v_ref || ')',
                'Customer cancelled the booking for ' || NEW.service_title || '. Reason: ' || COALESCE(NEW.cancellation_reason, 'No reason specified'),
                NEW.id,
                'booking',
                v_idem_key
            )
            ON CONFLICT (idempotency_key) DO NOTHING;

        ELSIF NEW.job_status = 'cancelled_by_provider' THEN
            v_idem_key := 'booking_cancelled_cust_' || NEW.id;
            INSERT INTO public.notifications (
                recipient_id,
                notification_type,
                title,
                body,
                reference_id,
                reference_type,
                idempotency_key
            ) VALUES (
                NEW.customer_id,
                'booking_confirmed',
                'Booking Cancelled (' || v_ref || ')',
                'Specialist was unable to complete ' || NEW.service_title || '. Any escrow deposit has been queued for refund.',
                NEW.id,
                'booking',
                v_idem_key
            )
            ON CONFLICT (idempotency_key) DO NOTHING;
        END IF;
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_bookings_notify ON public.bookings;
CREATE TRIGGER trg_bookings_notify
AFTER INSERT OR UPDATE OF job_status ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.trg_notify_booking_lifecycle_event();

-- 13. SERVER-SIDE EVENT TRIGGER: NEW CHAT MESSAGE
CREATE OR REPLACE FUNCTION public.trg_notify_new_chat_message()
RETURNS TRIGGER AS $$
DECLARE
    v_conv RECORD;
    v_recipient_id UUID;
    v_sender_name TEXT;
    v_idem_key TEXT;
    v_preview TEXT;
BEGIN
    SELECT * INTO v_conv FROM public.conversations WHERE id = NEW.conversation_id;
    IF NOT FOUND THEN RETURN NEW; END IF;

    -- Route to counterparty
    IF NEW.sender_id = v_conv.customer_id THEN
        v_recipient_id := v_conv.provider_id;
    ELSE
        v_recipient_id := v_conv.customer_id;
    END IF;

    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;

    v_preview := substring(NEW.content from 1 for 75);
    IF length(NEW.content) > 75 THEN
        v_preview := v_preview || '...';
    END IF;

    v_idem_key := 'msg_' || NEW.id;

    INSERT INTO public.notifications (
        recipient_id,
        notification_type,
        title,
        body,
        reference_id,
        reference_type,
        idempotency_key
    ) VALUES (
        v_recipient_id,
        'new_chat_message',
        'New message from ' || COALESCE(v_sender_name, 'Specialist'),
        v_preview,
        NEW.conversation_id,
        'conversation',
        v_idem_key
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_messages_notify ON public.messages;
CREATE TRIGGER trg_messages_notify
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.trg_notify_new_chat_message();

-- 14. SERVER-SIDE TRIGGER: QUEUE PUSH NOTIFICATIONS FOR ACTIVE DEVICE TOKENS
CREATE OR REPLACE FUNCTION public.trg_queue_push_notification()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.user_device_tokens 
        WHERE user_id = NEW.recipient_id AND is_active = TRUE
    ) THEN
        INSERT INTO public.push_notification_queue (
            notification_id,
            recipient_id,
            title,
            body,
            payload
        ) VALUES (
            NEW.id,
            NEW.recipient_id,
            NEW.title,
            NEW.body,
            jsonb_build_object(
                'notification_id', NEW.id,
                'notification_type', NEW.notification_type,
                'reference_id', NEW.reference_id,
                'reference_type', NEW.reference_type,
                'created_at', NEW.created_at
            )
        );
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_notifications_queue_push ON public.notifications;
CREATE TRIGGER trg_notifications_queue_push
AFTER INSERT ON public.notifications
FOR EACH ROW EXECUTE FUNCTION public.trg_queue_push_notification();
