"use client";

import { Download, Maximize2, RotateCw, Share2, X, ZoomIn, ZoomOut } from "lucide-react";
import { Button } from "@/components/ui/button";
import { formattedFileSize, type PreviewFile } from "./types";

export function PreviewToolbar({ file, zoom, rotation, onZoom, onRotate, onShare, onDownload, onFullscreen, onClose }: { file: PreviewFile; zoom: number; rotation: number; onZoom: (value: number) => void; onRotate: () => void; onShare: () => void; onDownload: () => void; onFullscreen: () => void; onClose: () => void }) {
  return <div className="flex flex-wrap items-center justify-between gap-3 border-b p-3"><div className="min-w-0"><p className="truncate font-semibold">{file.name}</p><p className="text-xs text-muted-foreground">{file.mimeType || "Unknown MIME type"} • {formattedFileSize(file.size)}</p></div><div className="flex flex-wrap gap-1"><Button variant="ghost" size="sm" onClick={() => onZoom(Math.max(.25, zoom - .25))} aria-label="Zoom out"><ZoomOut className="h-4 w-4" /></Button><Button variant="ghost" size="sm" onClick={() => onZoom(Math.min(3, zoom + .25))} aria-label="Zoom in"><ZoomIn className="h-4 w-4" /></Button><Button variant="ghost" size="sm" onClick={onRotate} aria-label={`Rotate preview from ${rotation} degrees`}><RotateCw className="h-4 w-4" /></Button><Button variant="ghost" size="sm" onClick={onShare}><Share2 className="mr-2 h-4 w-4" />Share</Button><Button variant="ghost" size="sm" onClick={onDownload}><Download className="mr-2 h-4 w-4" />Download</Button><Button variant="ghost" size="sm" onClick={onFullscreen} aria-label="Fullscreen"><Maximize2 className="h-4 w-4" /></Button><Button variant="ghost" size="sm" onClick={onClose} aria-label="Close preview"><X className="h-4 w-4" /></Button></div></div>;
}
