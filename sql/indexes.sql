-- ============================================================================
-- PRACTICAL CODE FINDER — INDEXES & SERVER-SIDE SEARCH RPC
-- File: sql/indexes.sql
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 1. B-Tree indexes for foreign keys, filtering, and ordering
CREATE INDEX IF NOT EXISTS idx_practicals_subject_id
    ON public.practicals (subject_id);

CREATE INDEX IF NOT EXISTS idx_practicals_practical_number
    ON public.practicals (practical_number);

CREATE INDEX IF NOT EXISTS idx_practicals_published_verified
    ON public.practicals (is_published, review_required, verification_status);

CREATE INDEX IF NOT EXISTS idx_search_terms_practical_id
    ON public.practical_search_terms (practical_id);

-- 2. GIN indexes for array membership (keywords and aliases)
CREATE INDEX IF NOT EXISTS idx_practicals_keywords_gin
    ON public.practicals USING GIN (keywords);

CREATE INDEX IF NOT EXISTS idx_practicals_aliases_gin
    ON public.practicals USING GIN (aliases);

-- 3. Trigram (pg_trgm) GIN indexes for fast partial substring & typo-tolerant matching
CREATE INDEX IF NOT EXISTS idx_practicals_question_trgm
    ON public.practicals USING GIN (original_question gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_practicals_title_trgm
    ON public.practicals USING GIN (title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_practicals_language_trgm
    ON public.practicals USING GIN (programming_language gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_search_terms_term_trgm
    ON public.practical_search_terms USING GIN (term gin_trgm_ops);

-- 4. Full-Text Search (tsvector) GIN index with weighted fields:
--    Weight A: original_question, title
--    Weight B: programming_language
--    Weight C: expected_output
CREATE INDEX IF NOT EXISTS idx_practicals_fts_gin
    ON public.practicals
    USING GIN (
        (
            setweight(to_tsvector('english', coalesce(original_question, '')), 'A') ||
            setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
            setweight(to_tsvector('english', coalesce(programming_language, '')), 'B') ||
            setweight(to_tsvector('english', coalesce(expected_output, '')), 'C')
        )
    );

-- ============================================================================
-- 5. Safe Server-Side Search RPC Function: public.search_practicals
--    - Uses SECURITY INVOKER so RLS policies are always respected.
--    - Sets a strict `search_path = public, extensions` for security.
--    - Combines weighted Full-Text Search, trigram fuzzy matching, keyword/alias
--      matching, practical number matching, and subject filtering.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.search_practicals(
    search_query TEXT DEFAULT '',
    subject_slug_filter TEXT DEFAULT NULL,
    result_limit INTEGER DEFAULT 20,
    result_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    subject_id UUID,
    subject_name TEXT,
    subject_slug TEXT,
    practical_number INTEGER,
    title TEXT,
    original_question TEXT,
    corrected_code TEXT,
    original_code TEXT,
    programming_language TEXT,
    expected_output TEXT,
    algorithm_steps JSONB,
    procedure_steps JSONB,
    instructions JSONB,
    keywords TEXT[],
    aliases TEXT[],
    source_pdf TEXT,
    source_pages INTEGER[],
    verification_status TEXT,
    relevance_score REAL
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    clean_query TEXT := trim(coalesce(search_query, ''));
    parsed_number INTEGER := NULL;
    safe_limit INTEGER := LEAST(GREATEST(coalesce(result_limit, 20), 1), 50);
    safe_offset INTEGER := GREATEST(coalesce(result_offset, 0), 0);
BEGIN
    -- Extract practical number if query is e.g. "Practical 3", "prac 3", or "3"
    IF clean_query ~* '^(?:practical|prac|p|exp|experiment|sr\.?\s*no\.?)?\s*#?\s*([0-9]{1,2})$' THEN
        parsed_number := (regexp_match(clean_query, '([0-9]{1,2})'))[1]::INTEGER;
    END IF;

    RETURN QUERY
    WITH ranked AS (
        SELECT
            p.id,
            p.subject_id,
            s.name AS subject_name,
            s.slug AS subject_slug,
            p.practical_number,
            p.title,
            p.original_question,
            p.corrected_code,
            p.original_code,
            p.programming_language,
            p.expected_output,
            p.algorithm_steps,
            p.procedure_steps,
            p.instructions,
            p.keywords,
            p.aliases,
            p.source_pdf,
            p.source_pages,
            p.verification_status,
            CASE
                WHEN clean_query = '' THEN 1.0::REAL
                ELSE (
                    -- 1. Exact or substring match in original_question (highest weight)
                    (CASE WHEN p.original_question ILIKE '%' || clean_query || '%' THEN 50.0 ELSE 0.0 END) +
                    -- 2. Exact or substring match in title
                    (CASE WHEN p.title ILIKE '%' || clean_query || '%' THEN 40.0 ELSE 0.0 END) +
                    -- 3. Practical number match
                    (CASE WHEN parsed_number IS NOT NULL AND p.practical_number = parsed_number THEN 45.0 ELSE 0.0 END) +
                    -- 4. Full-Text Search rank across question, title, language, output
                    (ts_rank_cd(
                        setweight(to_tsvector('english', coalesce(p.original_question, '')), 'A') ||
                        setweight(to_tsvector('english', coalesce(p.title, '')), 'A') ||
                        setweight(to_tsvector('english', coalesce(p.programming_language, '')), 'B') ||
                        setweight(to_tsvector('english', coalesce(p.expected_output, '')), 'C'),
                        websearch_to_tsquery('english', clean_query)
                    ) * 35.0) +
                    -- 5. Trigram fuzzy similarity (handles spelling mistakes and wording variations)
                    (GREATEST(
                        similarity(p.original_question, clean_query),
                        similarity(p.title, clean_query),
                        similarity(s.name, clean_query)
                    ) * 30.0) +
                    -- 6. Keyword or alias match
                    (CASE WHEN EXISTS (
                        SELECT 1 FROM unnest(p.keywords || p.aliases) AS kw
                        WHERE kw ILIKE '%' || clean_query || '%'
                           OR similarity(kw, clean_query) > 0.45
                    ) THEN 25.0 ELSE 0.0 END) +
                    -- 7. Subject name or programming language match
                    (CASE WHEN s.name ILIKE '%' || clean_query || '%' OR p.programming_language ILIKE '%' || clean_query || '%' THEN 15.0 ELSE 0.0 END) +
                    -- 8. Expected output match
                    (CASE WHEN p.expected_output ILIKE '%' || clean_query || '%' THEN 10.0 ELSE 0.0 END)
                )::REAL
            END AS score
        FROM public.practicals p
        INNER JOIN public.subjects s ON s.id = p.subject_id
        WHERE p.is_published = true
          AND p.review_required = false
          AND p.verification_status IN ('verified', 'corrected')
          AND (
              subject_slug_filter IS NULL
              OR trim(subject_slug_filter) = ''
              OR trim(subject_slug_filter) = 'all'
              OR s.slug = trim(subject_slug_filter)
          )
    )
    SELECT
        r.id,
        r.subject_id,
        r.subject_name,
        r.subject_slug,
        r.practical_number,
        r.title,
        r.original_question,
        r.corrected_code,
        r.original_code,
        r.programming_language,
        r.expected_output,
        r.algorithm_steps,
        r.procedure_steps,
        r.instructions,
        r.keywords,
        r.aliases,
        r.source_pdf,
        r.source_pages,
        r.verification_status,
        r.score AS relevance_score
    FROM ranked r
    WHERE clean_query = '' OR r.score >= 6.5
    ORDER BY
        r.score DESC,
        r.subject_name ASC,
        r.practical_number ASC NULLS LAST
    LIMIT safe_limit
    OFFSET safe_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_practicals(TEXT, TEXT, INTEGER, INTEGER) TO anon, authenticated;
