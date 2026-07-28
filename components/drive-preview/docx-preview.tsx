"use client";

import { useEffect, useRef, useState } from "react";
import { FileText, Loader2 } from "lucide-react";
import { renderAsync } from "docx-preview";
import { Button } from "@/components/ui/button";

export function DocxPreview({ blob, onDownload }: { blob: Blob; onDownload: () => void }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [status, setStatus] = useState<"loading" | "ready" | "failed">("loading");

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    let active = true;
    container.replaceChildren();
    setStatus("loading");
    void renderAsync(blob, container, container, {
      breakPages: true,
      ignoreFonts: false,
      ignoreHeight: false,
      ignoreWidth: false,
      renderFooters: true,
      renderHeaders: true,
      renderEndnotes: true,
      renderFootnotes: true,
      useBase64URL: true,
    }).then(() => { if (active) setStatus("ready"); }).catch(() => { if (active) setStatus("failed"); });
    return () => { active = false; container.replaceChildren(); };
  }, [blob]);

  return <div className="relative h-full min-h-[65vh] w-full overflow-auto bg-slate-200 p-4">
    {status === "loading" ? <div className="absolute inset-0 z-10 flex items-center justify-center bg-background/80"><Loader2 className="mr-2 h-5 w-5 animate-spin" />Rendering Word document…</div> : null}
    {status === "failed" ? <div className="absolute inset-0 z-10 flex items-center justify-center bg-background p-6"><div className="max-w-md text-center"><FileText className="mx-auto mb-3 h-12 w-12 text-muted-foreground" /><p className="font-medium">Word preview could not be rendered</p><p className="mt-1 text-sm text-muted-foreground">Download the original document to view it locally.</p><Button className="mt-4" onClick={onDownload}>Download</Button></div></div> : null}
    <div ref={containerRef} className="docx-preview-container mx-auto [&_.docx-wrapper]:!bg-transparent [&_section.docx]:!shadow-lg" />
  </div>;
}
