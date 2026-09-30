"use client";

import { useState, type FormEvent } from "react";
import { AlertTriangle, Send, FileText, Database } from "lucide-react";
import PdfViewer from "@/components/PdfViewer";

interface Citation {
  pdf: string;
  page: number;
  category?: string;
}

interface Message {
  role: "user" | "assistant";
  content: string;
  sqlExecuted?: string | null;
  citations?: Citation[];
  anomalyFlagged?: boolean;
}

export default function ForensicWorkspacePage() {
  const [messages, setMessages] = useState<Message[]>([
    {
      role: "assistant",
      content:
        "Forensic compliance agent online. Ready to analyze employee financial statements, cash-flow balances, and wealth deltas across filings.",
    },
  ]);
  const [inputQuery, setInputQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [activePdf, setActivePdf] = useState<string | null>("EMP-T27689_2026.pdf");
  const [activePage, setActivePage] = useState<number>(1);

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!inputQuery.trim() || loading) return;

    const userText = inputQuery;
    setInputQuery("");
    setMessages((prev) => [...prev, { role: "user", content: userText }]);
    setLoading(true);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}/api/v1/query`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            prompt: userText,
            user_id: "investigator_jm",
            investigation_case_id: "CASE-2026-JN-01",
          }),
        }
      );

      const data = await response.json();

      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          content: data.answer,
          sqlExecuted: data.sql_executed,
          citations: data.citations,
          anomalyFlagged: data.anomaly_flagged,
        },
      ]);

      if (data.citations && data.citations.length > 0) {
        setActivePdf(data.citations[0].pdf);
        setActivePage(data.citations[0].page);
      }
    } catch {
      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          content: "Network error: Unable to reach forensic backend service.",
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="flex h-screen w-screen bg-slate-950 text-slate-100">
      {/* Top Header */}
      <header className="absolute top-0 left-0 right-0 h-14 border-b border-slate-800 bg-slate-900/80 px-6 flex items-center justify-between z-10 backdrop-blur-md">
        <div className="flex items-center gap-3">
          <div className="h-3 w-3 rounded-full bg-emerald-500 animate-pulse" />
          <h1 className="text-sm font-semibold tracking-wide uppercase text-slate-200">
            Jamaica National Group | Statement of Affairs Forensic Workspace
          </h1>
        </div>
        <div className="text-xs text-slate-400 font-mono">
          Investigator: <span className="text-slate-200">dennish@jngroup.com</span> (Compliance Auth)
        </div>
      </header>

      {/* Main Split-Pane Workspace */}
      <div className="flex w-full h-full pt-14 divide-x divide-slate-800">
        {/* Left Pane: Evidence & Document Inspector */}
        <section className="w-1/2 p-4 flex flex-col gap-3">
          <div className="flex items-center justify-between text-xs text-slate-400 px-1">
            <span className="font-semibold tracking-wider uppercase">Source Document Evidence</span>
            <span>Target: JMD ($) Declarations</span>
          </div>
          <div className="flex-1 min-h-0">
            <PdfViewer filename={activePdf} targetPage={activePage} />
          </div>
        </section>

        {/* Right Pane: AI Investigator Copilot & SQL Audit */}
        <section className="w-1/2 flex flex-col bg-slate-900/50">
          {/* Scrollable Conversation Stream */}
          <div className="flex-1 overflow-y-auto p-6 space-y-4">
            {messages.map((m, idx) => (
              <div
                key={idx}
                className={`flex flex-col ${
                  m.role === "user" ? "items-end" : "items-start"
                }`}
              >
                <div
                  className={`max-w-[85%] rounded-xl p-4 text-sm ${
                    m.role === "user"
                      ? "bg-blue-600 text-white"
                      : "bg-slate-800 border border-slate-700 text-slate-200"
                  }`}
                >
                  {/* Anomaly Badge if flagged */}
                  {m.anomalyFlagged && (
                    <div className="mb-2 flex items-center gap-2 rounded bg-amber-500/20 border border-amber-500/40 px-2.5 py-1 text-xs font-semibold text-amber-300">
                      <AlertTriangle className="h-4 w-4" />
                      Potential Wealth Gap or Conflict Detected
                    </div>
                  )}

                  <p className="whitespace-pre-wrap leading-relaxed">{m.content}</p>

                  {/* Collapsible SQL Inspector */}
                  {m.sqlExecuted && (
                    <details className="mt-3 rounded border border-slate-700 bg-slate-950/60 p-2 text-xs">
                      <summary className="cursor-pointer font-mono text-slate-400 hover:text-slate-200 flex items-center gap-1">
                        <Database className="h-3 w-3" /> View Verified SQL Statement
                      </summary>
                      <pre className="mt-2 overflow-x-auto text-[11px] text-emerald-300 font-mono">
                        {m.sqlExecuted}
                      </pre>
                    </details>
                  )}

                  {/* Interactive Audit Citations */}
                  {m.citations && m.citations.length > 0 && (
                    <div className="mt-3 flex flex-wrap gap-2 pt-2 border-t border-slate-700/60">
                      {m.citations.map((c, i) => (
                        <button
                          key={i}
                          onClick={() => {
                            setActivePdf(c.pdf);
                            setActivePage(c.page);
                          }}
                          className="flex items-center gap-1.5 rounded-full bg-slate-700 hover:bg-emerald-600/30 border border-slate-600 hover:border-emerald-500 px-2.5 py-1 text-[11px] font-mono text-slate-300 transition"
                        >
                          <FileText className="h-3 w-3 text-emerald-400" />
                          {c.pdf} (p. {c.page})
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            ))}

            {loading && (
              <div className="flex items-center gap-2 text-xs text-slate-400">
                <div className="h-4 w-4 animate-spin rounded-full border-2 border-slate-600 border-t-emerald-400" />
                Executing read-only SQL analysis and checking declaration deltas...
              </div>
            )}
          </div>

          {/* Quick Query Actions */}
          <div className="px-6 py-2 border-t border-slate-800 flex gap-2 overflow-x-auto">
            <button
              onClick={() =>
                setInputQuery(
                  "Does employee James Mark (T27689) have any outside business conflicts or high wealth deltas?"
                )
              }
              className="text-xs bg-slate-800 hover:bg-slate-700 text-slate-300 rounded px-2.5 py-1 whitespace-nowrap transition border border-slate-700"
            >
              Analyze James Mark (T27689)
            </button>
            <button
              onClick={() =>
                setInputQuery(
                  "List all real estate holdings where loan balance exceeds 50% of property valuation."
                )
              }
              className="text-xs bg-slate-800 hover:bg-slate-700 text-slate-300 rounded px-2.5 py-1 whitespace-nowrap transition border border-slate-700"
            >
              High-LTV Real Estate Check
            </button>
          </div>

          {/* Input Box */}
          <form
            onSubmit={handleSubmit}
            className="p-4 border-t border-slate-800 bg-slate-900/80 flex gap-2"
          >
            <input
              type="text"
              value={inputQuery}
              onChange={(e) => setInputQuery(e.target.value)}
              placeholder="Ask a forensic question (e.g., 'Compare James Mark net wealth against net income')..."
              className="flex-1 rounded-lg border border-slate-700 bg-slate-950 px-4 py-2.5 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-1 focus:ring-emerald-500"
            />
            <button
              type="submit"
              disabled={loading}
              className="rounded-lg bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-emerald-500 disabled:opacity-50 transition flex items-center gap-1.5"
            >
              <Send className="h-4 w-4" /> Run
            </button>
          </form>
        </section>
      </div>
    </main>
  );
}