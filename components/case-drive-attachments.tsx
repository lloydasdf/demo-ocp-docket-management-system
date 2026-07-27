"use client";

import { useCallback, useEffect, useState } from "react";
import { ExternalLink, FolderPlus, Loader2, RefreshCw } from "lucide-react";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";

type DriveFile = {
  id: string;
  name: string;
  mimeType: string | null;
  webViewLink: string | null;
  webContentLink: string | null;
  size: string | null;
  modifiedTime: string | null;
};

type DriveState = {
  files: DriveFile[];
  scannedAt: string;
  folder: { name: string; webViewLink: string | null };
};

function fileSize(value: string | null) {
  const bytes = value ? Number(value) : 0;
  if (!Number.isFinite(bytes) || bytes <= 0) return "—";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
}

async function authenticatedRequest(caseId: number, path: "files" | "retry", method = "GET") {
  const supabase = await getSupabaseBrowserClient();
  const { data } = await supabase.auth.getSession();
  if (!data.session?.access_token) throw new Error("Your session has expired.");
  const response = await fetch(`/api/cases/${caseId}/drive/${path}`, {
    method,
    headers: { Authorization: `Bearer ${data.session.access_token}` },
    cache: "no-store",
  });
  const body = await response.json() as { data?: DriveState & { drive?: { status: string } }; error?: { message?: string; canCreate?: boolean } };
  return { response, body };
}

export function CaseDriveAttachments({ caseId, docketYear, docketNumber }: { caseId: number; docketYear: number | null; docketNumber: string | null }) {
  const [drive, setDrive] = useState<DriveState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [canCreate, setCanCreate] = useState(false);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const { response, body } = await authenticatedRequest(caseId, "files");
      if (!response.ok || !body.data) {
        setCanCreate(Boolean(body.error?.canCreate));
        throw new Error(body.error?.message ?? "Unable to read Google Drive attachments.");
      }
      setDrive(body.data); setCanCreate(false);
    } catch (loadError) { setError(loadError instanceof Error ? loadError.message : "Unable to read Google Drive attachments."); }
    finally { setLoading(false); }
  }, [caseId]);

  useEffect(() => { void load(); }, [load]);

  async function createFolder() {
    setCreating(true); setError(null);
    try {
      const { response, body } = await authenticatedRequest(caseId, "retry", "POST");
      if (!response.ok || body.data?.drive?.status !== "READY") throw new Error(body.error?.message ?? "Google Drive folder creation failed.");
      await load();
    } catch (createError) { setError(createError instanceof Error ? createError.message : "Google Drive folder creation failed."); }
    finally { setCreating(false); }
  }

  return <div className="space-y-4">
    <div className="flex flex-wrap items-center justify-between gap-3">
      <p className="text-sm text-muted-foreground">Expected location: <strong>{docketYear ?? "Unknown year"}</strong> / <strong>{docketNumber ?? "Unknown docket"}</strong></p>
      <div className="flex gap-2">
        {drive?.folder.webViewLink ? <Button variant="outline" asChild><a href={drive.folder.webViewLink} target="_blank" rel="noreferrer">Open folder<ExternalLink className="ml-2 h-4 w-4" /></a></Button> : null}
        <Button variant="outline" onClick={() => void load()} disabled={loading || creating}><RefreshCw className={`mr-2 h-4 w-4 ${loading ? "animate-spin" : ""}`} />Refresh</Button>
      </div>
    </div>
    {loading && !drive ? <div className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" />Finding the docket folder and loading files…</div> : null}
    {error ? <Alert variant="destructive"><AlertTitle>Google Drive unavailable</AlertTitle><AlertDescription className="space-y-3"><p>{error}</p>{canCreate ? <Button onClick={() => void createFolder()} disabled={creating}><FolderPlus className="mr-2 h-4 w-4" />{creating ? "Creating year and docket folders…" : "Create GDrive folder"}</Button> : null}</AlertDescription></Alert> : null}
    {drive && !loading ? drive.files.length ? <div className="divide-y rounded-lg border">{drive.files.map((file) => <div key={file.id} className="flex items-center justify-between gap-3 p-3"><div className="min-w-0"><p className="truncate font-medium">{file.name}</p><p className="text-xs text-muted-foreground">{fileSize(file.size)}{file.modifiedTime ? ` • Updated ${new Date(file.modifiedTime).toLocaleString()}` : ""}</p></div>{file.webViewLink ? <Button variant="ghost" size="sm" asChild><a href={file.webViewLink} target="_blank" rel="noreferrer" aria-label={`Open ${file.name}`}><ExternalLink className="h-4 w-4" /></a></Button> : null}</div>)}</div> : <div className="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">The Google Drive docket folder is connected and currently empty.</div> : null}
  </div>;
}
