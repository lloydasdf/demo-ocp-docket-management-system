"use client";

import { useRef, useState } from "react";
import { Loader2 } from "lucide-react";
import { FilePreview } from "./file-preview";
import { PreviewToolbar } from "./preview-toolbar";
import type { PreviewFile } from "./types";

export function AttachmentPreviewPane({ file, blob, url, loading, onShare, onDownload, onClose }: { file: PreviewFile; blob: Blob | null; url: string | null; loading: boolean; onShare: () => void; onDownload: () => void; onClose: () => void }) {
  const [zoom, setZoom] = useState(1); const [rotation, setRotation] = useState(0); const paneRef = useRef<HTMLDivElement>(null);
  return <section ref={paneRef} className="flex h-full min-h-[72vh] flex-col overflow-hidden rounded-lg border bg-background shadow-xl"><PreviewToolbar file={file} zoom={zoom} rotation={rotation} onZoom={setZoom} onRotate={() => setRotation((value) => (value + 90) % 360)} onShare={onShare} onDownload={onDownload} onFullscreen={() => void paneRef.current?.requestFullscreen()} onClose={onClose} /><div className="flex flex-1 items-center justify-center overflow-auto bg-muted/40 p-3">{loading || !blob || !url ? <div className="flex items-center gap-2 text-muted-foreground"><Loader2 className="h-5 w-5 animate-spin" />Loading preview…</div> : <div style={{ transform: `scale(${zoom}) rotate(${rotation}deg)`, transformOrigin: "center" }} className="flex h-full w-full items-center justify-center transition-transform"><FilePreview file={file} blob={blob} url={url} /></div>}</div></section>;
}
