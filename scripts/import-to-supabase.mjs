/**
 * Practical Code Finder - Secure Supabase Bulk Import Script
 * File: scripts/import-to-supabase.mjs
 *
 * Usage:
 *   1. Create a local .env file (excluded via .gitignore) with:
 *      SUPABASE_URL="https://your-project-ref.supabase.co"
 *      SUPABASE_SERVICE_ROLE_KEY="your-service-role-secret-key"
 *   2. Run:
 *      node scripts/import-to-supabase.mjs
 *
 * Security Note:
 *   NEVER expose SUPABASE_SERVICE_ROLE_KEY in frontend code or commit it to Git.
 */

import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    'Error: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment.\n' +
    'Please add them to your local .env file before running this import script.'
  );
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false }
});

async function runImport() {
  const manifestPath = path.resolve('data/extraction_manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

  console.log(`Loaded manifest: ${manifest.subjects.length} subjects, ${manifest.practicals.length} practicals.`);

  // 1. Upsert Subjects
  const subjectRows = manifest.subjects.map(s => ({
    id: s.id,
    name: s.name,
    slug: s.slug,
    description: s.description
  }));

  const { data: insertedSubjects, error: subjectErr } = await supabase
    .from('subjects')
    .upsert(subjectRows, { onConflict: 'slug' })
    .select('id, slug, name');

  if (subjectErr) {
    console.error('Failed to upsert subjects:', subjectErr.message);
    process.exit(1);
  }
  console.log(`Verified ${insertedSubjects.length} subjects in Supabase.`);

  // 2. Fetch existing practicals that have been manually reviewed so we don't overwrite them
  const { data: existingReviewed } = await supabase
    .from('practicals')
    .select('source_key')
    .eq('verification_status', 'verified_tested');

  const reviewedKeys = new Set((existingReviewed || []).map(r => r.source_key));

  // 3. Upsert Practicals in batches of 15
  const BATCH_SIZE = 15;
  let importedCount = 0;

  for (let i = 0; i < manifest.practicals.length; i += BATCH_SIZE) {
    const batch = manifest.practicals
      .slice(i, i + BATCH_SIZE)
      .filter(p => !reviewedKeys.has(p.source_key))
      .map(p => ({
        id: p.id,
        source_key: p.source_key,
        subject_id: p.subject_id,
        practical_number: p.practical_number,
        title: p.title,
        original_question: p.original_question,
        corrected_code: p.corrected_code,
        original_code: p.original_code,
        programming_language: p.programming_language,
        expected_output: p.expected_output,
        algorithm_steps: p.algorithm_steps,
        procedure_steps: p.procedure_steps,
        instructions: p.instructions,
        keywords: p.keywords,
        aliases: p.aliases,
        source_pdf: p.source_pdf,
        source_pages: p.source_pages,
        verification_status: p.verification_status,
        review_required: p.review_required,
        is_published: true
      }));

    if (batch.length > 0) {
      const { error: pracErr } = await supabase
        .from('practicals')
        .upsert(batch, { onConflict: 'source_key' });

      if (pracErr) {
        console.error(`Batch import failed at index ${i}:`, pracErr.message);
        process.exit(1);
      }
      importedCount += batch.length;
      console.log(`Imported batch ${Math.floor(i / BATCH_SIZE) + 1}: ${importedCount}/${manifest.practicals.length} practicals...`);
    }
  }

  // 4. Verify total record counts in Supabase
  const { count, error: countErr } = await supabase
    .from('practicals')
    .select('*', { count: 'exact', head: true });

  if (countErr) {
    console.error('Count verification failed:', countErr.message);
    process.exit(1);
  }

  console.log(`\nImport complete! Total practicals verified in Supabase: ${count} (Expected: ${manifest.practicals.length}).`);
}

runImport().catch(err => {
  console.error('Unexpected import error:', err);
  process.exit(1);
});
