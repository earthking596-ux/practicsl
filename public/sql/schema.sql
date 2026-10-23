-- ============================================================================
-- PRACTICAL CODE FINDER - POSTGRESQL SCHEMA (SUPABASE)
-- File: sql/schema.sql
-- Supports 4 subjects, 39 verified practicals, exact code indentation,
-- algorithm/procedure steps, source PDF traceability, and publication gates.
-- ============================================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ----------------------------------------------------------------------------
-- Table A: subjects
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE CHECK (char_length(trim(name)) > 0),
    slug TEXT NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.subjects IS 'Academic subjects extracted from the four practical PDFs.';

-- ----------------------------------------------------------------------------
-- Table B: practicals
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.practicals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_key TEXT NOT NULL UNIQUE CHECK (source_key ~ '^[a-z0-9_-]+$'),
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE RESTRICT,
    practical_number INTEGER CHECK (practical_number IS NULL OR practical_number > 0),
    title TEXT NOT NULL CHECK (char_length(trim(title)) > 0),
    original_question TEXT NOT NULL CHECK (char_length(trim(original_question)) > 0),
    corrected_code TEXT,
    original_code TEXT,
    programming_language TEXT,
    expected_output TEXT,
    algorithm_steps JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(algorithm_steps) = 'array'),
    procedure_steps JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(procedure_steps) = 'array'),
    instructions TEXT,
    keywords TEXT[] NOT NULL DEFAULT '{}'::text[],
    aliases TEXT[] NOT NULL DEFAULT '{}'::text[],
    source_pdf TEXT NOT NULL,
    source_pages INTEGER[] NOT NULL DEFAULT '{}'::integer[],
    verification_status TEXT NOT NULL DEFAULT 'verified_original' CHECK (
        verification_status IN (
            'verified_original',
            'verified_corrected',
            'verified_tested',
            'pending_review',
            'draft'
        )
    ),
    review_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.practicals IS 'Verified practical questions, conservatively corrected source code, step-by-step procedures, and PDF page references.';
COMMENT ON COLUMN public.practicals.corrected_code IS 'Raw source code preserving exact line breaks, tabs, and indentation. Never HTML-encoded.';

-- Automatic updated_at trigger
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_practicals_updated_at ON public.practicals;
CREATE TRIGGER trg_practicals_updated_at
BEFORE UPDATE ON public.practicals
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- ----------------------------------------------------------------------------
-- Table C: practical_search_terms
-- Improves synonym, abbreviation, and alternative question wording lookup
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.practical_search_terms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practical_id UUID NOT NULL REFERENCES public.practicals(id) ON DELETE CASCADE,
    term TEXT NOT NULL CHECK (char_length(trim(term)) > 0),
    term_type TEXT NOT NULL DEFAULT 'keyword' CHECK (
        term_type IN ('keyword', 'alias', 'algorithm', 'tool', 'output_token')
    ),
    UNIQUE (practical_id, term, term_type)
);

COMMENT ON TABLE public.practical_search_terms IS 'Normalized search synonyms, aliases, and tool/algorithm names linked to each practical.';
