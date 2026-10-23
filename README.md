# Practical Code Finder

**Search your practical. Get the code. Copy in one click.**

Practical Code Finder is a public, read-only academic web application designed for college students to search practical questions across four subjects, view verified source code or ordered procedure steps, and copy solutions with one click:

1. **Artificial Intelligence** (`final_AI__3f2816a9.pdf` — 9 Practicals + `RMP.py` & `RWP.py`)
2. **Ethical Hacking** (`final_ethical_hacking_607197eb.pdf` — 10 Practicals)
3. **Software Testing and Quality Assurance (STQA)** (`final_STQA_b89bf2f3.pdf` — 10 Practicals)
4. **Cryptography and Network Security (CNS)** (`finalCNS_69f47646.pdf` — 10 Practicals)

---

## Project Structure

```text
practical-code-finder/
├── index.html                        # Entry HTML page
├── css/
│   └── style.css                     # Academic stylesheet
├── js/
│   ├── config.js                     # Public Supabase configuration (Project URL & Anon Key)
│   ├── supabase-client.js            # Vanilla JS Supabase client initialization
│   ├── search.js                     # Supabase RPC & PostgREST search client
│   ├── clipboard.js                  # Exact raw string clipboard helper
│   └── app.js                        # Vanilla JS module entry point
├── src/
│   ├── lib/
│   │   └── supabase.ts               # TypeScript Supabase client utility (@supabase/supabase-js)
│   ├── data/
│   │   └── practicalsDataset.ts      # Complete extracted dataset (4 subjects, 39 practicals)
│   ├── utils/
│   │   ├── searchEngine.ts           # Weighted relevance ranking & fuzzy search logic
│   │   ├── searchEngine.test.ts      # Node built-in unit tests (9 test suites)
│   │   └── clipboard.ts              # One-click raw code & steps copy utility
│   ├── components/
│   │   ├── PracticalCard.tsx         # Expandable practical result card & code viewer
│   │   └── DatabaseSetupModal.tsx    # Supabase SQL & RLS setup assistant
│   ├── App.tsx                       # Main application interface
│   └── main.tsx                      # Application bootstrap
├── sql/
│   ├── schema.sql                    # PostgreSQL tables (subjects, practicals, practical_search_terms)
│   ├── policies.sql                  # Row Level Security (RLS) read-only public policies
│   ├── indexes.sql                   # GIN FTS, pg_trgm indexes, and public.search_practicals RPC
│   └── seed_import_notes.sql         # Idempotent INSERT ... ON CONFLICT seed SQL for all 39 practicals
├── data/
│   └── extraction_manifest.json      # Structured JSON manifest of all extracted PDF practicals
├── scripts/
│   ├── generate_artifacts.ts         # Generates seed_import_notes.sql and extraction_manifest.json
│   └── import_to_supabase.mjs        # Local Node.js bulk import script (uses SUPABASE_SERVICE_ROLE_KEY)
├── TESTING_CHECKLIST.md              # 23-point verification checklist & actual test results
├── .env.example                      # Environment variable template
└── .gitignore                        # Excludes .env.local and service-role secrets
```

---

## Step-by-Step Supabase Setup & Deployment Guide

### 1. Locate Your Supabase Project Configuration
Your project is configured to connect to:
- **Project URL:** `https://epmjvlgcgsvhylaskabn.supabase.co`
- **REST Endpoint:** `https://epmjvlgcgsvhylaskabn.supabase.co/rest/v1/`
- **Public Anon Key:** Configured in `src/lib/supabase.ts` and `js/config.js`.

> **Security Note:** Never put your `service_role` secret key or database password in frontend files (`src/`, `js/`, `index.html`) or commit them to GitHub. The public website uses only the `anon` key and relies on PostgreSQL Row Level Security (RLS) to block all unauthorized writes.

### 2. Apply the SQL Schema, RLS Policies, Indexes, and Seed Data
1. Open your [Supabase Project Dashboard](https://supabase.com/dashboard/project/epmjvlgcgsvhylaskabn).
2. Click **SQL Editor** in the left sidebar and click **New query**.
3. Run the SQL files in order (or copy them with one click using the **"Database & Seed SQL"** button in the top bar of the website):
   - `sql/schema.sql` — Creates `subjects`, `practicals`, and `practical_search_terms`.
   - `sql/policies.sql` — Enables RLS and grants read-only `SELECT` access on approved records to `anon`.
   - `sql/indexes.sql` — Creates `pg_trgm` and GIN full-text indexes plus the `public.search_practicals` RPC function.
   - `sql/seed_import_notes.sql` — Inserts all 4 subjects and all 39 extracted practicals.

### 3. Alternative: Bulk Import via Local Script
If you prefer importing via Node.js instead of the Supabase SQL Editor:
1. Create `.env.local` in the project root (already ignored by `.gitignore`):
   ```env
   VITE_SUPABASE_URL="https://epmjvlgcgsvhylaskabn.supabase.co"
   SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
   ```
2. Run:
   ```bash
   node scripts/import_to_supabase.mjs
   ```

### 4. Run Locally & Test
```bash
npm install
npx tsx --test src/utils/searchEngine.test.ts
npm run dev
```

### 5. Deploy to Free Static Hosting (GitHub Pages / Cloudflare Pages / Netlify / Vercel)
1. Run `npm run build` to produce the static production bundle in `dist/`.
2. Deploy the `dist/` directory to any free static host (e.g., GitHub Pages, Cloudflare Pages, or Netlify).
3. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in the static host's build environment variables if deploying to a new project.
