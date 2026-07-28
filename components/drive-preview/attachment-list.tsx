"use client";

import { Download, Eye, File, Folder, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { formattedFileSize, isFolder, type PreviewFile } from "./types";

export function AttachmentList({ files, selectedId, downloadingId, onSelect, onDownload, onBrowse }: { files: PreviewFile[]; selectedId?: string; downloadingId: string | null; onSelect: (file: PreviewFile) => void; onDownload: (file: PreviewFile) => void; onBrowse: (file: PreviewFile) => void }) {
  if (!files.length) return <div className="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">This Google Drive folder is currently empty.</div>;
  return <div className="divide-y overflow-hidden rounded-lg border">{files.map((file) => {
    const folder = isFolder(file);
    return <div key={file.id} className={`flex items-center justify-between gap-3 p-3 ${selectedId === file.id ? "bg-muted" : ""}`}>
      <button className="flex min-w-0 flex-1 items-center gap-3 text-left" onClick={() => folder ? onBrowse(file) : onSelect(file)}>
        {folder ? <Folder className="h-5 w-5 shrink-0 text-amber-600" /> : <File className="h-5 w-5 shrink-0 text-muted-foreground" />}
        <span className="min-w-0"><span className="block truncate font-medium">{file.name}</span><span className="block text-xs text-muted-foreground">{folder ? "Folder" : formattedFileSize(file.size)}{file.modifiedTime ? ` • Updated ${new Date(file.modifiedTime).toLocaleString()}` : ""}</span></span>
      </button>
      <div className="flex shrink-0 gap-1">{folder ? <Button variant="outline" size="sm" onClick={() => onBrowse(file)}>Browse</Button> : <><Button variant="outline" size="sm" onClick={() => onSelect(file)}><Eye className="mr-2 h-4 w-4" />Preview</Button><Button variant="ghost" size="sm" onClick={() => onDownload(file)} disabled={downloadingId === file.id} aria-label={`Download ${file.name}`}>{downloadingId === file.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}</Button></>}</div>
    </div>;
  })}</div>;
}
