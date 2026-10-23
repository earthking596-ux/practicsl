import React, { useState, useEffect } from 'react';
import {
  Copy,
  Check,
  ChevronDown,
  ChevronUp,
  Terminal,
  ListChecks,
  Code2,
  AlertCircle,
  FileText,
} from 'lucide-react';
import { RankedPractical, formatStepsForClipboard } from '../utils/searchEngine';
import { copyRawTextToClipboard } from '../utils/clipboard';
import { PdfViewerState } from './PdfViewerModal';

interface PracticalCardProps {
  practical: RankedPractical;
  defaultExpanded?: boolean;
  onOpenPdf?: (pdfState: PdfViewerState) => void;
}

const SUBJECT_PDF_FALLBACK: Record<string, string> = {
  'artificial-intelligence': 'final_AI__3f2816a9.pdf',
  'ethical-hacking': 'final_ethical_hacking_607197eb.pdf',
  stqa: 'final_STQA_b89bf2f3.pdf',
  'cryptography-and-network-security': 'finalCNS_69f47646.pdf',
};

export const PracticalCard: React.FC<PracticalCardProps> = ({
  practical,
  defaultExpanded = false,
  onOpenPdf,
}) => {
  const [expanded, setExpanded] = useState<boolean>(defaultExpanded);
  const [copyCodeState, setCopyCodeState] = useState<'idle' | 'copied' | 'error'>('idle');
  const [copyStepsState, setCopyStepsState] = useState<'idle' | 'copied' | 'error'>('idle');

  useEffect(() => {
    setExpanded(defaultExpanded);
  }, [defaultExpanded]);

  const hasCode = Boolean(practical.corrected_code && practical.corrected_code.length > 0);
  const hasAlgorithm = Boolean(
    practical.algorithm_steps && practical.algorithm_steps.length > 0
  );
  const hasProcedure = Boolean(
    practical.procedure_steps && practical.procedure_steps.length > 0
  );
  const hasSteps = hasAlgorithm || hasProcedure;
  const hasOutput = Boolean(
    practical.expected_output && practical.expected_output.trim().length > 0
  );

  const pdfFilename =
    practical.source_pdf || SUBJECT_PDF_FALLBACK[practical.subject_slug] || '';
  const startPage =
    practical.source_pages && practical.source_pages.length > 0
      ? practical.source_pages[0]
      : null;
  const pagesLabel =
    practical.source_pages && practical.source_pages.length > 0
      ? practical.source_pages.length === 1
        ? `Page ${practical.source_pages[0]}`
        : `Pages ${practical.source_pages[0]}–${
            practical.source_pages[practical.source_pages.length - 1]
          }`
      : null;

  const instructionsList: string[] = Array.isArray(practical.instructions)
    ? practical.instructions
    : practical.instructions
    ? [String(practical.instructions)]
    : [];

  const handleCopyCode = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (!practical.corrected_code) return;
    const success = await copyRawTextToClipboard(practical.corrected_code);
    if (success) {
      setCopyCodeState('copied');
      setTimeout(() => setCopyCodeState('idle'), 2200);
    } else {
      setCopyCodeState('error');
      setTimeout(() => setCopyCodeState('idle'), 2800);
    }
  };

  const handleCopySteps = async (e: React.MouseEvent) => {
    e.stopPropagation();
    const stepsString = formatStepsForClipboard(
      practical.algorithm_steps,
      practical.procedure_steps
    );
    if (!stepsString) return;
    const success = await copyRawTextToClipboard(stepsString);
    if (success) {
      setCopyStepsState('copied');
      setTimeout(() => setCopyStepsState('idle'), 2200);
    } else {
      setCopyStepsState('error');
      setTimeout(() => setCopyStepsState('idle'), 2800);
    }
  };

  const handleViewPdf = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (!pdfFilename || !onOpenPdf) return;
    onOpenPdf({
      title: `${practical.subject_name} — Practical No. ${practical.practical_number ?? ''}`,
      subtitle: pagesLabel ? `${practical.title} (${pagesLabel})` : practical.title,
      pdfFilename,
      page: startPage,
    });
  };

  // Generate a short solution preview (first 4 lines of code or first 2 procedure steps)
  const codePreviewLines = practical.corrected_code
    ? practical.corrected_code.split('\n').slice(0, 4).join('\n')
    : null;

  const stepsPreview =
    !codePreviewLines && hasProcedure && practical.procedure_steps
      ? practical.procedure_steps.slice(0, 2)
      : null;

  return (
    <article
      className="bg-white border border-slate-200 rounded-lg transition-colors hover:border-slate-300"
      data-testid={`practical-card-${practical.id}`}
    >
      {/* Summary Header */}
      <div className="p-5 sm:p-6">
        {/* Clean Unboxed Metadata Line */}
        <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-slate-600 mb-2 font-mono tabular-nums">
          <span className="font-semibold text-blue-800">{practical.subject_name}</span>
          {practical.practical_number !== null && (
            <>
              <span aria-hidden="true">·</span>
              <span className="font-medium text-slate-800">
                Practical No. {practical.practical_number}
              </span>
            </>
          )}
          {practical.programming_language && (
            <>
              <span aria-hidden="true">·</span>
              <span>{practical.programming_language}</span>
            </>
          )}
          {pagesLabel && (
            <>
              <span aria-hidden="true">·</span>
              <span className="text-slate-500">{pagesLabel}</span>
            </>
          )}
        </div>

        {/* Practical Question */}
        <h3 className="text-lg sm:text-xl font-semibold text-slate-900 leading-snug mb-1.5">
          {practical.original_question}
        </h3>

        {/* Descriptive Program Title if distinct from Question */}
        {practical.title &&
          practical.title.toLowerCase() !== practical.original_question.toLowerCase() && (
            <p className="text-sm text-slate-600 mb-4">{practical.title}</p>
          )}

        {/* Short Solution Preview when collapsed */}
        {!expanded && (
          <div className="mt-3 space-y-3">
            {codePreviewLines && (
              <div className="bg-slate-900 text-slate-100 rounded-md px-4 py-3 text-xs font-mono overflow-x-auto">
                <pre className="m-0 whitespace-pre leading-relaxed">{codePreviewLines}</pre>
                {practical.corrected_code &&
                  practical.corrected_code.split('\n').length > 4 && (
                    <div className="text-slate-400 mt-1 text-[11px]">
                      … ({practical.corrected_code.split('\n').length} lines total)
                    </div>
                  )}
              </div>
            )}

            {stepsPreview && (
              <div className="bg-slate-50 border border-slate-200 rounded-md px-4 py-3 text-xs text-slate-700 space-y-1">
                {stepsPreview.map((step, i) => (
                  <div key={i} className="truncate">
                    {step}
                  </div>
                ))}
                {practical.procedure_steps && practical.procedure_steps.length > 2 && (
                  <div className="text-slate-500 text-[11px] font-mono tabular-nums">
                    + {practical.procedure_steps.length - 2} more steps
                  </div>
                )}
              </div>
            )}

            {hasOutput && practical.expected_output && (
              <div className="text-xs text-slate-600 bg-slate-50 border border-slate-200 rounded-md px-3.5 py-2.5 font-mono overflow-x-auto">
                <span className="font-semibold text-slate-700">Expected Output: </span>
                <span className="text-slate-700">
                  {practical.expected_output.split('\n')[0]}
                  {practical.expected_output.split('\n').length > 1 ? ' …' : ''}
                </span>
              </div>
            )}
          </div>
        )}

        {/* Action Bar: One-Click Copy, View Original PDF & Expand Details */}
        <div className="mt-4 pt-3 border-t border-slate-100 flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-2.5">
            {hasCode && (
              <button
                type="button"
                onClick={handleCopyCode}
                aria-label={`Copy code for Practical ${practical.practical_number ?? ''} ${practical.title}`}
                className={`inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-medium rounded-md transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                  copyCodeState === 'copied'
                    ? 'bg-emerald-700 text-white'
                    : copyCodeState === 'error'
                    ? 'bg-red-700 text-white'
                    : 'bg-blue-700 text-white hover:bg-blue-800'
                }`}
              >
                {copyCodeState === 'copied' ? (
                  <>
                    <Check className="w-3.5 h-3.5" />
                    <span>Copied Code!</span>
                  </>
                ) : copyCodeState === 'error' ? (
                  <>
                    <AlertCircle className="w-3.5 h-3.5" />
                    <span>Copy Failed</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5" />
                    <span>Copy Code</span>
                  </>
                )}
              </button>
            )}

            {hasSteps && (
              <button
                type="button"
                onClick={handleCopySteps}
                aria-label={`Copy steps for Practical ${practical.practical_number ?? ''} ${practical.title}`}
                className={`inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-medium rounded-md border transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                  copyStepsState === 'copied'
                    ? 'bg-emerald-50 border-emerald-600 text-emerald-800'
                    : copyStepsState === 'error'
                    ? 'bg-red-50 border-red-600 text-red-800'
                    : 'bg-white border-slate-300 text-slate-700 hover:bg-slate-50 hover:text-slate-900'
                }`}
              >
                {copyStepsState === 'copied' ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-emerald-700" />
                    <span>Copied Steps!</span>
                  </>
                ) : copyStepsState === 'error' ? (
                  <>
                    <AlertCircle className="w-3.5 h-3.5 text-red-700" />
                    <span>Copy Failed</span>
                  </>
                ) : (
                  <>
                    <ListChecks className="w-3.5 h-3.5 text-slate-600" />
                    <span>Copy Steps</span>
                  </>
                )}
              </button>
            )}

            {pdfFilename && onOpenPdf && (
              <button
                type="button"
                onClick={handleViewPdf}
                aria-label={`View original PDF for Practical ${practical.practical_number ?? ''} ${practical.title}`}
                className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-medium rounded-md border border-slate-300 bg-white text-slate-700 hover:bg-slate-50 hover:text-blue-800 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
              >
                <FileText className="w-3.5 h-3.5 text-blue-700" />
                <span>View Original PDF{startPage ? ` (p. ${startPage})` : ''}</span>
              </button>
            )}
          </div>

          <button
            type="button"
            onClick={() => setExpanded((prev) => !prev)}
            aria-expanded={expanded}
            aria-label={
              expanded
                ? `Hide full solution for Practical ${practical.practical_number ?? ''} ${practical.title}`
                : `View full solution for Practical ${practical.practical_number ?? ''} ${practical.title}`
            }
            className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-medium text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-md transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            <span>{expanded ? 'Hide Full Solution' : 'View Full Solution'}</span>
            {expanded ? (
              <ChevronUp className="w-4 h-4" />
            ) : (
              <ChevronDown className="w-4 h-4" />
            )}
          </button>
        </div>
      </div>

      {/* Expanded Practical View */}
      {expanded && (
        <div className="border-t border-slate-200 bg-slate-50/60 p-5 sm:p-6 space-y-6">
          {/* 1. Question */}
          <div>
            <h4 className="text-xs font-semibold text-slate-500 mb-1.5">
              Question
            </h4>
            <p className="text-sm text-slate-900 bg-white border border-slate-200 rounded-md p-3.5 font-medium">
              {practical.original_question}
            </p>
          </div>

          {/* 2. Program Code (when available) */}
          {hasCode && practical.corrected_code && (
            <div>
              <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
                <div className="flex items-center gap-2">
                  <Code2 className="w-4 h-4 text-blue-700" />
                  <h4 className="text-xs font-semibold text-slate-700">
                    Program ({practical.programming_language || 'Code'})
                  </h4>
                  <span className="text-xs text-slate-500 font-mono tabular-nums">
                    · {practical.corrected_code.split('\n').length} lines
                  </span>
                </div>

                <button
                  type="button"
                  onClick={handleCopyCode}
                  className={`inline-flex items-center gap-1.5 px-3 py-1 text-xs font-medium rounded transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                    copyCodeState === 'copied'
                      ? 'bg-emerald-700 text-white'
                      : 'bg-blue-700 text-white hover:bg-blue-800'
                  }`}
                >
                  {copyCodeState === 'copied' ? (
                    <>
                      <Check className="w-3.5 h-3.5" />
                      <span>Copied Code!</span>
                    </>
                  ) : (
                    <>
                      <Copy className="w-3.5 h-3.5" />
                      <span>Copy Code</span>
                    </>
                  )}
                </button>
              </div>

              <div className="bg-slate-900 text-slate-100 rounded-md border border-slate-800 overflow-x-auto">
                <pre
                  className="p-4 m-0 text-xs sm:text-[13px] font-mono leading-relaxed whitespace-pre overflow-x-auto"
                  data-testid={`code-block-${practical.id}`}
                >
                  <code>{practical.corrected_code}</code>
                </pre>
              </div>
            </div>
          )}

          {/* 3. Expected Output (when available) */}
          {hasOutput && practical.expected_output && (
            <div>
              <div className="flex items-center gap-2 mb-2">
                <Terminal className="w-4 h-4 text-emerald-700" />
                <h4 className="text-xs font-semibold text-slate-700">Expected Output</h4>
              </div>
              <div className="bg-slate-900 text-emerald-300 rounded-md border border-slate-800 p-4 overflow-x-auto">
                <pre className="m-0 text-xs font-mono leading-relaxed whitespace-pre">
                  {practical.expected_output}
                </pre>
              </div>
            </div>
          )}

          {/* 4. Algorithm Steps (when available) */}
          {hasAlgorithm && practical.algorithm_steps && (
            <div>
              <div className="flex items-center justify-between gap-2 mb-2">
                <h4 className="text-xs font-semibold text-slate-700">Algorithm</h4>
                {!hasProcedure && (
                  <button
                    type="button"
                    onClick={handleCopySteps}
                    className="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium bg-white border border-slate-300 text-slate-700 rounded hover:bg-slate-100 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                  >
                    {copyStepsState === 'copied' ? (
                      <>
                        <Check className="w-3.5 h-3.5 text-emerald-700" />
                        <span>Copied Steps!</span>
                      </>
                    ) : (
                      <>
                        <ListChecks className="w-3.5 h-3.5" />
                        <span>Copy Steps</span>
                      </>
                    )}
                  </button>
                )}
              </div>
              <ol className="list-decimal list-inside bg-white border border-slate-200 rounded-md p-4 space-y-2 text-sm text-slate-800">
                {practical.algorithm_steps.map((step, idx) => (
                  <li key={idx} className="leading-relaxed">
                    {step}
                  </li>
                ))}
              </ol>
            </div>
          )}

          {/* 5. Procedure Steps (when available) */}
          {hasProcedure && practical.procedure_steps && (
            <div>
              <div className="flex items-center justify-between gap-2 mb-2">
                <h4 className="text-xs font-semibold text-slate-700">
                  Procedure ({practical.procedure_steps.length} steps)
                </h4>
                <button
                  type="button"
                  onClick={handleCopySteps}
                  className="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium bg-white border border-slate-300 text-slate-700 rounded hover:bg-slate-100 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                >
                  {copyStepsState === 'copied' ? (
                    <>
                      <Check className="w-3.5 h-3.5 text-emerald-700" />
                      <span>Copied Steps!</span>
                    </>
                  ) : (
                    <>
                      <ListChecks className="w-3.5 h-3.5" />
                      <span>Copy Steps</span>
                    </>
                  )}
                </button>
              </div>
              <div className="bg-white border border-slate-200 rounded-md p-4 space-y-2 text-sm text-slate-800">
                {practical.procedure_steps.map((step, idx) => {
                  const isSectionHeader = /^PART\s+\d+/i.test(step);
                  return isSectionHeader ? (
                    <div
                      key={idx}
                      className="pt-2 first:pt-0 font-semibold text-blue-900 text-xs tracking-wide border-b border-slate-100 pb-1"
                    >
                      {step}
                    </div>
                  ) : (
                    <div key={idx} className="leading-relaxed pl-1">
                      {step}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* 6. Important Instructions & Dependencies (when available) */}
          {instructionsList.length > 0 && (
            <div>
              <h4 className="text-xs font-semibold text-slate-700 mb-2">
                Instructions & Dependencies
              </h4>
              <div className="bg-white border border-slate-200 rounded-md p-4 space-y-3 text-xs sm:text-sm text-slate-700">
                {instructionsList.map((inst, idx) => {
                  const isCodeModule =
                    inst.includes('dict_hn =') ||
                    inst.includes('rwp_examples =') ||
                    inst.includes('<!DOCTYPE html>');
                  return isCodeModule ? (
                    <div key={idx} className="space-y-1.5">
                      <div className="text-xs font-semibold text-slate-600">
                        Included Shared Dependency / Auxiliary File:
                      </div>
                      <pre className="bg-slate-900 text-slate-100 p-3.5 rounded text-xs font-mono overflow-x-auto whitespace-pre">
                        {inst}
                      </pre>
                    </div>
                  ) : (
                    <p key={idx} className="leading-relaxed m-0">
                      {inst}
                    </p>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}
    </article>
  );
};
