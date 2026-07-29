"use client";

import { AlertCircle, CheckCircle2, Loader2, RotateCcw, X } from "lucide-react";
import { Button } from "@/components/ui/button";

export type UploadItem = { id: string; file: File; destinationId: string; progress: number; status: "queued" | "uploading" | "complete" | "failed" | "cancelled"; error?: string };

export function DriveUploadManager({ uploads, onCancel, onRetry }: { uploads: UploadItem[]; onCancel: (id: string) => void; onRetry: (id: string) => void }) {
  if (!uploads.length) return null;
  return <div className="space-y-2 rounded-lg border p-3" aria-live="polite">{uploads.map((item) => <div key={item.id} className="space-y-1.5">
      <div className="flex items-center gap-2 text-sm">
        {item.status === "complete" ? <CheckCircle2 className="h-4 w-4 shrink-0 text-green-600" /> : item.status === "failed" || item.status === "cancelled" ? <AlertCircle className="h-4 w-4 shrink-0 text-destructive" /> : <Loader2 className={`h-4 w-4 shrink-0 ${item.status === "uploading" ? "animate-spin" : ""}`} />}
        <span className="min-w-0 flex-1 truncate" title={item.file.name}>{item.file.name}</span>
        <span className="text-xs tabular-nums text-muted-foreground">{item.status === "complete" ? "Uploaded" : item.status === "cancelled" ? "Cancelled" : `${item.progress}%`}</span>
        {item.status === "queued" || item.status === "uploading" ? <Button type="button" size="icon" variant="ghost" className="h-7 w-7" onClick={() => onCancel(item.id)} aria-label={`Cancel ${item.file.name}`}><X className="h-4 w-4" /></Button> : null}
        {item.status === "failed" || item.status === "cancelled" ? <Button type="button" size="sm" variant="outline" onClick={() => onRetry(item.id)}><RotateCcw className="mr-1 h-3.5 w-3.5" />Retry</Button> : null}
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-muted"><div className={`h-full transition-[width] duration-150 ${item.status === "failed" || item.status === "cancelled" ? "bg-destructive" : "bg-primary"}`} style={{ width: `${item.progress}%` }} /></div>
      {item.error ? <p className="pl-6 text-xs text-destructive">{item.error}</p> : null}
    </div>)}</div>;
}
