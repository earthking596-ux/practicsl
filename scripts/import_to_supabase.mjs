/**
 * Practical Code Finder — Secure Local Bulk Import Script
 * File: scripts/import_to_supabase.mjs
 *
 * Usage:
 *   1. Create a `.env.local` file (excluded via .gitignore) with:
 *      VITE_SUPABASE_URL="https://epmjvlgcgsvhylaskabn.supabase.co"
 *      SUPABASE_SERVICE_ROLE_KEY="your-service-role-key-from-supabase-dashboard"
 *   2. Run:
 *      node scripts/import_to_supabase.mjs
 *
 * Security Note:
 *   This script runs locally in Node.js using the privileged `service_role` key
 *   to bypass RLS during bulk seeding. NEVER place `SUPABASE_SERVICE_ROLE_KEY`
 *   in any browser/frontend file.
 */

import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config({ path: '.env.local' });
dotenv.config();

const supabaseUrl = (
  process.env.VITE_SUPABASE_URL ||
  process.env.SUPABASE_URL ||
  'https://epmjvlgcgsvhylaskabn.supabase.co'
)
  .trim()
  .replace(/\/rest\/v1\/?$/i, '')
  .replace(/\/+$/, '');

const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!serviceRoleKey || serviceRoleKey === 'YOUR_SUPABASE_SERVICE_ROLE_KEY_FOR_LOCAL_IMPORT_ONLY') {
  console.error(
    'ERROR: Missing SUPABASE_SERVICE_ROLE_KEY in .env.local.\n' +
      'Because Row Level Security (RLS) blocks anonymous writes (HTTP 401 / PG 42501),\n' +
      'you must either:\n' +
      '  Option A (Recommended, 1-Click): Paste `sql/seed_import_notes.sql` into your Supabase SQL Editor and click Run.\n' +
      '  Option B (Script): Add SUPABASE_SERVICE_ROLE_KEY="..." to `.env.local` and re-run `node scripts/import_to_supabase.mjs`.'
  );
  process.exit(1);
}

const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function runImport() {
  const manifestPath = path.resolve('data/extraction_manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

  console.log(`Connecting to Supabase project: ${supabaseUrl}`);
  console.log(`Importing ${manifest.subjects.length} subjects...`);

  const { data: subjectsData, error: subjectsError } = await supabaseAdmin
    .from('subjects')
    .upsert(
      manifest.subjects.map((s) => ({
        id: s.id,
        name: s.name,
        slug: s.slug,
        description: s.description,
      })),
      { onConflict: 'slug' }
    )
    .select();

  if (subjectsError) {
    console.error('Failed to upsert subjects:', subjectsError);
    process.exit(1);
  }

  const slugToId = new Map(subjectsData.map((s) => [s.slug, s.id]));
  console.log(`Upserted ${subjectsData.length} subjects.`);

  const practicalRows = manifest.practicals.map((p) => ({
    id: p.id,
    source_key: p.source_key || `${p.subject_slug}-practical-${p.practical_number ?? p.id}`,
    subject_id: slugToId.get(p.subject_slug) || p.subject_id,
    practical_number: p.practical_number,
    title: p.title,
    original_question: p.original_question,
    corrected_code: p.corrected_code,
    original_code: p.original_code,
    programming_language: p.programming_language,
    expected_output: p.expected_output,
    algorithm_steps: p.algorithm_steps || [],
    procedure_steps: p.procedure_steps || [],
    instructions: Array.isArray(p.instructions)
      ? p.instructions
      : p.instructions
      ? [p.instructions]
      : [],
    keywords: p.keywords || [],
    aliases: p.aliases || [],
    source_pdf: p.source_pdf,
    source_pages: p.source_pages || [],
    verification_status: p.verification_status,
    review_required: Boolean(p.review_required),
    is_published: p.is_published !== false,
  }));

  console.log(`Importing ${practicalRows.length} practicals in batches...`);
  const batchSize = 10;
  for (let i = 0; i < practicalRows.length; i += batchSize) {
    const batch = practicalRows.slice(i, i + batchSize);
    const { error: batchError } = await supabaseAdmin
      .from('practicals')
      .upsert(batch, { onConflict: 'source_key' });

    if (batchError) {
      console.error(`Batch ${i / batchSize + 1} failed:`, batchError);
      process.exit(1);
    }
    console.log(`  Imported practicals ${i + 1}..${Math.min(i + batchSize, practicalRows.length)}`);
  }

  const { count, error: countError } = await supabaseAdmin
    .from('practicals')
    .select('id', { count: 'exact', head: true });

  if (countError) {
    console.error('Verification count query failed:', countError);
    process.exit(1);
  }

  console.log(`Import complete! Verified total practicals in Supabase: ${count}`);
}

runImport();
