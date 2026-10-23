-- ============================================================================
-- PRACTICAL CODE FINDER — ROW LEVEL SECURITY (RLS) POLICIES
-- File: sql/policies.sql
--
-- Security Model:
-- 1. Enable RLS on all public tables exposed through the Supabase Data API.
-- 2. Anonymous visitors (`anon`) and authenticated users (`authenticated`)
--    have strictly READ-ONLY (`SELECT`) access.
-- 3. Only published and reviewed practical records (`is_published = true`
--    AND `review_required = false` AND `verification_status IN ('verified', 'corrected')`)
--    are visible to public visitors.
-- 4. No `INSERT`, `UPDATE`, or `DELETE` policies exist for `anon` or
--    `authenticated`, so all client-side write attempts are rejected by
--    PostgreSQL with error code 42501.
-- ============================================================================

-- 1. Enable Row Level Security on all tables
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practicals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practical_search_terms ENABLE ROW LEVEL SECURITY;

-- 2. Revoke write privileges from public/anon roles as defense-in-depth
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.subjects FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.practicals FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.practical_search_terms FROM anon, authenticated;

GRANT SELECT ON public.subjects TO anon, authenticated;
GRANT SELECT ON public.practicals TO anon, authenticated;
GRANT SELECT ON public.practical_search_terms TO anon, authenticated;

-- 3. Drop existing policies if re-applying
DROP POLICY IF EXISTS "Public read access to subjects" ON public.subjects;
DROP POLICY IF EXISTS "Public read access to approved practicals" ON public.practicals;
DROP POLICY IF EXISTS "Public read access to search terms of approved practicals" ON public.practical_search_terms;

-- 4. Policy: Anonymous visitors can read all subjects
CREATE POLICY "Public read access to subjects"
ON public.subjects
FOR SELECT
TO anon, authenticated
USING (true);

-- 5. Policy: Anonymous visitors can read only published, non-review-flagged practicals
CREATE POLICY "Public read access to approved practicals"
ON public.practicals
FOR SELECT
TO anon, authenticated
USING (
    is_published = true
    AND review_required = false
    AND verification_status IN ('verified', 'corrected')
);

-- 6. Policy: Anonymous visitors can read search terms linked to approved practicals
CREATE POLICY "Public read access to search terms of approved practicals"
ON public.practical_search_terms
FOR SELECT
TO anon, authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.practicals p
        WHERE p.id = practical_search_terms.practical_id
          AND p.is_published = true
          AND p.review_required = false
          AND p.verification_status IN ('verified', 'corrected')
    )
);
