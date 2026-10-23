import fs from 'node:fs';
import path from 'node:path';
import {
  EXTRACTED_SUBJECTS,
  EXTRACTED_PRACTICALS,
  SHARED_AI_RMP_MODULE,
  SHARED_AI_RWP_MODULE,
} from '../src/data/practicalsDataset.ts';

function sqlText(val: string | null | undefined, tag = 'txt'): string {
  if (val === null || val === undefined) return 'NULL';
  let safeTag = tag;
  let counter = 1;
  while (val.includes(`$${safeTag}$`)) {
    safeTag = `${tag}_${counter++}`;
  }
  return `$${safeTag}$${val}$${safeTag}$`;
}

function sqlJsonb(val: unknown): string {
  if (val === null || val === undefined) return "'[]'::jsonb";
  const arr = Array.isArray(val) ? val : [val];
  const jsonStr = JSON.stringify(arr);
  return `${sqlText(jsonStr, 'json')}::jsonb`;
}

function sqlTextArray(arr: string[] | null | undefined): string {
  if (!arr || arr.length === 0) return "'{}'::text[]";
  const items = arr.map((item) => sqlText(item, 'item')).join(', ');
  return `ARRAY[${items}]::text[]`;
}

function sqlIntArray(arr: number[] | null | undefined): string {
  if (!arr || arr.length === 0) return "'{}'::integer[]";
  return `ARRAY[${arr.join(', ')}]::integer[]`;
}

function getSourceKey(p: (typeof EXTRACTED_PRACTICALS)[number]): string {
  return p.source_key || `${p.subject_slug}-practical-${p.practical_number ?? p.id}`;
}

function generateSeedSql(): string {
  const lines: string[] = [];
  lines.push('-- ============================================================================');
  lines.push('-- PRACTICAL CODE FINDER — COMPLETE SEED & IMPORT SQL');
  lines.push('-- File: sql/seed_import_notes.sql');
  lines.push('--');
  lines.push('-- Instructions:');
  lines.push('-- 1. Open your Supabase Project Dashboard (https://supabase.com/dashboard/project/epmjvlgcgsvhylaskabn)');
  lines.push('-- 2. Go to SQL Editor -> New Query.');
  lines.push('-- 3. Paste and run this file (sql/seed_import_notes.sql) to insert all 4 subjects');
  lines.push('--    and all 39 extracted practicals safely (includes source_key and RLS policies).');
  lines.push('-- ============================================================================');
  lines.push('');
  lines.push('BEGIN;');
  lines.push('');
  lines.push('-- 0. Ensure source_key column and compatible check constraints exist on public.practicals');
  lines.push('ALTER TABLE public.practicals ADD COLUMN IF NOT EXISTS source_key TEXT;');
  lines.push(`DO $$
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
END $$;`);
  lines.push('');
  lines.push(`ALTER TABLE public.practicals
    ADD CONSTRAINT chk_practicals_verification_status
    CHECK (verification_status IN ('verified', 'corrected', 'review_required', 'untested'));`);
  lines.push('');
  lines.push(`ALTER TABLE public.practical_search_terms
    ADD CONSTRAINT chk_search_terms_term_type
    CHECK (term_type IN ('synonym', 'algorithm', 'tool', 'typo_variant', 'keyword'));`);
  lines.push('');
  lines.push('CREATE UNIQUE INDEX IF NOT EXISTS uq_practicals_source_key ON public.practicals (source_key);');
  lines.push('');

  lines.push('-- 1. Upsert Subjects (4 Subjects)');
  for (const subj of EXTRACTED_SUBJECTS) {
    lines.push(`INSERT INTO public.subjects (id, name, slug, description)
VALUES (
    '${subj.id}',
    ${sqlText(subj.name, 'name')},
    ${sqlText(subj.slug, 'slug')},
    ${sqlText(subj.description, 'desc')}
)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;
`);
  }

  lines.push('-- 2. Upsert Practicals (39 Extracted Practicals across 4 Subjects with source_key)');
  for (const p of EXTRACTED_PRACTICALS) {
    const sourceKey = getSourceKey(p);
    lines.push(`-- [${p.subject_name}] Practical ${p.practical_number}: ${p.title} (source_key: ${sourceKey})`);
    lines.push(`INSERT INTO public.practicals (
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
    '${p.id}',
    ${sqlText(sourceKey, 'skey')},
    (SELECT id FROM public.subjects WHERE slug = ${sqlText(p.subject_slug, 's')}),
    ${p.practical_number === null ? 'NULL' : p.practical_number},
    ${sqlText(p.title, 'title')},
    ${sqlText(p.original_question, 'q')},
    ${sqlText(p.corrected_code, 'code')},
    ${sqlText(p.original_code, 'orig')},
    ${sqlText(p.programming_language, 'lang')},
    ${sqlText(p.expected_output, 'out')},
    ${sqlJsonb(p.algorithm_steps)},
    ${sqlJsonb(p.procedure_steps)},
    ${sqlJsonb(p.instructions)},
    ${sqlTextArray(p.keywords)},
    ${sqlTextArray(p.aliases)},
    ${sqlText(p.source_pdf, 'pdf')},
    ${sqlIntArray(p.source_pages)},
    ${sqlText(p.verification_status, 'v')},
    ${p.review_required ? 'true' : 'false'},
    ${p.is_published ? 'true' : 'false'}
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
`);
  }

  lines.push('-- 3. Upsert Search Terms (Synonyms & Keywords)');
  lines.push('DELETE FROM public.practical_search_terms;');
  for (const p of EXTRACTED_PRACTICALS) {
    const sourceKey = getSourceKey(p);
    const allTerms = [
      ...(p.keywords || []).map((t) => ({ term: t, type: 'keyword' })),
      ...(p.aliases || []).map((t) => ({ term: t, type: 'synonym' })),
    ];
    const seen = new Set<string>();
    for (const item of allTerms) {
      const norm = item.term.trim().toLowerCase();
      if (!norm || seen.has(norm)) continue;
      seen.add(norm);
      lines.push(`INSERT INTO public.practical_search_terms (practical_id, term, term_type)
VALUES (
    (SELECT id FROM public.practicals WHERE source_key = ${sqlText(sourceKey, 'skey')}),
    ${sqlText(item.term, 'term')},
    '${item.type}'
);`);
    }
  }

  lines.push('');
  lines.push('-- 4. Ensure Public Read-Only Row Level Security (RLS) Policies Are Active');
  lines.push('ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;');
  lines.push('ALTER TABLE public.practicals ENABLE ROW LEVEL SECURITY;');
  lines.push('ALTER TABLE public.practical_search_terms ENABLE ROW LEVEL SECURITY;');
  lines.push('GRANT SELECT ON public.subjects TO anon, authenticated;');
  lines.push('GRANT SELECT ON public.practicals TO anon, authenticated;');
  lines.push('GRANT SELECT ON public.practical_search_terms TO anon, authenticated;');
  lines.push('DROP POLICY IF EXISTS "Public read access to subjects" ON public.subjects;');
  lines.push('CREATE POLICY "Public read access to subjects" ON public.subjects FOR SELECT TO anon, authenticated USING (true);');
  lines.push('DROP POLICY IF EXISTS "Public read access to approved practicals" ON public.practicals;');
  lines.push(`CREATE POLICY "Public read access to approved practicals" ON public.practicals FOR SELECT TO anon, authenticated USING (is_published = true AND review_required = false AND verification_status IN ('verified', 'corrected'));`);
  lines.push('DROP POLICY IF EXISTS "Public read access to search terms of approved practicals" ON public.practical_search_terms;');
  lines.push(`CREATE POLICY "Public read access to search terms of approved practicals" ON public.practical_search_terms FOR SELECT TO anon, authenticated USING (EXISTS (SELECT 1 FROM public.practicals p WHERE p.id = practical_search_terms.practical_id AND p.is_published = true AND p.review_required = false));`);
  lines.push('');
  lines.push('COMMIT;');
  return lines.join('\n');
}

const practicalsWithSourceKey = EXTRACTED_PRACTICALS.map((p) => ({
  ...p,
  source_key: getSourceKey(p),
}));

const manifest = {
  project: 'Practical Code Finder',
  supabaseProjectUrl: 'https://epmjvlgcgsvhylaskabn.supabase.co',
  generatedAt: new Date().toISOString(),
  summary: {
    totalSubjects: EXTRACTED_SUBJECTS.length,
    totalPracticals: practicalsWithSourceKey.length,
    countsBySubject: EXTRACTED_SUBJECTS.map((s) => ({
      subject: s.name,
      slug: s.slug,
      count: practicalsWithSourceKey.filter((p) => p.subject_slug === s.slug).length,
    })),
  },
  sharedModules: {
    'RMP.py': SHARED_AI_RMP_MODULE,
    'RWP.py': SHARED_AI_RWP_MODULE,
  },
  subjects: EXTRACTED_SUBJECTS,
  practicals: practicalsWithSourceKey,
};

fs.mkdirSync(path.resolve('data'), { recursive: true });
fs.mkdirSync(path.resolve('public/data'), { recursive: true });
fs.mkdirSync(path.resolve('sql'), { recursive: true });
fs.mkdirSync(path.resolve('public/sql'), { recursive: true });

const manifestJson = JSON.stringify(manifest, null, 2);
fs.writeFileSync(path.resolve('data/extraction_manifest.json'), manifestJson, 'utf8');
fs.writeFileSync(path.resolve('public/data/extraction_manifest.json'), manifestJson, 'utf8');

const seedSql = generateSeedSql();
fs.writeFileSync(path.resolve('sql/seed_import_notes.sql'), seedSql, 'utf8');
fs.writeFileSync(path.resolve('public/sql/seed_import_notes.sql'), seedSql, 'utf8');

const schemaSql = fs.readFileSync(path.resolve('sql/schema.sql'), 'utf8');
const policiesSql = fs.readFileSync(path.resolve('sql/policies.sql'), 'utf8');
const indexesSql = fs.readFileSync(path.resolve('sql/indexes.sql'), 'utf8');
const fullSetupSql = [schemaSql, policiesSql, indexesSql, seedSql].join('\n\n');
fs.writeFileSync(path.resolve('public/sql/full_supabase_setup.sql'), fullSetupSql, 'utf8');

console.log('Regenerated extraction_manifest.json and seed_import_notes.sql with source_key.');
