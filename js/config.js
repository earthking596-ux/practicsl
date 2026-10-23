/**
 * Practical Code Finder — Supabase Public Client Configuration
 *
 * SECURITY NOTE:
 * - Only the public Project URL and the public `anon` key belong in this file.
 * - NEVER put a `service_role` secret key or database password in frontend files.
 * - Row Level Security (RLS) policies in PostgreSQL enforce read-only public access.
 */

export const SUPABASE_CONFIG = {
  // Base project URL derived from https://epmjvlgcgsvhylaskabn.supabase.co/rest/v1/
  projectUrl: 'https://epmjvlgcgsvhylaskabn.supabase.co',
  restEndpoint: 'https://epmjvlgcgsvhylaskabn.supabase.co/rest/v1/',
  anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwbWp2bGdjZ3N2aHlsYXNrYWJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3NjQxNDIsImV4cCI6MjEwODM0MDE0Mn0.NCzguQeAo2S9W06dfgrX3wFwsjnKNydwZ5NB_NNjYzQ',
  defaultPageSize: 20,
  searchDebounceMs: 220,
};

export function getNormalizedProjectUrl(url = SUPABASE_CONFIG.projectUrl) {
  return String(url || '')
    .trim()
    .replace(/\/rest\/v1\/?$/i, '')
    .replace(/\/+$/, '');
}
