"use client";

import { useMemo } from "react";
import { Download, Eye, File, Folder, FolderInput, Loader2, Pencil, Share2, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { formattedFileSize, isFolder, type PreviewFile } from "./types";

export type AttachmentSortOption = "modified-asc" | "modified-desc" | "name-asc" | "name-desc" | "size-desc" | "size-asc" | "type-asc";

const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" });

function fileType(file: PreviewFile) {
  if (isFolder(file)) return "Folder";
  const extension = file.name.match(/\.([^.]+)$/)?.[1]?.toUpperCase();
  if (extension) return extension;
  return file.mimeType?.split("/").pop()?.toUpperCase() || "FILE";
}

function numericValue(value: string | null) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

export function AttachmentList({ files, sort, selectedId, downloadingId, managingFolderId, managingFileId, canShare, onSelect, onDownload, onShare, onRenameFile, onMoveFile, onTrashFile, onBrowse, onRenameFolder, onTrashFolder }: { files: PreviewFile[]; sort: AttachmentSortOption; selectedId?: string; downloadingId: string | null; managingFolderId?: string | null; managingFileId?: string | null; canShare?: boolean; onSelect: (file: PreviewFile) => void; onDownload: (file: PreviewFile) => void; onShare: (file: PreviewFile) => void; onRenameFile: (file: PreviewFile) => void; onMoveFile: (file: PreviewFile) => void; onTrashFile: (file: PreviewFile) => void; onBrowse: (file: PreviewFile) => void; onRenameFolder: (file: PreviewFile) => void; onTrashFolder: (file: PreviewFile) => void }) {
  const sortedFiles = useMemo(() => [...files].sort((left, right) => {
    let result = 0;
    if (sort === "name-asc" || sort === "name-desc") result = collator.compare(left.name, right.name) * (sort === "name-desc" ? -1 : 1);
    else if (sort === "modified-asc" || sort === "modified-desc") result = (numericValue(left.modifiedTime ? String(Date.parse(left.modifiedTime)) : null) - numericValue(right.modifiedTime ? String(Date.parse(right.modifiedTime)) : null)) * (sort === "modified-desc" ? -1 : 1);
    else if (sort === "size-asc" || sort === "size-desc") result = (numericValue(left.size) - numericValue(right.size)) * (sort === "size-desc" ? -1 : 1);
    else result = collator.compare(fileType(left), fileType(right));
    return result || collator.compare(left.name, right.name);
  }), [files, sort]);

  if (!files.length) return <div className="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">This Google Drive folder is currently empty.</div>;
  return <div className="divide-y overflow-hidden rounded-lg border">{sortedFiles.map((file) => {
      const folder = isFolder(file);
      return <div key={file.id} className={`flex items-center justify-between gap-3 p-3 ${selectedId === file.id ? "bg-muted" : ""}`}>
        <button className="flex min-w-0 flex-1 items-center gap-3 text-left" onClick={() => folder ? onBrowse(file) : onSelect(file)}>
          {folder ? <Folder className="h-5 w-5 shrink-0 text-amber-600" /> : <File className="h-5 w-5 shrink-0 text-muted-foreground" />}
          <span className="min-w-0"><span className="block truncate font-medium">{file.name}</span><span className="block text-xs text-muted-foreground">{fileType(file)}{folder ? "" : ` • ${formattedFileSize(file.size)}`}{file.modifiedTime ? ` • Updated ${new Date(file.modifiedTime).toLocaleString()}` : ""}</span></span>
        </button>
        <div className="flex shrink-0 gap-1">{folder ? <><Button variant="outline" size="sm" onClick={() => onBrowse(file)} disabled={managingFolderId === file.id}>Browse</Button><Button variant="ghost" size="icon" onClick={() => onRenameFolder(file)} disabled={managingFolderId === file.id} aria-label={`Rename ${file.name}`}>{managingFolderId === file.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Pencil className="h-4 w-4" />}</Button><Button variant="ghost" size="icon" className="text-destructive hover:text-destructive" onClick={() => onTrashFolder(file)} disabled={managingFolderId === file.id} aria-label={`Trash ${file.name}`}><Trash2 className="h-4 w-4" /></Button></> : <><Button variant="outline" size="sm" onClick={() => onSelect(file)} disabled={managingFileId === file.id}><Eye className="mr-2 h-4 w-4" />Preview</Button>{canShare ? <Button variant="ghost" size="icon" onClick={() => onShare(file)} disabled={managingFileId === file.id} aria-label={`Share ${file.name}`}><Share2 className="h-4 w-4" /></Button> : null}<Button variant="ghost" size="icon" onClick={() => onDownload(file)} disabled={downloadingId === file.id || managingFileId === file.id} aria-label={`Download ${file.name}`}>{downloadingId === file.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}</Button><Button variant="ghost" size="icon" onClick={() => onRenameFile(file)} disabled={managingFileId === file.id} aria-label={`Rename ${file.name}`}>{managingFileId === file.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Pencil className="h-4 w-4" />}</Button><Button variant="ghost" size="icon" onClick={() => onMoveFile(file)} disabled={managingFileId === file.id} aria-label={`Move ${file.name}`}><FolderInput className="h-4 w-4" /></Button><Button variant="ghost" size="icon" className="text-destructive hover:text-destructive" onClick={() => onTrashFile(file)} disabled={managingFileId === file.id} aria-label={`Trash ${file.name}`}><Trash2 className="h-4 w-4" /></Button></>}</div>
      </div>;
    })}</div>;
}
