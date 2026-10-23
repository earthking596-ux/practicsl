import test from 'node:test';
import assert from 'node:assert/strict';
import {
  EXTRACTED_SUBJECTS,
  EXTRACTED_PRACTICALS,
} from '../data/practicalsDataset';
import {
  filterAndRankPracticals,
  formatStepsForClipboard,
  parsePracticalNumberQuery,
  getSubjectCounts,
} from './searchEngine';

test('dataset inventory has all 4 subjects and all 39 practicals with zero omissions', () => {
  assert.equal(EXTRACTED_SUBJECTS.length, 4);
  assert.equal(EXTRACTED_PRACTICALS.length, 39);

  const counts = getSubjectCounts(EXTRACTED_PRACTICALS, EXTRACTED_SUBJECTS);
  assert.equal(counts['artificial-intelligence'], 9);
  assert.equal(counts['ethical-hacking'], 10);
  assert.equal(counts['stqa'], 10);
  assert.equal(counts['cryptography-and-network-security'], 10);
  assert.equal(counts.all, 39);
});

test('exact question search ranks the matching practical #1', () => {
  const res = filterAndRankPracticals(EXTRACTED_PRACTICALS, {
    query: 'Implement the A* Search algorithm for solving a pathfinding problem.',
  });
  assert.ok(res.results.length > 0);
  assert.equal(res.results[0].subject_slug, 'artificial-intelligence');
  assert.equal(res.results[0].practical_number, 3);
});

test('partial keyword and algorithm searches work across all four subjects', () => {
  const bfsRes = filterAndRankPracticals(EXTRACTED_PRACTICALS, { query: 'BFS Arad' });
  assert.equal(bfsRes.results[0].id, 'a1000000-0000-4000-8000-000000000001');

  const keyloggerRes = filterAndRankPracticals(EXTRACTED_PRACTICALS, { query: 'keylogger pynput' });
  assert.equal(keyloggerRes.results[0].id, 'b2000000-0000-4000-8000-000000000009');

  const checkboxRes = filterAndRankPracticals(EXTRACTED_PRACTICALS, {
    query: 'checked and unchecked checkboxes',
  });
  assert.equal(checkboxRes.results[0].id, 'c3000000-0000-4000-8000-000000000009');

  const diffieRes = filterAndRankPracticals(EXTRACTED_PRACTICALS, {
    query: 'Diffie-Hellman key exchange',
  });
  assert.equal(diffieRes.results[0].id, 'd4000000-0000-4000-8000-000000000005');
});

test('common spelling mistakes and typos still find the intended practical', () => {
  const typoBfs = filterAndRankPracticals(EXTRACTED_PRACTICALS, {
    query: 'Bredth First Serch',
  });
  assert.ok(typoBfs.results.length > 0);
  assert.equal(typoBfs.results[0].id, 'a1000000-0000-4000-8000-000000000001');

  const typoKeylogger = filterAndRankPracticals(EXTRACTED_PRACTICALS, {
    query: 'keyloger python',
  });
  assert.ok(typoKeylogger.results.length > 0);
  assert.equal(typoKeylogger.results[0].id, 'b2000000-0000-4000-8000-000000000009');
});

test('subject filter restricts results strictly to the selected subject', () => {
  const stqaOnly = filterAndRankPracticals(EXTRACTED_PRACTICALS, {
    query: '',
    subjectSlug: 'stqa',
  });
  assert.equal(stqaOnly.totalCount, 10);
  assert.ok(stqaOnly.results.every((r) => r.subject_slug === 'stqa'));
});

test('unmatched queries return zero results rather than unrelated practicals', () => {
  const noMatch = filterAndRankPracticals(EXTRACTED_PRACTICALS, {
    query: 'quantum blockchain solidity smart contract compiler xyz999',
  });
  assert.equal(noMatch.totalCount, 0);
  assert.equal(noMatch.results.length, 0);
});

test('unpublished or review_required practicals are never exposed publicly', () => {
  const testRecords = [
    ...EXTRACTED_PRACTICALS,
    {
      ...EXTRACTED_PRACTICALS[0],
      id: 'hidden-unpublished-1',
      title: 'Secret Unpublished Practical',
      original_question: 'Secret Unpublished Practical Question',
      is_published: false,
      review_required: false,
    },
    {
      ...EXTRACTED_PRACTICALS[0],
      id: 'hidden-review-2',
      title: 'Unreviewed Practical',
      original_question: 'Unreviewed Practical Question',
      is_published: true,
      review_required: true,
    },
  ];
  const res = filterAndRankPracticals(testRecords, { query: 'Secret Unpublished' });
  assert.equal(res.totalCount, 0);
  const res2 = filterAndRankPracticals(testRecords, { query: 'Unreviewed Practical' });
  assert.equal(res2.totalCount, 0);
});

test('parsePracticalNumberQuery extracts practical numbers accurately', () => {
  assert.equal(parsePracticalNumberQuery('Practical 5'), 5);
  assert.equal(parsePracticalNumberQuery('prac no 8'), 8);
  assert.equal(parsePracticalNumberQuery('10'), 10);
});

test('code strings preserve exact line breaks and indentation and formatStepsForClipboard works', () => {
  const aiPrac1 = EXTRACTED_PRACTICALS.find(
    (p) => p.id === 'a1000000-0000-4000-8000-000000000001'
  )!;
  assert.ok(aiPrac1.corrected_code?.includes('def BFS(city, cityq, visitedq):\n    global result'));
  const stepsText = formatStepsForClipboard(aiPrac1.algorithm_steps, aiPrac1.procedure_steps);
  assert.ok(stepsText.includes('Algorithm:'));
  assert.ok(stepsText.includes('Procedure:'));
});
