"use client";

import { useMemo, useState } from "react";
import { ArrowDownAZ, Download, Eye, File, Folder, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { formattedFileSize, isFolder, type PreviewFile } from "./types";

type SortOption = "modified-asc" | "modified-desc" | "name-asc" | "name-desc" | "size-desc" | "size-asc" | "type-asc";

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

export function AttachmentList({ files, selectedId, downloadingId, onSelect, onDownload, onBrowse }: { files: PreviewFile[]; selectedId?: string; downloadingId: string | null; onSelect: (file: PreviewFile) => void; onDownload: (file: PreviewFile) => void; onBrowse: (file: PreviewFile) => void }) {
  const [sort, setSort] = useState<SortOption>("modified-asc");
  const [foldersFirst, setFoldersFirst] = useState(true);
  const sortedFiles = useMemo(() => [...files].sort((left, right) => {
    if (foldersFirst && isFolder(left) !== isFolder(right)) return isFolder(left) ? -1 : 1;
    let result = 0;
    if (sort === "name-asc" || sort === "name-desc") result = collator.compare(left.name, right.name) * (sort === "name-desc" ? -1 : 1);
    else if (sort === "modified-asc" || sort === "modified-desc") result = (numericValue(left.modifiedTime ? String(Date.parse(left.modifiedTime)) : null) - numericValue(right.modifiedTime ? String(Date.parse(right.modifiedTime)) : null)) * (sort === "modified-desc" ? -1 : 1);
    else if (sort === "size-asc" || sort === "size-desc") result = (numericValue(left.size) - numericValue(right.size)) * (sort === "size-desc" ? -1 : 1);
    else result = collator.compare(fileType(left), fileType(right));
    return result || collator.compare(left.name, right.name);
  }), [files, foldersFirst, sort]);

  if (!files.length) return <div className="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">This Google Drive folder is currently empty.</div>;
  return <div className="space-y-3">
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border bg-muted/30 p-2.5">
      <div className="flex items-center gap-2 text-sm font-medium"><ArrowDownAZ className="h-4 w-4" />Sort attachments</div>
      <div className="flex flex-wrap items-center gap-3">
        <Select value={sort} onValueChange={(value) => setSort(value as SortOption)}>
          <SelectTrigger size="sm" className="w-[210px]" aria-label="Sort attachments"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="modified-asc">Modified date: Oldest first</SelectItem>
            <SelectItem value="modified-desc">Modified date: Newest first</SelectItem>
            <SelectItem value="name-asc">File name: A–Z</SelectItem>
            <SelectItem value="name-desc">File name: Z–A</SelectItem>
            <SelectItem value="size-desc">File size: Largest first</SelectItem>
            <SelectItem value="size-asc">File size: Smallest first</SelectItem>
            <SelectItem value="type-asc">File type</SelectItem>
          </SelectContent>
        </Select>
        <label className="flex cursor-pointer items-center gap-2 whitespace-nowrap text-sm"><Checkbox checked={foldersFirst} onCheckedChange={(checked) => setFoldersFirst(checked === true)} />Folders first</label>
      </div>
    </div>
    <div className="divide-y overflow-hidden rounded-lg border">{sortedFiles.map((file) => {
      const folder = isFolder(file);
      return <div key={file.id} className={`flex items-center justify-between gap-3 p-3 ${selectedId === file.id ? "bg-muted" : ""}`}>
        <button className="flex min-w-0 flex-1 items-center gap-3 text-left" onClick={() => folder ? onBrowse(file) : onSelect(file)}>
          {folder ? <Folder className="h-5 w-5 shrink-0 text-amber-600" /> : <File className="h-5 w-5 shrink-0 text-muted-foreground" />}
          <span className="min-w-0"><span className="block truncate font-medium">{file.name}</span><span className="block text-xs text-muted-foreground">{fileType(file)}{folder ? "" : ` • ${formattedFileSize(file.size)}`}{file.modifiedTime ? ` • Updated ${new Date(file.modifiedTime).toLocaleString()}` : ""}</span></span>
        </button>
        <div className="flex shrink-0 gap-1">{folder ? <Button variant="outline" size="sm" onClick={() => onBrowse(file)}>Browse</Button> : <><Button variant="outline" size="sm" onClick={() => onSelect(file)}><Eye className="mr-2 h-4 w-4" />Preview</Button><Button variant="ghost" size="sm" onClick={() => onDownload(file)} disabled={downloadingId === file.id} aria-label={`Download ${file.name}`}>{downloadingId === file.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}</Button></>}</div>
      </div>;
    })}</div>
  </div>;
}
