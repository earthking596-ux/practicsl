import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import {
  Search,
  Terminal,
  X,
  Copy,
  Check,
  AlertTriangle,
  RefreshCw,
  FileCode2,
  Loader2,
  FileText,
  ExternalLink,
  Download,
} from 'lucide-react';
import supabase, {
  PracticalRecord,
  SubjectRecord,
} from './lib/supabase';
import {
  SHARED_AI_RMP_MODULE,
  SHARED_AI_RWP_MODULE,
} from './data/practicalsDataset';
import {
  filterAndRankPracticals,
  getSubjectCounts,
  RankedPractical,
} from './utils/searchEngine';
import { copyRawTextToClipboard } from './utils/clipboard';
import { PracticalCard } from './components/PracticalCard';
import { PdfViewerModal, PdfViewerState } from './components/PdfViewerModal';

const PAGE_SIZE = 15;

interface SubjectPdfInfo {
  subjectName: string;
  subjectSlug: string;
  pdfFilename: string;
  pagesCount: number;
  practicalsCount: number;
}

const ORIGINAL_SUBJECT_PDFS: SubjectPdfInfo[] = [
  {
    subjectName: 'Artificial Intelligence',
    subjectSlug: 'artificial-intelligence',
    pdfFilename: 'final_AI__3f2816a9.pdf',
    pagesCount: 28,
    practicalsCount: 9,
  },
  {
    subjectName: 'Ethical Hacking',
    subjectSlug: 'ethical-hacking',
    pdfFilename: 'final_ethical_hacking_607197eb.pdf',
    pagesCount: 38,
    practicalsCount: 10,
  },
  {
    subjectName: 'Software Testing and Quality Assurance',
    subjectSlug: 'stqa',
    pdfFilename: 'final_STQA_b89bf2f3.pdf',
    pagesCount: 52,
    practicalsCount: 10,
  },
  {
    subjectName: 'Cryptography and Network Security',
    subjectSlug: 'cryptography-and-network-security',
    pdfFilename: 'finalCNS_69f47646.pdf',
    pagesCount: 28,
    practicalsCount: 10,
  },
];

export default function App() {
  // Search & Filter State
  const [searchInput, setSearchInput] = useState<string>('');
  const [debouncedQuery, setDebouncedQuery] = useState<string>('');
  const [selectedSubject, setSelectedSubject] = useState<string>('all');
  const [visibleLimit, setVisibleLimit] = useState<number>(PAGE_SIZE);

  // Live Practicals & Subjects State
  const [subjects, setSubjects] = useState<SubjectRecord[]>([]);
  const [allPracticals, setAllPracticals] = useState<PracticalRecord[]>([]);
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  // Shared Module Copy & PDF Viewer State
  const [copiedSharedFile, setCopiedSharedFile] = useState<string | null>(null);
  const [activePdf, setActivePdf] = useState<PdfViewerState | null>(null);

  // Stale request guard
  const latestSyncIdRef = useRef<number>(0);

  /**
   * Fetch subjects and published practicals from Supabase.
   */
  const loadPracticals = useCallback(async () => {
    const syncId = ++latestSyncIdRef.current;
    setIsLoading(true);
    setConnectionError(null);

    try {
      const [subjectsRes, practicalsRes] = await Promise.all([
        supabase
          .from('subjects')
          .select('id, name, slug, description, created_at')
          .order('name', { ascending: true }),
        supabase
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
            subjects (
              id,
              name,
              slug
            )
          `
          )
          .eq('is_published', true)
          .eq('review_required', false)
          .order('practical_number', { ascending: true }),
      ]);

      if (syncId !== latestSyncIdRef.current) return;

      if (subjectsRes.error) {
        throw new Error(subjectsRes.error.message || 'Unable to load subjects.');
      }
      if (practicalsRes.error) {
        throw new Error(practicalsRes.error.message || 'Unable to load practicals.');
      }

      const loadedSubjects: SubjectRecord[] = subjectsRes.data || [];
      const livePracticalsRaw = practicalsRes.data || [];

      setSubjects(loadedSubjects);

      const subjectMap = new Map<string, SubjectRecord>(
        loadedSubjects.map((s) => [s.id, s])
      );

      const normalizedLive: PracticalRecord[] = livePracticalsRaw.map((row: any) => {
        const joinedSubj = Array.isArray(row.subjects) ? row.subjects[0] : row.subjects;
        const fallbackSubj = subjectMap.get(row.subject_id);
        return {
          id: row.id,
          subject_id: row.subject_id,
          subject_name: joinedSubj?.name || fallbackSubj?.name || 'Subject',
          subject_slug: joinedSubj?.slug || fallbackSubj?.slug || '',
          practical_number: row.practical_number,
          title: row.title || row.original_question,
          original_question: row.original_question,
          corrected_code: row.corrected_code,
          original_code: row.original_code,
          programming_language: row.programming_language,
          expected_output: row.expected_output,
          algorithm_steps: Array.isArray(row.algorithm_steps) ? row.algorithm_steps : [],
          procedure_steps: Array.isArray(row.procedure_steps) ? row.procedure_steps : [],
          instructions: row.instructions,
          keywords: Array.isArray(row.keywords) ? row.keywords : [],
          aliases: Array.isArray(row.aliases) ? row.aliases : [],
          source_pdf: row.source_pdf || '',
          source_pages: Array.isArray(row.source_pages) ? row.source_pages : [],
          verification_status: row.verification_status || 'verified',
          review_required: Boolean(row.review_required),
          is_published: row.is_published !== false,
        };
      });

      setAllPracticals(normalizedLive);
    } catch (err: any) {
      if (syncId !== latestSyncIdRef.current) return;
      setConnectionError(
        err instanceof Error
          ? err.message
          : 'Unable to load practicals right now. Please check your connection and try again.'
      );
    } finally {
      if (syncId === latestSyncIdRef.current) {
        setIsLoading(false);
      }
    }
  }, []);

  useEffect(() => {
    loadPracticals();
  }, [loadPracticals]);

  // Debounce search input slightly (180ms)
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedQuery(searchInput);
      setVisibleLimit(PAGE_SIZE);
    }, 180);
    return () => clearTimeout(timer);
  }, [searchInput]);

  // Handle explicit form submission immediately
  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setDebouncedQuery(searchInput);
    setVisibleLimit(PAGE_SIZE);
  };

  const handleClearSearch = () => {
    setSearchInput('');
    setDebouncedQuery('');
    setVisibleLimit(PAGE_SIZE);
  };

  const handleSubjectSelect = (slug: string) => {
    setSelectedSubject(slug);
    setVisibleLimit(PAGE_SIZE);
  };

  // Compute subject counts and ranked search results
  const subjectCounts = useMemo(
    () => getSubjectCounts(allPracticals, subjects),
    [allPracticals, subjects]
  );

  const searchResponse = useMemo(
    () =>
      filterAndRankPracticals(allPracticals, {
        query: debouncedQuery,
        subjectSlug: selectedSubject,
        limit: visibleLimit,
        offset: 0,
      }),
    [allPracticals, debouncedQuery, selectedSubject, visibleLimit]
  );

  const handleCopySharedModule = async (filename: string, rawCode: string) => {
    const ok = await copyRawTextToClipboard(rawCode);
    if (ok) {
      setCopiedSharedFile(filename);
      setTimeout(() => setCopiedSharedFile(null), 2200);
    }
  };

  const quickQueries = [
    'Breadth First Search',
    'A* Search',
    'Naive-Bayes RWP',
    'Keylogger Python',
    'SQL Injection',
    'Selenium WebDriver Login',
    'Update 10 student records Excel',
    'RSA Digital Signature',
    'Diffie-Hellman',
  ];

  return (
    <div className="min-h-screen flex flex-col bg-slate-50 text-slate-900">
      {/* Top Navigation Bar */}
      <header className="sticky top-0 z-30 bg-white border-b border-slate-200 px-4 sm:px-8 py-3.5">
        <div className="max-w-6xl mx-auto flex items-center justify-between gap-8">
          {/* Brand Title */}
          <a
            href="#top"
            className="inline-flex items-center gap-2 text-base sm:text-lg font-bold tracking-tight text-slate-900 whitespace-nowrap shrink-0"
          >
            <Terminal className="w-5 h-5 text-blue-700 shrink-0" />
            <span>Python Compiler</span>
          </a>

          {/* Navigation Links */}
          <nav
            aria-label="Primary Navigation"
            className="hidden sm:flex items-center gap-6 text-sm font-medium text-slate-600"
          >
            <a
              href="#search-section"
              className="hover:text-slate-900 hover:underline underline-offset-4 transition-colors whitespace-nowrap shrink-0"
            >
              Practicals
            </a>
            <a
              href="#original-pdfs"
              className="hover:text-slate-900 hover:underline underline-offset-4 transition-colors whitespace-nowrap shrink-0"
            >
              Original PDFs
            </a>
            <a
              href="#shared-modules"
              className="hover:text-slate-900 hover:underline underline-offset-4 transition-colors whitespace-nowrap shrink-0"
            >
              Shared Modules
            </a>
          </nav>

          {/* Primary Action: Jump to Original PDFs */}
          <div className="flex items-center shrink-0">
            <a
              href="#original-pdfs"
              className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-medium text-white bg-blue-700 hover:bg-blue-800 rounded-md transition-colors whitespace-nowrap shrink-0"
            >
              <FileText className="w-3.5 h-3.5" />
              <span>Original PDFs</span>
            </a>
          </div>
        </div>
      </header>

      {/* Main Content Container */}
      <main id="top" className="flex-1 max-w-6xl w-full mx-auto px-4 sm:px-8 py-8 sm:py-10 space-y-10">
        {/* Hero & Search Section */}
        <section id="search-section" className="space-y-6">
          <div className="max-w-3xl space-y-2">
            <h1 className="text-2xl sm:text-4xl font-bold tracking-tight text-slate-900">
              Python Compiler
            </h1>
            <p className="text-base sm:text-lg text-slate-600">
              Search your practical. Get the code. Copy in one click.
            </p>
          </div>

          {/* Search Form */}
          <form onSubmit={handleSearchSubmit} role="search" className="space-y-3">
            <label htmlFor="practical-search-input" className="sr-only">
              Search practical question, program title, algorithm, keyword, or practical number
            </label>
            <div className="flex flex-col sm:flex-row gap-2.5">
              <div className="relative flex-1">
                <Search
                  aria-hidden="true"
                  className="w-5 h-5 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none"
                />
                <input
                  id="practical-search-input"
                  type="text"
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  placeholder="Type your practical question, algorithm (e.g. BFS, A*, Keylogger, RSA, Selenium), or Practical No..."
                  className="w-full pl-11 pr-10 py-3.5 bg-white border border-slate-300 rounded-lg text-sm sm:text-base text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-blue-600"
                />
                {searchInput.length > 0 && (
                  <button
                    type="button"
                    onClick={handleClearSearch}
                    aria-label="Clear search query"
                    className="absolute right-2.5 top-1/2 -translate-y-1/2 p-1.5 text-slate-400 hover:text-slate-700 rounded-md hover:bg-slate-100 cursor-pointer"
                  >
                    <X className="w-4 h-4" />
                  </button>
                )}
              </div>

              <button
                type="submit"
                className="inline-flex items-center justify-center gap-2 px-6 py-3.5 bg-blue-700 hover:bg-blue-800 text-white text-sm font-semibold rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
              >
                <Search className="w-4 h-4" />
                <span>Search Practicals</span>
              </button>
            </div>

            {/* Quick Search Suggestions */}
            <div className="flex flex-wrap items-center gap-1.5 pt-1 text-xs">
              <span className="text-slate-500 font-medium mr-1">Quick searches:</span>
              {quickQueries.map((q) => (
                <button
                  key={q}
                  type="button"
                  onClick={() => {
                    setSearchInput(q);
                    setDebouncedQuery(q);
                    setVisibleLimit(PAGE_SIZE);
                  }}
                  className="px-2.5 py-1 bg-white border border-slate-200 hover:border-blue-400 hover:text-blue-800 text-slate-700 rounded transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                >
                  {q}
                </button>
              ))}
            </div>
          </form>

          {/* Subject Filters */}
          <div className="space-y-2">
            <div className="text-xs font-semibold text-slate-500">
              Filter by Subject
            </div>
            <div
              role="group"
              aria-label="Filter practicals by subject"
              className="flex flex-wrap items-center gap-2"
            >
              <button
                type="button"
                onClick={() => handleSubjectSelect('all')}
                aria-pressed={selectedSubject === 'all'}
                className={`px-3.5 py-2 text-xs sm:text-sm font-medium rounded-md border transition-colors whitespace-nowrap shrink-0 cursor-pointer font-mono tabular-nums ${
                  selectedSubject === 'all'
                    ? 'bg-slate-900 border-slate-900 text-white'
                    : 'bg-white border-slate-300 text-slate-700 hover:bg-slate-100'
                }`}
              >
                All Subjects ({subjectCounts.all ?? allPracticals.length})
              </button>

              {subjects.map((subj) => {
                const count = subjectCounts[subj.slug] ?? 0;
                const isActive = selectedSubject === subj.slug;
                return (
                  <button
                    key={subj.id}
                    type="button"
                    onClick={() => handleSubjectSelect(subj.slug)}
                    aria-pressed={isActive}
                    className={`px-3.5 py-2 text-xs sm:text-sm font-medium rounded-md border transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                      isActive
                        ? 'bg-blue-700 border-blue-700 text-white'
                        : 'bg-white border-slate-300 text-slate-700 hover:bg-slate-100'
                    }`}
                  >
                    <span>{subj.name}</span>{' '}
                    <span className="font-mono tabular-nums opacity-85">({count})</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Error Banner */}
          {connectionError && (
            <div
              role="alert"
              className="bg-red-50 border border-red-200 rounded-lg p-4 flex flex-wrap items-center justify-between gap-4 text-xs sm:text-sm text-red-900"
            >
              <div className="flex items-start gap-2.5">
                <AlertTriangle className="w-5 h-5 text-red-700 shrink-0 mt-0.5" />
                <div>
                  <div className="font-semibold">Unable to load practicals</div>
                  <div className="text-red-800 mt-0.5">{connectionError}</div>
                </div>
              </div>
              <button
                type="button"
                onClick={loadPracticals}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white border border-red-300 text-red-900 font-medium rounded hover:bg-red-100 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
              >
                <RefreshCw className="w-3.5 h-3.5" />
                <span>Retry</span>
              </button>
            </div>
          )}

          {/* Results Count & Active Filter Bar */}
          <div className="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-slate-200 text-xs sm:text-sm text-slate-600">
            <div className="flex items-center gap-2 font-mono tabular-nums" aria-live="polite">
              {isLoading ? (
                <span className="inline-flex items-center gap-2 text-slate-600">
                  <Loader2 className="w-4 h-4 animate-spin text-blue-700" />
                  <span>Loading practicals...</span>
                </span>
              ) : (
                <span>
                  Showing <strong>{searchResponse.results.length}</strong> of{' '}
                  <strong>{searchResponse.totalCount}</strong> matching{' '}
                  {searchResponse.totalCount === 1 ? 'practical' : 'practicals'}
                  {selectedSubject !== 'all'
                    ? ` in ${
                        subjects.find((s) => s.slug === selectedSubject)?.name || selectedSubject
                      }`
                    : ' across all subjects'}
                  {debouncedQuery.trim() ? ` for "${debouncedQuery.trim()}"` : ''}
                </span>
              )}
            </div>

            {(debouncedQuery.trim() !== '' || selectedSubject !== 'all') && (
              <button
                type="button"
                onClick={() => {
                  setSearchInput('');
                  setDebouncedQuery('');
                  setSelectedSubject('all');
                  setVisibleLimit(PAGE_SIZE);
                }}
                className="text-xs font-medium text-blue-700 hover:text-blue-900 hover:underline cursor-pointer"
              >
                Reset search & subject filter
              </button>
            )}
          </div>

          {/* Search Results List or Empty State */}
          {!isLoading && searchResponse.totalCount === 0 ? (
            <div
              data-testid="empty-search-state"
              className="bg-white border border-slate-200 rounded-lg p-10 text-center space-y-3"
            >
              <p className="text-base font-medium text-slate-800 m-0">
                No matching practical found. Try different keywords or select another subject.
              </p>
              <div className="pt-2">
                <button
                  type="button"
                  onClick={() => {
                    setSearchInput('');
                    setDebouncedQuery('');
                    setSelectedSubject('all');
                  }}
                  className="px-4 py-2 text-xs font-medium bg-slate-900 text-white rounded-md hover:bg-slate-800 transition-colors cursor-pointer"
                >
                  Show All Practicals
                </button>
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              {searchResponse.results.map((practical: RankedPractical, idx: number) => (
                <PracticalCard
                  key={practical.id}
                  practical={practical}
                  defaultExpanded={searchResponse.totalCount === 1 || (debouncedQuery.trim() !== '' && idx === 0)}
                  onOpenPdf={(pdfState) => setActivePdf(pdfState)}
                />
              ))}

              {searchResponse.hasMore && (
                <div className="pt-4 text-center">
                  <button
                    type="button"
                    onClick={() => setVisibleLimit((prev) => prev + PAGE_SIZE)}
                    className="px-5 py-2.5 text-xs sm:text-sm font-medium bg-white border border-slate-300 hover:bg-slate-100 text-slate-800 rounded-md transition-colors cursor-pointer font-mono tabular-nums"
                  >
                    Load More Practicals ({searchResponse.results.length} of{' '}
                    {searchResponse.totalCount} shown)
                  </button>
                </div>
              )}
            </div>
          )}
        </section>

        {/* Original Subject Practical PDFs Section */}
        <section id="original-pdfs" className="pt-8 border-t border-slate-200 space-y-4">
          <div className="space-y-1">
            <h2 className="text-lg sm:text-xl font-bold text-slate-900">
              Original Practical Manuals (PDF)
            </h2>
            <p className="text-xs sm:text-sm text-slate-600">
              View the complete original practical PDF for any subject directly on this page, open it
              in a new tab, or download a copy.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 items-stretch">
            {ORIGINAL_SUBJECT_PDFS.map((item) => {
              const pdfUrl = `/assets/aistudio/${item.pdfFilename}`;
              return (
                <div
                  key={item.subjectSlug}
                  className="bg-white border border-slate-200 rounded-lg p-5 flex flex-col justify-between space-y-4"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2 text-xs text-slate-500 font-mono tabular-nums">
                      <FileText className="w-4 h-4 text-blue-700 shrink-0" />
                      <span>{item.practicalsCount} Practicals</span>
                      <span aria-hidden="true">·</span>
                      <span>{item.pagesCount} Pages</span>
                    </div>
                    <h3 className="text-base font-semibold text-slate-900">
                      {item.subjectName}
                    </h3>
                  </div>

                  <div className="flex flex-wrap items-center gap-2 pt-2 border-t border-slate-100">
                    <button
                      type="button"
                      onClick={() =>
                        setActivePdf({
                          title: `${item.subjectName} — Original Practical PDF`,
                          subtitle: `${item.practicalsCount} Practicals · ${item.pagesCount} Pages`,
                          pdfFilename: item.pdfFilename,
                          page: 1,
                        })
                      }
                      className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-medium bg-blue-700 hover:bg-blue-800 text-white rounded-md transition-colors whitespace-nowrap cursor-pointer"
                    >
                      <FileText className="w-3.5 h-3.5" />
                      <span>View Original PDF</span>
                    </button>

                    <a
                      href={pdfUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-medium bg-white border border-slate-300 hover:bg-slate-50 text-slate-700 rounded-md transition-colors whitespace-nowrap"
                    >
                      <ExternalLink className="w-3.5 h-3.5" />
                      <span>Open Tab</span>
                    </a>

                    <a
                      href={pdfUrl}
                      download={item.pdfFilename}
                      className="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-medium bg-white border border-slate-300 hover:bg-slate-50 text-slate-700 rounded-md transition-colors whitespace-nowrap"
                    >
                      <Download className="w-3.5 h-3.5" />
                      <span>Download</span>
                    </a>
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        {/* Shared Dependency Modules Section (RMP.py & RWP.py for AI Practicals) */}
        <section id="shared-modules" className="pt-8 border-t border-slate-200 space-y-4">
          <div className="space-y-1">
            <h2 className="text-lg sm:text-xl font-bold text-slate-900">
              Shared Python Modules (RMP.py & RWP.py)
            </h2>
            <p className="text-xs sm:text-sm text-slate-600">
              AI Practicals 1–4 import <code>RMP.py</code> and AI Practical 6 imports{' '}
              <code>RWP.py</code>. Save these files in the same folder as your practical scripts.
            </p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-stretch">
            {/* RMP.py Card */}
            <div className="bg-white border border-slate-200 rounded-lg p-5 flex flex-col justify-between space-y-3">
              <div className="space-y-2">
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <FileCode2 className="w-4 h-4 text-blue-700" />
                    <h3 className="text-sm font-semibold text-slate-900">
                      RMP.py (Romanian Map Problem)
                    </h3>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleCopySharedModule('RMP.py', SHARED_AI_RMP_MODULE)}
                    className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                      copiedSharedFile === 'RMP.py'
                        ? 'bg-emerald-700 text-white'
                        : 'bg-blue-700 text-white hover:bg-blue-800'
                    }`}
                  >
                    {copiedSharedFile === 'RMP.py' ? (
                      <>
                        <Check className="w-3.5 h-3.5" />
                        <span>Copied RMP.py!</span>
                      </>
                    ) : (
                      <>
                        <Copy className="w-3.5 h-3.5" />
                        <span>Copy RMP.py</span>
                      </>
                    )}
                  </button>
                </div>
                <p className="text-xs text-slate-600 m-0">
                  Used by AI Practicals 1 (BFS), 2 (IDDFS), 3 (A* Search), and 4 (RBFS).
                </p>
              </div>
              <pre className="bg-slate-900 text-slate-100 rounded-md p-3.5 text-xs font-mono overflow-x-auto max-h-60 m-0 whitespace-pre">
                <code>{SHARED_AI_RMP_MODULE}</code>
              </pre>
            </div>

            {/* RWP.py Card */}
            <div className="bg-white border border-slate-200 rounded-lg p-5 flex flex-col justify-between space-y-3">
              <div className="space-y-2">
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <FileCode2 className="w-4 h-4 text-blue-700" />
                    <h3 className="text-sm font-semibold text-slate-900">
                      RWP.py (Restaurant Waiting Problem)
                    </h3>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleCopySharedModule('RWP.py', SHARED_AI_RWP_MODULE)}
                    className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                      copiedSharedFile === 'RWP.py'
                        ? 'bg-emerald-700 text-white'
                        : 'bg-blue-700 text-white hover:bg-blue-800'
                    }`}
                  >
                    {copiedSharedFile === 'RWP.py' ? (
                      <>
                        <Check className="w-3.5 h-3.5" />
                        <span>Copied RWP.py!</span>
                      </>
                    ) : (
                      <>
                        <Copy className="w-3.5 h-3.5" />
                        <span>Copy RWP.py</span>
                      </>
                    )}
                  </button>
                </div>
                <p className="text-xs text-slate-600 m-0">
                  Used by AI Practical 6 (Naive-Bayes Learning Algorithm for RWP).
                </p>
              </div>
              <pre className="bg-slate-900 text-slate-100 rounded-md p-3.5 text-xs font-mono overflow-x-auto max-h-60 m-0 whitespace-pre">
                <code>{SHARED_AI_RWP_MODULE}</code>
              </pre>
            </div>
          </div>
        </section>
      </main>

      {/* Simple Footer */}
      <footer className="bg-white border-t border-slate-200 px-4 sm:px-8 py-6 mt-12">
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
          <div>
            <strong>Python Compiler</strong> — Search your practical. Get the code. Copy in one click.
          </div>
          <div>
            Artificial Intelligence · Ethical Hacking · STQA · Cryptography &amp; Network Security
          </div>
        </div>
      </footer>

      {/* In-App Original PDF Viewer Modal */}
      <PdfViewerModal pdfState={activePdf} onClose={() => setActivePdf(null)} />
    </div>
  );
}
