/**
 * Practical Code Finder — One-Click Copy Utility
 *
 * Copies directly from the raw database string held in application state.
 * Preserves line breaks, indentation, tabs, spaces, quotes, and special characters
 * without trimming, normalizing, or reconstructing from rendered HTML.
 * Never reports success before the copy operation actually succeeds.
 */

export async function copyRawTextToClipboard(rawText: string): Promise<boolean> {
  if (typeof rawText !== 'string' || rawText.length === 0) {
    return false;
  }

  // Primary modern Clipboard API
  if (
    typeof navigator !== 'undefined' &&
    navigator.clipboard &&
    typeof navigator.clipboard.writeText === 'function'
  ) {
    try {
      await navigator.clipboard.writeText(rawText);
      return true;
    } catch {
      // Fall through to textarea fallback if Clipboard API is blocked in iframe
    }
  }

  // Fallback mechanism for mobile / restricted iframe contexts
  if (typeof document !== 'undefined') {
    try {
      const textarea = document.createElement('textarea');
      // Assign raw string directly; do NOT trim or normalize
      textarea.value = rawText;
      textarea.setAttribute('readonly', '');
      textarea.style.position = 'fixed';
      textarea.style.top = '-9999px';
      textarea.style.left = '-9999px';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);

      textarea.focus();
      textarea.select();
      textarea.setSelectionRange(0, textarea.value.length);

      const succeeded = document.execCommand('copy');
      document.body.removeChild(textarea);
      return Boolean(succeeded);
    } catch {
      return false;
    }
  }

  return false;
}
