-- ============================================================================
-- PRACTICAL CODE FINDER - SEARCH INDEXES & RPC FUNCTION
-- File: sql/indexes.sql
-- Combines PostgreSQL Full-Text Search (tsvector), Trigram similarity (pg_trgm),
-- keyword/alias matching, and weighted relevance ranking.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 1. Standard B-Tree & GIN Indexes on foreign keys and arrays
CREATE INDEX IF NOT EXISTS idx_practicals_subject_id
    ON public.practicals (subject_id);

CREATE INDEX IF NOT EXISTS idx_practicals_practical_number
    ON public.practicals (practical_number);

CREATE INDEX IF NOT EXISTS idx_practicals_published_status
    ON public.practicals (is_published, verification_status);

CREATE INDEX IF NOT EXISTS idx_practicals_keywords_gin
    ON public.practicals USING GIN (keywords);

CREATE INDEX IF NOT EXISTS idx_practicals_aliases_gin
    ON public.practicals USING GIN (aliases);

-- 2. Trigram GIN Indexes for typo-tolerant & substring matching
CREATE INDEX IF NOT EXISTS idx_practicals_question_trgm
    ON public.practicals USING GIN (original_question gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_practicals_title_trgm
    ON public.practicals USING GIN (title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_search_terms_term_trgm
    ON public.practical_search_terms USING GIN (term gin_trgm_ops);

-- 3. Weighted Full-Text Search Expression Index
-- Weight A: original_question & title
-- Weight B: programming_language & instructions
-- Weight C: expected_output
CREATE INDEX IF NOT EXISTS idx_practicals_fts
    ON public.practicals
    USING GIN (
        (
            setweight(to_tsvector('english', coalesce(original_question, '')), 'A') ||
            setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
            setweight(to_tsvector('english', coalesce(programming_language, '')), 'B') ||
            setweight(to_tsvector('english', coalesce(instructions, '')), 'C') ||
            setweight(to_tsvector('english', coalesce(expected_output, '')), 'C')
        )
    );

-- 4. Safe Server-Side Search RPC Function: public.search_practicals
-- Uses SECURITY INVOKER so Row Level Security (RLS) policies on practicals
-- and subjects are always enforced for anonymous callers.
CREATE OR REPLACE FUNCTION public.search_practicals(
    search_query TEXT DEFAULT '',
    subject_filter TEXT DEFAULT NULL,
    result_limit INTEGER DEFAULT 20,
    result_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    source_key TEXT,
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
    instructions TEXT,
    keywords TEXT[],
    aliases TEXT[],
    source_pdf TEXT,
    source_pages INTEGER[],
    verification_status TEXT,
    review_required BOOLEAN,
    relevance_score REAL
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    cleaned_query TEXT := trim(coalesce(search_query, ''));
    safe_limit INTEGER := LEAST(GREATEST(coalesce(result_limit, 20), 1), 50);
    safe_offset INTEGER := GREATEST(coalesce(result_offset, 0), 0);
    parsed_prac_num INTEGER := NULL;
    ts_q TSQUERY := NULL;
BEGIN
    -- Extract standalone practical number if query is e.g. "1", "practical 4", "prac 8"
    IF cleaned_query ~* '^(?:practical|prac|exp|experiment|no\.?|#)?\s*(\d{1,2})\s*$' THEN
        parsed_prac_num := (regexp_match(cleaned_query, '(\d{1,2})'))[1]::INTEGER;
    END IF;

    IF cleaned_query <> '' THEN
        ts_q := websearch_to_tsquery('english', cleaned_query);
    END IF;

    RETURN QUERY
    WITH scored AS (
        SELECT
            p.id,
            p.source_key,
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
            p.review_required,
            CASE
                WHEN cleaned_query = '' THEN 1.0::REAL
                ELSE (
                    -- 1. Exact or substring match in original_question / title (highest weight)
                    (CASE WHEN p.original_question ILIKE '%' || cleaned_query || '%' THEN 45.0 ELSE 0.0 END) +
                    (CASE WHEN p.title ILIKE '%' || cleaned_query || '%' THEN 38.0 ELSE 0.0 END) +
                    -- 2. Practical number match
                    (CASE WHEN parsed_prac_num IS NOT NULL AND p.practical_number = parsed_prac_num THEN 50.0 ELSE 0.0 END) +
                    -- 3. Full-text search rank on question, title, language, output
                    (CASE
                        WHEN ts_q IS NOT NULL AND (
                            setweight(to_tsvector('english', coalesce(p.original_question, '')), 'A') ||
                            setweight(to_tsvector('english', coalesce(p.title, '')), 'A') ||
                            setweight(to_tsvector('english', coalesce(p.programming_language, '')), 'B') ||
                            setweight(to_tsvector('english', coalesce(p.instructions, '')), 'C') ||
                            setweight(to_tsvector('english', coalesce(p.expected_output, '')), 'C')
                        ) @@ ts_q
                        THEN ts_rank_cd(
                            setweight(to_tsvector('english', coalesce(p.original_question, '')), 'A') ||
                            setweight(to_tsvector('english', coalesce(p.title, '')), 'A') ||
                            setweight(to_tsvector('english', coalesce(p.programming_language, '')), 'B') ||
                            setweight(to_tsvector('english', coalesce(p.instructions, '')), 'C') ||
                            setweight(to_tsvector('english', coalesce(p.expected_output, '')), 'C'),
                            ts_q
                        ) * 35.0
                        ELSE 0.0
                    END) +
                    -- 4. Keyword or alias match
                    (CASE WHEN EXISTS (
                        SELECT 1 FROM unnest(p.keywords) kw WHERE kw ILIKE '%' || cleaned_query || '%' OR cleaned_query ILIKE '%' || kw || '%'
                    ) THEN 28.0 ELSE 0.0 END) +
                    (CASE WHEN EXISTS (
                        SELECT 1 FROM unnest(p.aliases) al WHERE al ILIKE '%' || cleaned_query || '%'
                    ) THEN 25.0 ELSE 0.0 END) +
                    -- 5. Subject or Programming Language match
                    (CASE WHEN s.name ILIKE '%' || cleaned_query || '%' THEN 18.0 ELSE 0.0 END) +
                    (CASE WHEN coalesce(p.programming_language, '') ILIKE '%' || cleaned_query || '%' THEN 15.0 ELSE 0.0 END) +
                    -- 6. Trigram fuzzy similarity (handles typos)
                    (GREATEST(
                        word_similarity(cleaned_query, p.original_question),
                        word_similarity(cleaned_query, p.title),
                        word_similarity(cleaned_query, array_to_string(p.keywords, ' '))
                    ) * 30.0) +
                    -- 7. Low-weight fallback match in expected_output or code
                    (CASE WHEN coalesce(p.expected_output, '') ILIKE '%' || cleaned_query || '%' THEN 8.0 ELSE 0.0 END) +
                    (CASE WHEN coalesce(p.corrected_code, '') ILIKE '%' || cleaned_query || '%' THEN 4.0 ELSE 0.0 END)
                )::REAL
            END AS relevance_score
        FROM public.practicals p
        INNER JOIN public.subjects s ON s.id = p.subject_id
        WHERE p.is_published = TRUE
          AND p.verification_status IN ('verified_original', 'verified_corrected', 'verified_tested')
          AND (
              subject_filter IS NULL
              OR subject_filter = ''
              OR subject_filter = 'all'
              OR s.slug = subject_filter
              OR s.id::TEXT = subject_filter
          )
    )
    SELECT
        scored.id,
        scored.source_key,
        scored.subject_id,
        scored.subject_name,
        scored.subject_slug,
        scored.practical_number,
        scored.title,
        scored.original_question,
        scored.corrected_code,
        scored.original_code,
        scored.programming_language,
        scored.expected_output,
        scored.algorithm_steps,
        scored.procedure_steps,
        scored.instructions,
        scored.keywords,
        scored.aliases,
        scored.source_pdf,
        scored.source_pages,
        scored.verification_status,
        scored.review_required,
        scored.relevance_score
    FROM scored
    WHERE (cleaned_query = '' OR scored.relevance_score >= 10.5)
    ORDER BY
        scored.relevance_score DESC,
        scored.subject_name ASC,
        scored.practical_number ASC NULLS LAST
    LIMIT safe_limit
    OFFSET safe_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_practicals(TEXT, TEXT, INTEGER, INTEGER) TO anon, authenticated;
