/**
 * Practical Code Finder — Application Entry Reference (js/app.js)
 * Coordinates Supabase connection checks, debounced search, subject filtering,
 * expandable practical details, and one-click clipboard actions.
 */

import { checkSupabaseConnection } from './supabase-client.js';
import { searchPracticalsInSupabase } from './search.js';
import { copyToClipboardExact, formatStepsText } from './clipboard.js';

export {
  checkSupabaseConnection,
  searchPracticalsInSupabase,
  copyToClipboardExact,
  formatStepsText,
};
