import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  title: "JN Group | Confidential Financial Declarations Copilot",
  description: "Forensic analysis and investigation interface for employee disclosures.",
};

export default function RootLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <html lang="en">
      <body className="h-screen w-screen overflow-hidden antialiased bg-slate-900 text-slate-100">
        {children}
      </body>
    </html>
  );
}