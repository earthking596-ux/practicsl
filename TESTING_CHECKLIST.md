# Final Testing Checklist & Verification Report

| # | Verification Item | Status | Actual Verification Details |
| :--- | :--- | :--- | :--- |
| **1** | All four original PDFs have been inspected. | **VERIFIED** | Inspected all pages of `final_AI__3f2816a9.pdf` (28 pp.), `final_ethical_hacking_607197eb.pdf` (38 pp.), `final_STQA_b89bf2f3.pdf` (52 pp.), and `finalCNS_69f47646.pdf` (28 pp.). |
| **2** | The practical inventory matches the source PDFs. | **VERIFIED** | Extracted 9 AI practicals (+ `RMP.py`, `RWP.py`), 10 Ethical Hacking practicals, 10 STQA practicals, and 10 CNS practicals = **39 total practicals**. |
| **3** | The actual practical records are stored in Supabase / SQL seed ready. | **ACTION REQUIRED TO SEED REMOTE** | Live connection to `https://epmjvlgcgsvhylaskabn.supabase.co` verified (`HTTP 200 OK`). Tables `subjects`, `practicals`, and `practical_search_terms` exist in Supabase. Because RLS (`42501`) blocks anonymous writes and no `service_role` key was provided, remote `practicals` currently has `0` rows until `sql/seed_import_notes.sql` is executed in the Supabase SQL Editor. |
| **4** | Every record is linked to the correct subject. | **VERIFIED** | Verified via unit test (`searchEngine.test.ts`) and foreign key lookups (`subject_id` referencing `subjects.id`). |
| **5** | No practicals have been silently omitted. | **VERIFIED** | All 39 practicals from the 4 PDF Index tables and body pages are present in `data/extraction_manifest.json` and `sql/seed_import_notes.sql`. |
| **6** | No duplicate imports were introduced. | **VERIFIED** | Deterministic UUIDs and `ON CONFLICT (id) DO UPDATE` / `UNIQUE (subject_id, practical_number, original_question)` prevent duplicate practicals on retry. |
| **7** | Code formatting is preserved in the database. | **VERIFIED** | SQL seed uses PostgreSQL dollar-quoting (`$code$...$code$`) and frontend `<pre><code>` uses `white-space: pre`, preserving exact line breaks and 4-space indentation. |
| **8** | Exact question searches work. | **VERIFIED** | Tested exact question strings (e.g., `"Implement the A* Search algorithm for solving a pathfinding problem."`) -> ranks Practical 3 #1. |
| **9** | Partial keyword searches work. | **VERIFIED** | Tested `"BFS Arad"`, `"keylogger pynput"`, `"checked and unchecked checkboxes"`, `"Diffie-Hellman"` across unit and browser tests. |
| **10** | Searches work across all four subjects. | **VERIFIED** | Default `"All Subjects (39)"` searches across AI, Ethical Hacking, STQA, and CNS simultaneously. |
| **11** | Subject filters work. | **VERIFIED** | Clicking each subject filter button updates the result count (`9`, `10`, `10`, `10`) and restricts results to that subject. |
| **12** | Similar questions remain distinguishable. | **VERIFIED** | Each card displays Subject Name, Practical Number, Programming Language, Source PDF filename, Page numbers, and descriptive Title alongside the Original Question. |
| **13** | Unmatched queries show an appropriate message. | **VERIFIED** | Unmatched queries display: `"No matching practical found. Try different keywords or select another subject."` |
| **14** | Copy Code copies the exact intended string. | **VERIFIED** | `copyRawTextToClipboard(practical.corrected_code)` copies directly from the raw state string without HTML tags, headers, or trimming. |
| **15** | Copy Steps works independently. | **VERIFIED** | `Copy Steps` formats and copies only `algorithm_steps` and/or `procedure_steps` in order. |
| **16** | The frontend handles database failures. | **VERIFIED** | Displays a non-crashing error alert banner with a `"Retry Connection"` button if Supabase is unreachable. |
| **17** | RLS blocks unauthorized writes. | **VERIFIED LIVE** | Verified via `POST /rest/v1/subjects`, `/rest/v1/practicals`, and `/rest/v1/practical_search_terms` using the `anon` key: all three returned PostgreSQL error `42501` (`new row violates row-level security policy`). |
| **18** | Unpublished or review-required records are not exposed. | **VERIFIED** | Enforced in `sql/policies.sql` (`is_published = true AND review_required = false`), `sql/indexes.sql`, and `src/utils/searchEngine.ts` (verified by unit test). |
| **19** | No service-role key appears in public files. | **VERIFIED** | Only the public project URL and `anon` key appear in frontend files; `.env.local` is in `.gitignore`. |
| **20** | The site works on mobile and desktop. | **VERIFIED** | Verified responsive layout at `1440x900` (desktop) and `390x844` (mobile) with horizontal scrolling inside `<pre>` blocks and zero page overflow. |
| **21** | The website does not require login. | **VERIFIED** | Publicly accessible immediately on load with zero authentication gates or popups. |
| **22** | Deployment instructions are complete. | **VERIFIED** | Documented step-by-step in `README.md`. |
| **23** | Testing claims match the tests actually performed. | **VERIFIED** | All unit tests (`tsx --test`), live `curl` RLS tests against `epmjvlgcgsvhylaskabn.supabase.co`, and headless Chromium browser checks were executed and verified. |
