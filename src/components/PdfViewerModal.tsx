import React from 'react';
import { X, FileText, ExternalLink, Download } from 'lucide-react';

export interface PdfViewerState {
  title: string;
  subtitle?: string;
  pdfFilename: string;
  page?: number | null;
}

interface PdfViewerModalProps {
  pdfState: PdfViewerState | null;
  onClose: () => void;
}

export const PdfViewerModal: React.FC<PdfViewerModalProps> = ({ pdfState, onClose }) => {
  if (!pdfState) return null;

  const baseUrl = `/assets/aistudio/${pdfState.pdfFilename}`;
  const viewerUrl =
    pdfState.page && pdfState.page > 0 ? `${baseUrl}#page=${pdfState.page}` : baseUrl;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/70 p-2 sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-label={`Original PDF Viewer: ${pdfState.title}`}
      onClick={onClose}
    >
      <div
        className="bg-white border border-slate-200 rounded-lg w-full max-w-5xl h-[90vh] flex flex-col overflow-hidden shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Modal Header */}
        <div className="px-4 sm:px-6 py-3.5 border-b border-slate-200 flex flex-wrap items-center justify-between gap-3 bg-slate-50">
          <div className="flex items-center gap-2.5 min-w-0">
            <FileText className="w-5 h-5 text-blue-700 shrink-0" />
            <div className="truncate">
              <h2 className="text-sm sm:text-base font-bold text-slate-900 truncate">
                {pdfState.title}
              </h2>
              {pdfState.subtitle && (
                <p className="text-xs text-slate-600 truncate m-0 font-mono tabular-nums">
                  {pdfState.subtitle}
                </p>
              )}
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <a
              href={viewerUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-white border border-slate-300 hover:bg-slate-100 text-slate-700 rounded-md transition-colors whitespace-nowrap"
            >
              <ExternalLink className="w-3.5 h-3.5" />
              <span>Open in New Tab</span>
            </a>

            <a
              href={baseUrl}
              download={pdfState.pdfFilename}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-blue-700 hover:bg-blue-800 text-white rounded-md transition-colors whitespace-nowrap"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Download PDF</span>
            </a>

            <button
              type="button"
              onClick={onClose}
              aria-label="Close PDF viewer"
              className="p-1.5 text-slate-500 hover:text-slate-900 hover:bg-slate-200 rounded-md transition-colors cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Embedded PDF Frame */}
        <div className="flex-1 bg-slate-800 relative">
          <iframe
            key={viewerUrl}
            src={viewerUrl}
            title={pdfState.title}
            className="w-full h-full border-0"
          />
        </div>
      </div>
    </div>
  );
};
