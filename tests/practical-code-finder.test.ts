import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

import {
  normalizeText,
  tokenizeQuery,
  trigramSimilarity,
  scorePractical,
  searchPracticalsLocal
} from '../js/search.js';
import { isServiceRoleKey } from '../js/config.js';
import { formatStepsForCopy } from '../js/clipboard.js';

const manifestPath = path.resolve('data/extraction_manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

test('Dataset Inventory: contains all 4 subjects and 39 extracted practicals', () => {
  assert.equal(manifest.subjects.length, 4);
  assert.equal(manifest.practicals.length, 39);

  const counts = manifest.summary.counts_by_subject;
  assert.equal(counts['artificial-intelligence'], 9);
  assert.equal(counts['ethical-hacking'], 10);
  assert.equal(counts['software-testing-and-quality-assurance'], 10);
  assert.equal(counts['cryptography-and-network-security'], 10);
});

test('Dataset Integrity: no duplicate IDs or source_keys, all linked to valid subjects', () => {
  const ids = new Set();
  const keys = new Set();
  const subjectIds = new Set(manifest.subjects.map((s: any) => s.id));

  for (const p of manifest.practicals) {
    assert.ok(!ids.has(p.id), `Duplicate ID: ${p.id}`);
    assert.ok(!keys.has(p.source_key), `Duplicate source_key: ${p.source_key}`);
    assert.ok(subjectIds.has(p.subject_id), `Invalid subject_id on ${p.source_key}`);
    assert.ok(p.original_question && p.original_question.trim().length > 0);
    assert.ok(Array.isArray(p.source_pages) && p.source_pages.length > 0);
    ids.add(p.id);
    keys.add(p.source_key);
  }
});

test('Code Formatting: preserves exact indentation and line breaks in corrected_code', () => {
  const bfs = manifest.practicals.find((p: any) => p.source_key === 'ai-prac-01');
  assert.ok(bfs);
  assert.ok(bfs.corrected_code.includes('def BFS(city, cityq, visitedq):\n    global result'));
  assert.ok(bfs.corrected_code.includes('dict_gn = dict('));
});

test('Search Engine: matches exact and partial questions across all 4 subjects', () => {
  // 1. AI: A* Search
  const aStarRes = searchPracticalsLocal(manifest.practicals, { query: 'A* Search algorithm' });
  assert.ok(aStarRes.items.length > 0);
  assert.equal(aStarRes.items[0].source_key, 'ai-prac-03');

  // 2. Ethical Hacking: Nmap Port Scanning
  const nmapRes = searchPracticalsLocal(manifest.practicals, { query: 'Port Scanning with Nmap' });
  assert.ok(nmapRes.items.length > 0);
  assert.equal(nmapRes.items[0].source_key, 'eh-prac-04');

  // 3. STQA: Update 10 student records in Excel
  const excelRes = searchPracticalsLocal(manifest.practicals, { query: 'update 10 student records in an Excel file' });
  assert.ok(excelRes.items.length > 0);
  assert.equal(excelRes.items[0].source_key, 'stqa-prac-05');

  // 4. CNS: Diffie Hellman
  const dhRes = searchPracticalsLocal(manifest.practicals, { query: 'Diffie Hellman Key Exchange' });
  assert.ok(dhRes.items.length > 0);
  assert.equal(dhRes.items[0].source_key, 'cns-prac-05');
});

test('Search Engine: handles common spelling mistakes and subject filtering', () => {
  // Spelling mistake: "breadth frst serch"
  const typoRes = searchPracticalsLocal(manifest.practicals, { query: 'breadth frst serch' });
  assert.ok(typoRes.items.length > 0);
  assert.equal(typoRes.items[0].source_key, 'ai-prac-01');

  // Subject filter: only STQA practicals
  const stqaOnly = searchPracticalsLocal(manifest.practicals, {
    query: '',
    subjectSlug: 'software-testing-and-quality-assurance',
    limit: 50
  });
  assert.equal(stqaOnly.totalCount, 10);
  assert.ok(stqaOnly.items.every((p: any) => p.subject_slug === 'software-testing-and-quality-assurance'));
});

test('Search Engine: returns empty array for unrelated queries', () => {
  const noMatch = searchPracticalsLocal(manifest.practicals, {
    query: 'quantum blockchain compiler solidity recipe'
  });
  assert.equal(noMatch.totalCount, 0);
  assert.equal(noMatch.items.length, 0);
});

test('Security & Clipboard Helpers: blocks service_role keys and formats steps accurately', () => {
  // Fake JWT with {"role":"service_role"}
  const fakeServicePayload = Buffer.from(JSON.stringify({ role: 'service_role' })).toString('base64url');
  const fakeServiceJwt = `eyJhbGciOiJIUzI1NiJ9.${fakeServicePayload}.sig`;
  assert.equal(isServiceRoleKey(fakeServiceJwt), true);
  assert.equal(isServiceRoleKey('sb_secret_123456789'), true);

  // Fake JWT with {"role":"anon"}
  const fakeAnonPayload = Buffer.from(JSON.stringify({ role: 'anon' })).toString('base64url');
  const fakeAnonJwt = `eyJhbGciOiJIUzI1NiJ9.${fakeAnonPayload}.sig`;
  assert.equal(isServiceRoleKey(fakeAnonJwt), false);

  const stepsStr = formatStepsForCopy(['Step 1: Open Firefox', 'Initialize WebDriver']);
  assert.equal(stepsStr, 'Step 1: Open Firefox\nStep 2: Initialize WebDriver');
});
