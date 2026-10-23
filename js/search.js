/**
 * Practical Code Finder — Database Search Module (js/search.js)
 * Queries the Supabase PostgreSQL database (`search_practicals` RPC and `practicals` table)
 * with weighted relevance ranking, subject filtering, and stale-request protection.
 */

import { supabaseClient } from './supabase-client.js';
import { SUPABASE_CONFIG } from './config.js';

let latestRequestId = 0;

/**
 * Execute a database-backed search against Supabase.
 */
export async function searchPracticalsInSupabase({
  query = '',
  subjectSlug = 'all',
  limit = SUPABASE_CONFIG.defaultPageSize,
  offset = 0,
} = {}) {
  const requestId = ++latestRequestId;
  const cleanQuery = String(query || '').trim();

  // 1. Try server-side PostgreSQL RPC `search_practicals` first
  const rpcRes = await supabaseClient.rpc('search_practicals', {
    search_query: cleanQuery,
    subject_slug_filter: subjectSlug === 'all' ? null : subjectSlug,
    result_limit: limit,
    result_offset: offset,
  });

  if (requestId !== latestRequestId) {
    return { stale: true, results: [], totalCount: 0 };
  }

  if (!rpcRes.error && Array.isArray(rpcRes.data)) {
    return {
      stale: false,
      results: rpcRes.data,
      totalCount: rpcRes.data.length,
      source: 'supabase-rpc',
    };
  }

  // 2. Fallback to direct PostgREST query on `practicals` joined with `subjects`
  let queryBuilder = supabaseClient
    .from('practicals')
    .select(
      `
      id,
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
      is_published,
      subjects!inner (
        id,
        name,
        slug
      )
    `,
      { count: 'exact' }
    )
    .eq('is_published', true)
    .eq('review_required', false);

  if (subjectSlug && subjectSlug !== 'all') {
    queryBuilder = queryBuilder.eq('subjects.slug', subjectSlug);
  }

  if (cleanQuery) {
    const escaped = cleanQuery.replace(/[%_]/g, '');
    queryBuilder = queryBuilder.or(
      `original_question.ilike.%${escaped}%,title.ilike.%${escaped}%,programming_language.ilike.%${escaped}%,expected_output.ilike.%${escaped}%`
    );
  }

  const { data, error, count } = await queryBuilder
    .order('practical_number', { ascending: true })
    .range(offset, offset + limit - 1);

  if (requestId !== latestRequestId) {
    return { stale: true, results: [], totalCount: 0 };
  }

  if (error) {
    throw error;
  }

  const normalized = (data || []).map((row) => ({
    ...row,
    subject_name: row.subjects?.name || '',
    subject_slug: row.subjects?.slug || '',
  }));

  return {
    stale: false,
    results: normalized,
    totalCount: count ?? normalized.length,
    source: 'supabase-rest',
  };
}
