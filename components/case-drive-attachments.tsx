"use client";

import { useCallback, useEffect, useState } from "react";
import { ArrowLeft, CheckCircle2, FolderPlus, Loader2, RefreshCw } from "lucide-react";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { AttachmentWorkspace, type PreviewFile } from "@/components/drive-preview";
import type { OnlyOfficeSession } from "@/components/drive-preview/onlyoffice-editor";

type DriveFile = PreviewFile;

type DriveState = {
  files: DriveFile[];
  scannedAt: string;
  folder: { id: string; name: string; webViewLink: string | null };
  currentFolder: { id: string; name: string; webViewLink: string | null };
};

async function authenticatedRequest(caseId: number, path: string, method = "GET") {
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

export function CaseDriveAttachments({ caseId, docketYear, docketType, docketNumber, onPreviewChange }: { caseId: number; docketYear: number | null; docketType: string | null; docketNumber: string | null; onPreviewChange?: (active: boolean, widthPercent?: number) => void }) {
  const [drive, setDrive] = useState<DriveState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [canCreate, setCanCreate] = useState(false);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [downloadingId, setDownloadingId] = useState<string | null>(null);
  const [folderStack, setFolderStack] = useState<Array<{ id: string; name: string }>>([]);
  const [folderCreated, setFolderCreated] = useState(false);

  const load = useCallback(async (folderId?: string) => {
    setLoading(true); setError(null); setFolderCreated(false);
    try {
      const { response, body } = await authenticatedRequest(caseId, folderId ? `files?folderId=${encodeURIComponent(folderId)}` : "files");
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
      // A newly provisioned docket folder is empty by definition. Avoid an
      // immediate redundant Drive listing; Refresh remains available on demand.
      setCanCreate(false);
      setDrive(null);
      setFolderStack([]);
      setFolderCreated(true);
    } catch (createError) { setError(createError instanceof Error ? createError.message : "Google Drive folder creation failed."); }
    finally { setCreating(false); }
  }

  async function fetchFileBlob(file: DriveFile) {
      const supabase = await getSupabaseBrowserClient();
      const { data } = await supabase.auth.getSession();
      if (!data.session?.access_token) throw new Error("Your session has expired.");
      const response = await fetch(`/api/cases/${caseId}/drive/files/${encodeURIComponent(file.id)}/download`, { headers: { Authorization: `Bearer ${data.session.access_token}` } });
      if (!response.ok) {
        const body = await response.json().catch(() => null) as { error?: { message?: string } } | null;
        throw new Error(body?.error?.message ?? "Unable to download the file.");
      }
      return { blob: await response.blob(), disposition: response.headers.get("content-disposition") ?? "" };
  }

  async function loadPreviewBlob(file: DriveFile) {
    return (await fetchFileBlob(file)).blob;
  }

  async function startDocumentEdit(file: DriveFile): Promise<OnlyOfficeSession> {
    const supabase = await getSupabaseBrowserClient();
    const { data } = await supabase.auth.getSession();
    if (!data.session?.access_token) throw new Error("Your session has expired.");
    const response = await fetch(`/api/cases/${caseId}/drive/edit/start`, { method: "POST", headers: { "content-type": "application/json", Authorization: `Bearer ${data.session.access_token}` }, body: JSON.stringify({ fileId: file.id }) });
    const body = await response.json() as { data?: OnlyOfficeSession; error?: { message?: string } };
    if (!response.ok || !body.data) throw new Error(body.error?.message ?? "Unable to start the document editor.");
    return body.data;
  }

  async function checkDocumentEditStatus(sessionId: string) {
    const supabase = await getSupabaseBrowserClient(); const { data } = await supabase.auth.getSession();
    if (!data.session?.access_token) throw new Error("Your session has expired.");
    const response = await fetch(`/api/cases/${caseId}/drive/edit/${sessionId}/status`, { headers: { Authorization: `Bearer ${data.session.access_token}` }, cache: "no-store" });
    const body = await response.json() as { data?: { status: string; last_error?: string | null }; error?: { message?: string } };
    if (!response.ok || !body.data) throw new Error(body.error?.message ?? "Unable to read edit status.");
    return body.data;
  }

  async function cancelDocumentEditSession(sessionId: string) {
    const supabase = await getSupabaseBrowserClient(); const { data } = await supabase.auth.getSession();
    if (!data.session?.access_token) return;
    await fetch(`/api/cases/${caseId}/drive/edit/${sessionId}/status`, { method: "DELETE", headers: { Authorization: `Bearer ${data.session.access_token}` } });
  }

  async function downloadFile(file: DriveFile) {
    setDownloadingId(file.id); setError(null);
    try {
      const downloaded = await fetchFileBlob(file);
      const url = URL.createObjectURL(downloaded.blob);
      const disposition = downloaded.disposition;
      const encodedName = disposition.match(/filename\*=UTF-8''([^;]+)/i)?.[1];
      const downloadName = encodedName ? decodeURIComponent(encodedName) : file.name;
      const anchor = document.createElement("a");
      anchor.href = url; anchor.download = downloadName; document.body.appendChild(anchor); anchor.click(); anchor.remove();
      URL.revokeObjectURL(url);
    } catch (downloadError) { setError(downloadError instanceof Error ? downloadError.message : "Unable to download the file."); }
    finally { setDownloadingId(null); }
  }

  function browseFolder(folder: DriveFile) {
    if (!drive) return;
    setFolderStack((items) => [...items, { id: drive.currentFolder.id, name: drive.currentFolder.name }]);
    void load(folder.id);
  }

  function browseBack() {
    const parent = folderStack[folderStack.length - 1];
    if (!parent) return;
    setFolderStack((items) => items.slice(0, -1));
    void load(parent.id);
  }

  const nestedLocation = drive && drive.currentFolder.id !== drive.folder.id
    ? [...folderStack.slice(1).map((folder) => folder.name), drive.currentFolder.name]
    : [];

  return <div className="space-y-4">
    <div className="flex flex-wrap items-center justify-between gap-3">
      <p className="text-sm text-muted-foreground">Location: <strong>{docketYear ?? "Unknown year"}</strong> / <strong>{docketType ?? "Unknown type"}</strong> / <strong>{docketNumber ?? "Unknown docket"}</strong>{nestedLocation.map((name, index) => <span key={`${name}-${index}`}> / <strong>{name}</strong></span>)}</p>
      <div className="flex gap-2">
        {folderStack.length ? <Button variant="outline" onClick={browseBack} disabled={loading}><ArrowLeft className="mr-2 h-4 w-4" />Back</Button> : null}
        <Button variant="outline" onClick={() => void load(drive?.currentFolder.id)} disabled={loading || creating}><RefreshCw className={`mr-2 h-4 w-4 ${loading ? "animate-spin" : ""}`} />Refresh</Button>
      </div>
    </div>
    {loading && !drive ? <div className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" />Finding the docket folder and loading files…</div> : null}
    {creating ? <div className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" />Creating folder</div> : null}
    {folderCreated ? <div className="flex items-center gap-3 rounded-lg border border-green-200 bg-green-50 p-4 text-green-800"><CheckCircle2 className="h-6 w-6 motion-safe:animate-[bounce_600ms_ease-out_1]" /><div><p className="font-medium">Folder created</p><p className="text-sm">The new Google Drive docket folder is empty.</p></div></div> : null}
    {error ? <Alert variant="destructive"><AlertTitle>Google Drive unavailable</AlertTitle><AlertDescription className="space-y-3"><p>{error}</p>{canCreate ? <Button onClick={() => void createFolder()} disabled={creating}><FolderPlus className="mr-2 h-4 w-4" />Create GDrive folder</Button> : null}</AlertDescription></Alert> : null}
    {drive && !loading ? <AttachmentWorkspace files={drive.files} downloadingId={downloadingId} onBrowse={browseFolder} onDownload={(file) => void downloadFile(file)} loadBlob={loadPreviewBlob} startEdit={startDocumentEdit} checkEditStatus={checkDocumentEditStatus} cancelEditSession={cancelDocumentEditSession} onDocumentSaved={() => void load(drive.currentFolder.id)} onPreviewChange={onPreviewChange} onError={setError} /> : null}
  </div>;
}
