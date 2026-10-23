-- ============================================================================
-- PRACTICAL CODE FINDER — POSTGRESQL SCHEMA (Supabase)
-- File: sql/schema.sql
-- ============================================================================

-- Enable required extensions for UUID generation and fuzzy trigram search
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ----------------------------------------------------------------------------
-- Table A: subjects
-- Stores one record for each actual practical PDF subject.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE CHECK (char_length(trim(name)) > 0),
    slug TEXT NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9-]+$'),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- Table B: practicals
-- Stores every extracted practical question, original & corrected code,
-- ordered algorithm/procedure steps, expected outputs, and PDF source pages.
-- Note: Code columns (corrected_code, original_code) preserve exact line breaks
-- and indentation without automatic trimming or HTML formatting.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.practicals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_key TEXT NOT NULL UNIQUE CHECK (char_length(trim(source_key)) > 0),
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    practical_number INTEGER CHECK (practical_number IS NULL OR practical_number > 0),
    title TEXT NOT NULL CHECK (char_length(trim(title)) > 0),
    original_question TEXT NOT NULL CHECK (char_length(trim(original_question)) > 0),
    corrected_code TEXT,
    original_code TEXT,
    programming_language TEXT,
    expected_output TEXT,
    algorithm_steps JSONB DEFAULT '[]'::jsonb,
    procedure_steps JSONB DEFAULT '[]'::jsonb,
    instructions JSONB DEFAULT '[]'::jsonb,
    keywords TEXT[] NOT NULL DEFAULT '{}'::text[],
    aliases TEXT[] NOT NULL DEFAULT '{}'::text[],
    source_pdf TEXT NOT NULL,
    source_pages INTEGER[] NOT NULL DEFAULT '{}'::integer[],
    verification_status TEXT NOT NULL DEFAULT 'verified'
        CHECK (verification_status IN ('verified', 'corrected', 'review_required', 'untested')),
    review_required BOOLEAN NOT NULL DEFAULT false,
    is_published BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- Table C: practical_search_terms
-- Improves synonym management, alternative question wording, and search ranking.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.practical_search_terms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practical_id UUID NOT NULL REFERENCES public.practicals(id) ON DELETE CASCADE,
    term TEXT NOT NULL CHECK (char_length(trim(term)) > 0),
    term_type TEXT NOT NULL DEFAULT 'synonym'
        CHECK (term_type IN ('synonym', 'algorithm', 'tool', 'typo_variant', 'keyword')),
    CONSTRAINT uq_practical_term UNIQUE (practical_id, term)
);

-- ----------------------------------------------------------------------------
-- Automatic updated_at timestamp trigger for practicals
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_practicals_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_practicals_updated_at ON public.practicals;
CREATE TRIGGER trg_practicals_updated_at
BEFORE UPDATE ON public.practicals
FOR EACH ROW
EXECUTE FUNCTION public.set_practicals_updated_at();
