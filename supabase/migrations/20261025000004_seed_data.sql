-- ============================================================================
-- SOAMA MARKETPLACE: SEED DATA
-- Migration: 20261025000004_seed_data.sql
-- Description: Standard service categories and initial reference data.
-- ============================================================================

-- 1. SEED SERVICE CATEGORIES (Aligned with Flutter ServiceCategory.mockCategories)
INSERT INTO public.service_categories (id, name, description, icon_name, is_active, display_order)
VALUES
    ('cleaning', 'Cleaning & Housekeeping', 'Home, office, deep cleaning, and post-construction cleaning services.', 'cleaning_services_outlined', TRUE, 1),
    ('plumbing', 'Plumbing & Drainage', 'Leak repair, pipe fitting, drainage unclogging, and bathroom installations.', 'plumbing_outlined', TRUE, 2),
    ('electrical', 'Electrical & Wiring', 'Residential wiring, solar inverter installation, generator repairs, and fixture installation.', 'electrical_services_outlined', TRUE, 3),
    ('carpentry', 'Carpentry & Woodwork', 'Cabinet making, furniture repairs, door and lock fitting, and custom roofing timber.', 'carpenter_outlined', TRUE, 4),
    ('painting', 'Painting & Decorating', 'Interior/exterior wall painting, decorative screeding, wallpaper, and POP finishes.', 'format_paint_outlined', TRUE, 5),
    ('appliance', 'Appliance Repair', 'Refrigerators, washing machines, microwaves, televisions, and kitchen appliances.', 'home_repair_service_outlined', TRUE, 6),
    ('hvac', 'AC & Refrigeration', 'Air conditioner installation, gas refilling, compressor repairs, and routine maintenance.', 'ac_unit_outlined', TRUE, 7),
    ('pest_control', 'Pest Control & Fumigation', 'Residential fumigation, termite treatment, rodent extermination, and bedbug clearing.', 'pest_control_outlined', TRUE, 8)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name,
    is_active = EXCLUDED.is_active,
    display_order = EXCLUDED.display_order;

-- 2. STORAGE BUCKET INITIALIZATION (Idempotent Supabase Storage Setup)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('avatars', 'avatars', TRUE, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('service-portfolio', 'service-portfolio', TRUE, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('verification-documents', 'verification-documents', FALSE, 15728640, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
    ('chat-attachments', 'chat-attachments', FALSE, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage Policies for Avatars
CREATE POLICY "Public avatars viewable"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Storage Policies for Portfolio
CREATE POLICY "Portfolio images viewable"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'service-portfolio');

CREATE POLICY "Providers can upload portfolio"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'service-portfolio' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Storage Policies for Verification Documents (Private)
CREATE POLICY "Users can view only their own documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'verification-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can upload verification docs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'verification-documents' AND (storage.foldername(name))[1] = auth.uid()::text);
