import { createClient, SupabaseClient } from '@supabase/supabase-js';

/**
 * Supabase Project URL & Public Anon Key
 * Note: The REST endpoint URL (https://epmjvlgcgsvhylaskabn.supabase.co/rest/v1/)
 * belongs to the base Supabase project URL https://epmjvlgcgsvhylaskabn.supabase.co.
 * The Supabase JS client automatically appends /rest/v1/ for PostgREST queries.
 */
export const SUPABASE_PROJECT_URL: string =
  import.meta.env.VITE_SUPABASE_URL || 'https://epmjvlgcgsvhylaskabn.supabase.co';

export const SUPABASE_REST_URL: string = `${SUPABASE_PROJECT_URL.replace(/\/+$/, '')}/rest/v1/`;

export const SUPABASE_ANON_KEY: string =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwbWp2bGdjZ3N2aHlsYXNrYWJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3NjQxNDIsImV4cCI6MjEwODM0MDE0Mn0.NCzguQeAo2S9W06dfgrX3wFwsjnKNydwZ5NB_NNjYzQ';

export interface SubjectRecord {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  created_at?: string;
}

export interface PracticalRecord {
  id: string;
  source_key?: string;
  subject_id: string;
  subject_name?: string;
  subject_slug?: string;
  practical_number: number | null;
  title: string;
  original_question: string;
  corrected_code: string | null;
  original_code: string | null;
  programming_language: string | null;
  expected_output: string | null;
  algorithm_steps: string[] | null;
  procedure_steps: string[] | null;
  instructions: string[] | string | null;
  keywords: string[];
  aliases: string[];
  source_pdf: string;
  source_pages: number[];
  verification_status: 'verified' | 'corrected' | 'review_required' | 'untested';
  review_required: boolean;
  is_published: boolean;
  created_at?: string;
  updated_at?: string;
}

/**
 * Normalize a Supabase URL in case the user provides the /rest/v1/ path directly.
 */
export function normalizeSupabaseUrl(rawUrl: string): string {
  return rawUrl.trim().replace(/\/rest\/v1\/?$/i, '').replace(/\/+$/, '');
}

/**
 * Initialized Supabase client instance for anonymous public read-only access
 * protected by PostgreSQL Row Level Security (RLS).
 */
export const supabase: SupabaseClient = createClient(
  normalizeSupabaseUrl(SUPABASE_PROJECT_URL),
  SUPABASE_ANON_KEY,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }
);

export default supabase;
