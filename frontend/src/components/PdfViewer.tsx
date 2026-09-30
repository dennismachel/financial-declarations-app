"use client";

interface PdfViewerProps {
  filename: string | null;
  targetPage: number;
}

export default function PdfViewer({ filename, targetPage }: PdfViewerProps) {
  if (!filename) {
    return (
      <div className="flex h-full flex-col items-center justify-center border-2 border-dashed border-slate-700 rounded-xl bg-slate-800/40 p-6 text-center text-slate-400">
        <p className="text-sm font-medium">No document active</p>
        <p className="text-xs text-slate-500 mt-1">
          Click an audit citation or select a declaration filing to inspect source PDF evidence.
        </p>
      </div>
    );
  }

  // Points to FastAPI backend static/media route or public PDF endpoint
  const pdfUrl = `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}/pdfs/${filename}#page=${targetPage}`;

  return (
    <div className="flex flex-col h-full rounded-xl overflow-hidden border border-slate-700 bg-slate-800">
      <div className="flex items-center justify-between bg-slate-800/90 px-4 py-2 border-b border-slate-700">
        <span className="text-xs font-mono font-semibold text-emerald-400 truncate">
          📄 {filename}
        </span>
        <span className="rounded bg-slate-700 px-2 py-0.5 text-xs text-slate-300">
          Page {targetPage}
        </span>
      </div>
      <iframe
        key={`${filename}-p${targetPage}`}
        src={pdfUrl}
        className="w-full h-full border-none bg-slate-100"
        title="PDF Document Viewer"
      />
    </div>
  );
}