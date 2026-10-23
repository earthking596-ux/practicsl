/**
 * Practical Code Finder — Supabase Client Utility (Vanilla JS ES Module)
 * Initializes the official @supabase/supabase-js client with the project URL and anon key.
 */

import { createClient } from '@supabase/supabase-js';
import { SUPABASE_CONFIG, getNormalizedProjectUrl } from './config.js';

export const supabaseUrl = getNormalizedProjectUrl(SUPABASE_CONFIG.projectUrl);
export const supabaseAnonKey = SUPABASE_CONFIG.anonKey;

export const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

/**
 * Verify live connectivity to Supabase and return current table counts.
 */
export async function checkSupabaseConnection() {
  try {
    const [subjectsRes, practicalsRes] = await Promise.all([
      supabaseClient.from('subjects').select('id, name, slug, description').order('name'),
      supabaseClient
        .from('practicals')
        .select('id', { count: 'exact', head: true })
        .eq('is_published', true)
        .eq('review_required', false),
    ]);

    if (subjectsRes.error) {
      throw subjectsRes.error;
    }
    if (practicalsRes.error) {
      throw practicalsRes.error;
    }

    return {
      connected: true,
      projectUrl: supabaseUrl,
      subjects: subjectsRes.data || [],
      practicalsCount: practicalsRes.count ?? 0,
      error: null,
    };
  } catch (err) {
    return {
      connected: false,
      projectUrl: supabaseUrl,
      subjects: [],
      practicalsCount: 0,
      error: err instanceof Error ? err.message : 'Unable to reach Supabase database.',
    };
  }
}

export default supabaseClient;
