import { PracticalRecord, SubjectRecord } from '../lib/supabase';

export interface SearchOptions {
  query: string;
  subjectSlug?: string;
  limit?: number;
  offset?: number;
}

export interface RankedPractical extends PracticalRecord {
  relevanceScore: number;
  matchedFields: string[];
}

export interface SearchResponse {
  results: RankedPractical[];
  totalCount: number;
  hasMore: boolean;
  dataSource: 'supabase-rpc' | 'supabase-rest' | 'verified-manifest';
}

const STOP_WORDS = new Set([
  'a', 'an', 'the', 'to', 'for', 'in', 'on', 'of', 'and', 'or', 'with', 'by', 'is', 'are', 'be', 'as', 'at', 'from'
]);

/**
 * Normalize text for comparison while keeping meaningful symbols like * (for A*).
 */
export function normalizeSearchText(input: string): string {
  return String(input || '')
    .toLowerCase()
    .replace(/['’`"]/g, '')
    .replace(/[^a-z0-9*+#._\-\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Compute character trigram similarity (0..1) between two strings, similar to PostgreSQL pg_trgm.
 */
export function trigramSimilarity(a: string, b: string): number {
  const s1 = `  ${normalizeSearchText(a)} `;
  const s2 = `  ${normalizeSearchText(b)} `;
  if (s1.trim().length === 0 || s2.trim().length === 0) return 0;
  if (s1 === s2) return 1;

  const trigrams1 = new Set<string>();
  const trigrams2 = new Set<string>();

  for (let i = 0; i <= s1.length - 3; i++) {
    trigrams1.add(s1.slice(i, i + 3));
  }
  for (let i = 0; i <= s2.length - 3; i++) {
    trigrams2.add(s2.slice(i, i + 3));
  }

  if (trigrams1.size === 0 || trigrams2.size === 0) return 0;

  let intersection = 0;
  for (const t of trigrams1) {
    if (trigrams2.has(t)) intersection++;
  }

  return (2 * intersection) / (trigrams1.size + trigrams2.size);
}

/**
 * Compute bounded Levenshtein edit distance between two tokens for typo tolerance.
 */
export function editDistance(a: string, b: string): number {
  if (a === b) return 0;
  if (Math.abs(a.length - b.length) > 3) return 99;
  const dp: number[][] = Array.from({ length: a.length + 1 }, () =>
    new Array(b.length + 1).fill(0)
  );
  for (let i = 0; i <= a.length; i++) dp[i][0] = i;
  for (let j = 0; j <= b.length; j++) dp[0][j] = j;

  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost
      );
    }
  }
  return dp[a.length][b.length];
}

/**
 * Extract explicit practical number if the user types e.g. "Practical 4", "prac no 4", "p4", or "4".
 */
export function parsePracticalNumberQuery(rawQuery: string): number | null {
  const clean = rawQuery.trim();
  const match = clean.match(
    /^(?:practical|prac|exp|experiment|sr\.?\s*no\.?|no\.?|p)?\s*(?:no\.?|number|#|:|-)?\s*(\d{1,2})$/i
  );
  if (match) {
    return parseInt(match[1], 10);
  }
  const inlineMatch = clean.match(/\b(?:practical|prac|no\.?|p)\s*#?\s*(\d{1,2})\b/i);
  if (inlineMatch) {
    return parseInt(inlineMatch[1], 10);
  }
  return null;
}

/**
 * Score a single practical record against a user search query using weighted relevance.
 */
export function scorePracticalRecord(
  record: PracticalRecord,
  rawQuery: string
): { score: number; matchedFields: string[] } {
  const normQuery = normalizeSearchText(rawQuery);
  if (!normQuery) {
    return { score: 1, matchedFields: [] };
  }

  const matchedFields: string[] = [];
  let score = 0;

  const normQuestion = normalizeSearchText(record.original_question);
  const normTitle = normalizeSearchText(record.title);
  const normSubject = normalizeSearchText(record.subject_name || '');
  const normLang = normalizeSearchText(record.programming_language || '');
  const normOutput = normalizeSearchText(record.expected_output || '');
  const normKeywords = (record.keywords || []).map(normalizeSearchText);
  const normAliases = (record.aliases || []).map(normalizeSearchText);
  const normSteps = normalizeSearchText(
    [...(record.algorithm_steps || []), ...(record.procedure_steps || [])].join(' ')
  );
  const normCode = normalizeSearchText(record.corrected_code || '');

  // 1. Practical Number match
  const parsedPracNo = parsePracticalNumberQuery(rawQuery);
  if (parsedPracNo !== null && record.practical_number === parsedPracNo) {
    score += 65;
    matchedFields.push('practical_number');
  }

  // 2. Exact / Full Phrase match in Question or Title (Highest priority)
  if (normQuestion === normQuery) {
    score += 120;
    matchedFields.push('exact_question');
  } else if (normQuestion.includes(normQuery)) {
    score += 75;
    matchedFields.push('original_question');
  }

  if (normTitle === normQuery) {
    score += 100;
    matchedFields.push('exact_title');
  } else if (normTitle.includes(normQuery)) {
    score += 65;
    matchedFields.push('title');
  }

  // 3. Keyword & Alias exact or substring match
  for (const kw of [...normKeywords, ...normAliases]) {
    if (kw === normQuery) {
      score += 70;
      matchedFields.push('keyword_exact');
      break;
    } else if (kw.includes(normQuery) || (normQuery.length >= 3 && normQuery.includes(kw))) {
      score += 40;
      matchedFields.push('keyword');
      break;
    }
  }

  // 4. Subject abbreviation / Subject name match
  const subjectAbbreviations: Record<string, string[]> = {
    'artificial-intelligence': ['ai', 'artificial intelligence', 'machine learning', 'ml'],
    'ethical-hacking': ['eh', 'ethical hacking', 'cybersecurity', 'kali linux', 'hacking'],
    stqa: ['stqa', 'sqta', 'software testing', 'quality assurance', 'selenium'],
    'cryptography-and-network-security': ['cns', 'cryptography', 'network security', 'crypto'],
  };
  const subjAbbrevs = subjectAbbreviations[record.subject_slug || ''] || [];
  if (normSubject.includes(normQuery) || subjAbbrevs.includes(normQuery)) {
    score += 35;
    matchedFields.push('subject');
  }

  // 5. Programming Language match
  if (normLang && (normLang === normQuery || normLang.includes(normQuery))) {
    score += 30;
    matchedFields.push('programming_language');
  }

  // 6. Token-level & Fuzzy / Typo-tolerant matching across Question, Title, Keywords, Output, Steps
  const rawTokens = normQuery.split(' ').filter(Boolean);
  const meaningfulTokens = rawTokens.filter((t) => !STOP_WORDS.has(t) || rawTokens.length === 1);
  const tokensToUse = meaningfulTokens.length > 0 ? meaningfulTokens : rawTokens;

  if (tokensToUse.length > 0) {
    const questionWords = normQuestion.split(' ').filter(Boolean);
    const titleWords = normTitle.split(' ').filter(Boolean);
    const kwWords = [...normKeywords, ...normAliases]
      .join(' ')
      .split(' ')
      .filter(Boolean);
    const subjWords = [...normSubject.split(' '), ...subjAbbrevs].filter(Boolean);
    const langWords = normLang.split(' ').filter(Boolean);

    let matchedTokenCount = 0;
    let tokenScoreSum = 0;

    for (const token of tokensToUse) {
      // If token is a number and matches practical_number
      if (/^\d{1,2}$/.test(token) && record.practical_number === parseInt(token, 10)) {
        matchedTokenCount++;
        tokenScoreSum += 25;
        continue;
      }

      let bestTokenWeight = 0;

      // Check exact substring in high-priority fields
      if (normQuestion.includes(token)) {
        bestTokenWeight = Math.max(bestTokenWeight, 22);
      }
      if (normTitle.includes(token)) {
        bestTokenWeight = Math.max(bestTokenWeight, 20);
      }
      if (normKeywords.some((k) => k.includes(token)) || normAliases.some((a) => a.includes(token))) {
        bestTokenWeight = Math.max(bestTokenWeight, 18);
      }
      if (subjWords.some((sw) => sw === token) || normSubject.includes(token)) {
        bestTokenWeight = Math.max(bestTokenWeight, 14);
      }
      if (normLang.includes(token)) {
        bestTokenWeight = Math.max(bestTokenWeight, 14);
      }
      if (normOutput.includes(token)) {
        bestTokenWeight = Math.max(bestTokenWeight, 10);
      }
      if (normSteps.includes(token)) {
        bestTokenWeight = Math.max(bestTokenWeight, 8);
      }
      // Incidental match in source code gets low weight
      if (bestTokenWeight === 0 && token.length >= 3 && normCode.includes(token)) {
        bestTokenWeight = 4;
      }

      // Fuzzy typo-tolerance check if token length >= 4 and not already strongly matched
      if (bestTokenWeight < 14 && token.length >= 4) {
        const candidatePool = [...questionWords, ...titleWords, ...kwWords, ...langWords];
        for (const cand of candidatePool) {
          if (cand.length < 3) continue;
          const dist = editDistance(token, cand);
          const maxAllowedDist = token.length >= 7 ? 2 : 1;
          if (dist <= maxAllowedDist) {
            bestTokenWeight = Math.max(bestTokenWeight, 15 - dist * 3);
            matchedFields.push('fuzzy_typo');
            break;
          }
        }
      }

      if (bestTokenWeight > 0) {
        matchedTokenCount++;
        tokenScoreSum += bestTokenWeight;
      }
    }

    const tokenCoverage = matchedTokenCount / tokensToUse.length;
    if (tokenCoverage === 1) {
      score += tokenScoreSum * 1.35;
    } else if (tokenCoverage >= 0.5) {
      score += tokenScoreSum * tokenCoverage;
    } else {
      // Less than half of meaningful tokens matched: heavily penalize to avoid unrelated results
      score = score * 0.25;
    }
  }

  // 7. Whole-string trigram similarity boost for alternative question wording
  const qTrgm = Math.max(
    trigramSimilarity(normQuery, normQuestion),
    trigramSimilarity(normQuery, normTitle)
  );
  if (qTrgm >= 0.28) {
    score += qTrgm * 45;
  }

  return {
    score: Math.round(score * 100) / 100,
    matchedFields: Array.from(new Set(matchedFields)),
  };
}

/**
 * Filter and rank practical records across all four subjects.
 * Enforces publication/verification rules (is_published = true, review_required = false).
 */
export function filterAndRankPracticals(
  practicals: PracticalRecord[],
  options: SearchOptions
): SearchResponse {
  const { query = '', subjectSlug = 'all', limit = 20, offset = 0 } = options;
  const cleanQuery = query.trim();

  // Only allow published, verified/corrected, non-review-flagged records publicly
  const publicRecords = practicals.filter(
    (p) =>
      p.is_published !== false &&
      p.review_required !== true &&
      (p.verification_status === 'verified' || p.verification_status === 'corrected')
  );

  // Filter by subject if specified
  const subjectFiltered =
    !subjectSlug || subjectSlug === 'all'
      ? publicRecords
      : publicRecords.filter((p) => p.subject_slug === subjectSlug || p.subject_id === subjectSlug);

  // If query is empty, return records ordered by Subject name then Practical number
  if (!cleanQuery) {
    const sorted = [...subjectFiltered].sort((a, b) => {
      const subjCmp = (a.subject_name || '').localeCompare(b.subject_name || '');
      if (subjCmp !== 0) return subjCmp;
      return (a.practical_number ?? 999) - (b.practical_number ?? 999);
    });
    const rankedAll: RankedPractical[] = sorted.map((item) => ({
      ...item,
      relevanceScore: 1,
      matchedFields: [],
    }));
    const paginated = rankedAll.slice(offset, offset + limit);
    return {
      results: paginated,
      totalCount: rankedAll.length,
      hasMore: offset + limit < rankedAll.length,
      dataSource: 'verified-manifest',
    };
  }

  // Score and filter by minimum relevance threshold (12.0) so unrelated queries return 0 results
  const scored: RankedPractical[] = [];
  for (const record of subjectFiltered) {
    const { score, matchedFields } = scorePracticalRecord(record, cleanQuery);
    if (score >= 12.0) {
      scored.push({
        ...record,
        relevanceScore: score,
        matchedFields,
      });
    }
  }

  scored.sort((a, b) => {
    if (b.relevanceScore !== a.relevanceScore) {
      return b.relevanceScore - a.relevanceScore;
    }
    const subjCmp = (a.subject_name || '').localeCompare(b.subject_name || '');
    if (subjCmp !== 0) return subjCmp;
    return (a.practical_number ?? 999) - (b.practical_number ?? 999);
  });

  const paginated = scored.slice(offset, offset + limit);
  return {
    results: paginated,
    totalCount: scored.length,
    hasMore: offset + limit < scored.length,
    dataSource: 'verified-manifest',
  };
}

/**
 * Format algorithm or procedure steps into a clean numbered string for one-click copying.
 */
export function formatStepsForClipboard(
  algorithmSteps?: string[] | null,
  procedureSteps?: string[] | null
): string {
  const sections: string[] = [];

  if (algorithmSteps && algorithmSteps.length > 0) {
    const formattedAlgo = algorithmSteps
      .map((step, idx) => {
        const trimmed = String(step).trim();
        return /^(step\s*\d+|part\s*\d+|\d+[.)])/i.test(trimmed)
          ? trimmed
          : `${idx + 1}. ${trimmed}`;
      })
      .join('\n');
    sections.push(
      procedureSteps && procedureSteps.length > 0
        ? `Algorithm:\n${formattedAlgo}`
        : formattedAlgo
    );
  }

  if (procedureSteps && procedureSteps.length > 0) {
    const formattedProc = procedureSteps
      .map((step, idx) => {
        const trimmed = String(step).trim();
        return /^(step\s*\d+|part\s*\d+|\d+[.)])/i.test(trimmed)
          ? trimmed
          : `Step ${idx + 1}: ${trimmed}`;
      })
      .join('\n');
    sections.push(
      algorithmSteps && algorithmSteps.length > 0
        ? `Procedure:\n${formattedProc}`
        : formattedProc
    );
  }

  return sections.join('\n\n');
}

export function getSubjectCounts(
  practicals: PracticalRecord[],
  subjects: SubjectRecord[]
): Record<string, number> {
  const counts: Record<string, number> = { all: 0 };
  for (const s of subjects) {
    counts[s.slug] = 0;
  }
  for (const p of practicals) {
    if (
      p.is_published !== false &&
      p.review_required !== true &&
      (p.verification_status === 'verified' || p.verification_status === 'corrected')
    ) {
      counts.all = (counts.all || 0) + 1;
      if (p.subject_slug) {
        counts[p.subject_slug] = (counts[p.subject_slug] || 0) + 1;
      }
    }
  }
  return counts;
}
