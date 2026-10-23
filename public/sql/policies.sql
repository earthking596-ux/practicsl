-- ============================================================================
-- PRACTICAL CODE FINDER - ROW LEVEL SECURITY (RLS) POLICIES
-- File: sql/policies.sql
-- Enforces strict anonymous read-only access to published & approved records.
-- ============================================================================

-- 1. Enable Row Level Security on all exposed tables
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practicals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practical_search_terms ENABLE ROW LEVEL SECURITY;

-- Force RLS even for table owners unless bypassed by service_role
ALTER TABLE public.subjects FORCE ROW LEVEL SECURITY;
ALTER TABLE public.practicals FORCE ROW LEVEL SECURITY;
ALTER TABLE public.practical_search_terms FORCE ROW LEVEL SECURITY;

-- 2. Revoke all write privileges from public/anon/authenticated roles
REVOKE ALL ON public.subjects FROM anon, authenticated;
REVOKE ALL ON public.practicals FROM anon, authenticated;
REVOKE ALL ON public.practical_search_terms FROM anon, authenticated;

GRANT SELECT ON public.subjects TO anon, authenticated;
GRANT SELECT ON public.practicals TO anon, authenticated;
GRANT SELECT ON public.practical_search_terms TO anon, authenticated;

-- 3. Drop existing policies if re-applying
DROP POLICY IF EXISTS "Allow public read access to subjects" ON public.subjects;
DROP POLICY IF EXISTS "Allow public read access to published practicals" ON public.practicals;
DROP POLICY IF EXISTS "Allow public read access to search terms of published practicals" ON public.practical_search_terms;

-- 4. Read-only SELECT policy for subjects
CREATE POLICY "Allow public read access to subjects"
ON public.subjects
FOR SELECT
TO anon, authenticated
USING (true);

-- 5. Read-only SELECT policy for practicals
-- Only exposes records that are explicitly published and have a verified status
-- (excludes 'draft' and 'pending_review' records from public view).
CREATE POLICY "Allow public read access to published practicals"
ON public.practicals
FOR SELECT
TO anon, authenticated
USING (
    is_published = TRUE
    AND verification_status IN ('verified_original', 'verified_corrected', 'verified_tested')
);

-- 6. Read-only SELECT policy for practical_search_terms
CREATE POLICY "Allow public read access to search terms of published practicals"
ON public.practical_search_terms
FOR SELECT
TO anon, authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.practicals p
        WHERE p.id = practical_search_terms.practical_id
          AND p.is_published = TRUE
          AND p.verification_status IN ('verified_original', 'verified_corrected', 'verified_tested')
    )
);

-- Note: No INSERT, UPDATE, or DELETE policies are created for anon or authenticated.
-- PostgreSQL RLS denies all writes by default when no permissive write policy exists.
-- Bulk imports are performed exclusively via a local script using SUPABASE_SERVICE_ROLE_KEY
-- or the Supabase SQL Editor.
