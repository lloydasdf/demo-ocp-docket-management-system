"use client";

import { useEffect, useRef, useState } from "react";
import { FileText, Loader2 } from "lucide-react";
import { renderAsync } from "docx-preview";
import { Button } from "@/components/ui/button";

export function DocxPreview({ blob, onDownload }: { blob: Blob; onDownload: () => void }) {
  const viewportRef = useRef<HTMLDivElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [status, setStatus] = useState<"loading" | "ready" | "failed">("loading");
  const [dimensions, setDimensions] = useState({ scale: 1, width: 0, height: 0 });

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

  useEffect(() => {
    if (status !== "ready") return;
    const viewport = viewportRef.current; const content = containerRef.current;
    if (!viewport || !content) return;
    const fit = () => {
      const naturalWidth = content.scrollWidth; const naturalHeight = content.scrollHeight;
      if (!naturalWidth || !naturalHeight) return;
      const scale = Math.min(1, viewport.clientWidth / naturalWidth);
      setDimensions({ scale, width: naturalWidth * scale, height: naturalHeight * scale });
    };
    fit();
    const observer = new ResizeObserver(fit); observer.observe(viewport); observer.observe(content);
    window.addEventListener("orientationchange", fit);
    return () => { observer.disconnect(); window.removeEventListener("orientationchange", fit); };
  }, [status]);

  return <div ref={viewportRef} className="relative h-full min-h-[65vh] w-full overflow-x-hidden overflow-y-auto bg-slate-200 p-4">
    {status === "loading" ? <div className="absolute inset-0 z-10 flex items-center justify-center bg-background/80"><Loader2 className="mr-2 h-5 w-5 animate-spin" />Rendering Word document…</div> : null}
    {status === "failed" ? <div className="absolute inset-0 z-10 flex items-center justify-center bg-background p-6"><div className="max-w-md text-center"><FileText className="mx-auto mb-3 h-12 w-12 text-muted-foreground" /><p className="font-medium">Word preview could not be rendered</p><p className="mt-1 text-sm text-muted-foreground">Download the original document to view it locally.</p><Button className="mt-4" onClick={onDownload}>Download</Button></div></div> : null}
    <div className="relative mx-auto" style={{ width: dimensions.width || "100%", height: dimensions.height || "auto" }}><div ref={containerRef} style={{ position: dimensions.width ? "absolute" : "relative", left: 0, top: 0, transform: `scale(${dimensions.scale})`, transformOrigin: "top left" }} className="docx-preview-container [&_.docx-wrapper]:!bg-transparent [&_section.docx]:!shadow-lg" /></div>
  </div>;
}
