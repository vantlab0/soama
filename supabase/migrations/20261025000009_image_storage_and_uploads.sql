-- ============================================================================
-- SOAMA MARKETPLACE: SECURE STORAGE, IMAGE UPLOADS, AND RLS POLICIES
-- Migration: 20261025000009_image_storage_and_uploads.sql
-- Description: Configures buckets for avatars, service portfolio, chat attachments,
--              and verification documents. Enforces ownership path isolation,
--              file size constraints, and allowed MIME types.
-- ============================================================================

-- 1. ADD IMAGE COLUMNS TO CORE TABLES IF NOT ALREADY PRESENT
ALTER TABLE public.provider_services 
    ADD COLUMN IF NOT EXISTS image_url TEXT;

ALTER TABLE public.provider_profiles 
    ADD COLUMN IF NOT EXISTS gallery_images TEXT[] DEFAULT '{}';

-- 2. STORAGE BUCKET CONFIGURATION (IDEMPOTENT)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    (
        'avatars', 
        'avatars', 
        TRUE, 
        5242880, -- 5 MB
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    ),
    (
        'service-portfolio', 
        'service-portfolio', 
        TRUE, 
        10485760, -- 10 MB
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    ),
    (
        'chat-attachments', 
        'chat-attachments', 
        FALSE, -- Private bucket
        10485760, -- 10 MB
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
    ),
    (
        'verification-documents', 
        'verification-documents', 
        FALSE, -- Private bucket
        15728640, -- 15 MB
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
    )
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 3. STORAGE RLS POLICIES

-- Enable RLS on storage.objects (default in Supabase, ensure enabled)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 3.1 AVATARS POLICIES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public avatars viewable" ON storage.objects;
CREATE POLICY "Public avatars viewable"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars' 
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'avatars' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
CREATE POLICY "Users can delete their own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ----------------------------------------------------------------------------
-- 3.2 SERVICE PORTFOLIO POLICIES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Portfolio images viewable" ON storage.objects;
CREATE POLICY "Portfolio images viewable"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'service-portfolio');

DROP POLICY IF EXISTS "Providers can upload portfolio" ON storage.objects;
CREATE POLICY "Providers can upload portfolio"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'service-portfolio' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Providers can update portfolio" ON storage.objects;
CREATE POLICY "Providers can update portfolio"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'service-portfolio' 
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'service-portfolio' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Providers can delete portfolio" ON storage.objects;
CREATE POLICY "Providers can delete portfolio"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'service-portfolio' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ----------------------------------------------------------------------------
-- 3.3 CHAT ATTACHMENTS POLICIES (PRIVATE)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Chat participants can view attachments" ON storage.objects;
CREATE POLICY "Chat participants can view attachments"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'chat-attachments' 
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE (storage.foldername(name))[2] = c.id::text
              AND (c.customer_id = auth.uid() OR c.provider_id = auth.uid())
        )
    )
);

DROP POLICY IF EXISTS "Users can upload chat attachments" ON storage.objects;
CREATE POLICY "Users can upload chat attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'chat-attachments' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can delete their chat attachments" ON storage.objects;
CREATE POLICY "Users can delete their chat attachments"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'chat-attachments' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ----------------------------------------------------------------------------
-- 3.4 VERIFICATION DOCUMENTS POLICIES (PRIVATE)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can view only their own documents" ON storage.objects;
CREATE POLICY "Users can view only their own documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'verification-documents' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can upload verification docs" ON storage.objects;
CREATE POLICY "Users can upload verification docs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'verification-documents' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can delete their verification docs" ON storage.objects;
CREATE POLICY "Users can delete their verification docs"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'verification-documents' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);
