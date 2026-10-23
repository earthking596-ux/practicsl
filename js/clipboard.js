/**
 * Practical Code Finder — Clipboard Module (js/clipboard.js)
 * Copies exact raw code or ordered steps strings from application state
 * without trimming, re-indenting, or reading from innerHTML/textContent.
 */

export async function copyToClipboardExact(rawString) {
  if (typeof rawString !== 'string' || rawString.length === 0) {
    return { ok: false, error: 'Nothing to copy.' };
  }

  if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
    try {
      await navigator.clipboard.writeText(rawString);
      return { ok: true, error: null };
    } catch (_err) {
      // Fallback to hidden textarea copy
    }
  }

  try {
    const textarea = document.createElement('textarea');
    textarea.value = rawString;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.top = '-9999px';
    textarea.style.left = '-9999px';
    document.body.appendChild(textarea);
    textarea.focus();
    textarea.select();
    textarea.setSelectionRange(0, textarea.value.length);
    const ok = document.execCommand('copy');
    document.body.removeChild(textarea);
    return { ok: Boolean(ok), error: ok ? null : 'Browser blocked clipboard access.' };
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : 'Clipboard operation failed.',
    };
  }
}

export function formatStepsText(algorithmSteps = [], procedureSteps = []) {
  const parts = [];
  if (Array.isArray(algorithmSteps) && algorithmSteps.length > 0) {
    const lines = algorithmSteps.map((s, i) =>
      /^(step\s*\d+|part\s*\d+|\d+[.)])/i.test(String(s).trim()) ? String(s).trim() : `${i + 1}. ${String(s).trim()}`
    );
    parts.push(procedureSteps?.length ? `Algorithm:\n${lines.join('\n')}` : lines.join('\n'));
  }
  if (Array.isArray(procedureSteps) && procedureSteps.length > 0) {
    const lines = procedureSteps.map((s, i) =>
      /^(step\s*\d+|part\s*\d+|\d+[.)])/i.test(String(s).trim()) ? String(s).trim() : `Step ${i + 1}: ${String(s).trim()}`
    );
    parts.push(algorithmSteps?.length ? `Procedure:\n${lines.join('\n')}` : lines.join('\n'));
  }
  return parts.join('\n\n');
}
